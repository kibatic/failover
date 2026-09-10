#!/usr/bin/env node
'use strict';

// Preview live de html/index.template.html, avec rechargement auto du
// navigateur à chaque modif du fichier. Ne dépend que du runtime Node
// fourni par l'image node:alpine (voir `make preview`), aucune install.

const http = require('http');
const fs = require('fs');
const path = require('path');

const TEMPLATE_PATH = path.join(__dirname, '..', 'html', 'index.template.html');
const PORT = process.env.PREVIEW_PORT || 3000;

// Mêmes valeurs par défaut que le Dockerfile / le tableau du README.
const DEFAULTS = {
  TITLE: 'Site Maintenance',
  HEADLINE: 'We will be back soon!',
  MESSAGE: 'Sorry for the inconvenience, we are performing maintenance.',
  TEAM_NAME: 'The Team',
  THEME: 'Light',
  LINK_COLOR: '#dc8100',
};

function render() {
  let html = fs.readFileSync(TEMPLATE_PATH, 'utf8');
  for (const key of Object.keys(DEFAULTS)) {
    const value = process.env[key] !== undefined ? process.env[key] : DEFAULTS[key];
    html = html.split('${' + key + '}').join(value);
  }
  const reload = "<script>new EventSource('/__reload').onmessage=()=>location.reload();</script>";
  return html.replace('</body>', reload + '</body>');
}

let clients = [];
fs.watch(TEMPLATE_PATH, () => {
  console.log('template modifié, rechargement des navigateurs connectés...');
  clients.forEach((res) => res.write('data: reload\n\n'));
});

http
  .createServer((req, res) => {
    if (req.url === '/__reload') {
      res.writeHead(200, {
        'Content-Type': 'text/event-stream',
        'Cache-Control': 'no-cache',
        Connection: 'keep-alive',
      });
      res.write('\n');
      clients.push(res);
      req.on('close', () => {
        clients = clients.filter((c) => c !== res);
      });
      return;
    }
    try {
      res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
      res.end(render());
    } catch (err) {
      res.writeHead(500, { 'Content-Type': 'text/plain; charset=utf-8' });
      res.end(String(err));
    }
  })
  .listen(PORT, () => console.log(`preview ready`));
