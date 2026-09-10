failover
========

*reverse proxy nginx avec bascule automatique vers une page de maintenance*

Ce conteneur se place devant un service HTTP (`UPSTREAM_HOST`/`UPSTREAM_PORT`). Tant que
celui-ci répond `200` sur un chemin de vérification (`HEALTH_PATH`, `/` par défaut), le
trafic lui est transmis normalement. Dès qu'il ne répond plus `200` (panne, déploiement en
cours, healthcheck en timeout, DNS absent...), le conteneur sert automatiquement une page de
maintenance locale, templatée, jusqu'à ce que l'upstream redevienne sain.

Inspiré de [wickerlabs/maintenance](https://hub.docker.com/r/wickerlabs/maintenance) pour le
template de page (mêmes noms de variables `TITLE`/`HEADLINE`/`MESSAGE`/`TEAM_NAME`/`THEME`/
`LINK_COLOR`), mais réécrit sur une base nginx (leur implémentation sert la page via une
boucle `nc` mono-connexion, inutilisable en prod) avec en plus :

- un vrai reverse proxy vers l'upstream (nginx `proxy_pass`), pas juste une page statique,
- un healthcheck actif en arrière-plan (et non une simple interception d'erreurs par requête),
  qui vérifie une seule fois pour tous, indépendamment du chemin réellement demandé,
- une hystérésis (`HEALTH_FAIL_THRESHOLD`/`HEALTH_PASS_THRESHOLD`) pour éviter de basculer sur
  un simple aléa réseau,
- un démarrage prudent : le conteneur sert la page de maintenance tant que l'upstream n'a pas
  été vérifié sain au moins une fois.

Fonctionnement
--------------

Au démarrage, `docker-entrypoint.sh` génère deux configurations nginx complètes (une qui
proxifie vers l'upstream, une qui sert la page de maintenance) et active la maintenance par
défaut. Un script `healthcheck.sh` tourne en tâche de fond, sonde l'upstream à intervalle
régulier, et bascule la configuration active (`nginx -s reload`, sans coupure) selon l'état de
santé constaté.

Variables d'environnement
--------------------------

| Variable                 | Défaut                        | Description                                    |
|---------------------------|-------------------------------|-------------------------------------------------|
| `PORT`                    | `8080`                        | Port d'écoute du conteneur                       |
| `UPSTREAM_HOST`           | `web`                          | Hôte du service à mettre devant                  |
| `UPSTREAM_PORT`           | `80`                           | Port du service à mettre devant                  |
| `HEALTH_PATH`              | `/`                            | Chemin sondé pour le healthcheck                 |
| `HEALTH_INTERVAL`          | `5`                            | Intervalle entre deux checks (secondes)          |
| `HEALTH_TIMEOUT`           | `3`                            | Timeout d'un check (secondes)                    |
| `HEALTH_FAIL_THRESHOLD`    | `2`                            | Échecs consécutifs avant bascule en maintenance  |
| `HEALTH_PASS_THRESHOLD`    | `2`                            | Succès consécutifs avant retour au proxy         |
| `RESPONSE_CODE`            | `503`                          | Code HTTP renvoyé en mode maintenance            |
| `TITLE`                    | `Site Maintenance`             | Titre de la page                                 |
| `HEADLINE`                 | `We will be back soon!`        | Titre affiché                                    |
| `MESSAGE`                  | `Sorry for the inconvenience...` | Message affiché (HTML autorisé)                |
| `TEAM_NAME`                 | `The Team`                     | Signature en bas de page                         |
| `THEME`                     | `Light`                        | `Light` ou `Dark`                                |
| `LINK_COLOR`                | `#dc8100`                      | Couleur des liens dans le message                |

Quickstart
----------

```
# builder et lancer failover devant un faux service "web" de test
make up

# vérifier l'état actuel (200 = proxy, 503 = maintenance)
make curl

# simuler une panne, attendre la bascule, revérifier
make stop-web
sleep 5
make curl

# relever web, attendre le retour au proxy
make start-web
sleep 5
make curl
```

Utilisation en prod (exemple Swarm)
-------------------------------------

Ce conteneur ne fait que du routing HTTP simple côté Traefik (un seul router, un seul
service loadbalancer) : le failover se joue entièrement à l'intérieur du conteneur, ce qui le
rend compatible avec le provider Docker/Swarm de Traefik (contrairement au type de service
`failover` natif de Traefik, qui n'est supporté que par les providers File et Kubernetes CRD).

```yaml
services:
  web:
    image: monimage:latest
    networks:
      - default
    deploy:
      labels:
        - traefik.enable=false   # web n'est plus exposé directement

  failover:
    image: registry.kibatic.com/ops/failover:latest
    networks:
      - default
      - traefik-public
    environment:
      UPSTREAM_HOST: web
      UPSTREAM_PORT: "80"
    deploy:
      labels:
        - traefik.enable=true
        - traefik.docker.network=traefik-public
        - traefik.http.routers.myapp.rule=Host(`example.com`)
        - traefik.http.services.myapp.loadbalancer.server.port=8080
```

CI
--

Le build/push de l'image passe par GitHub Actions ([.github/workflows/build.yml](.github/workflows/build.yml)),
via Docker Build Cloud (driver `cloud`, builder `kibatic/kibatic`) plutôt qu'un build local — le
paquet `docker-buildx-plugin` de Docker CE sur Linux n'embarque pas ce driver, seul Docker
Desktop ou un binaire buildx dédié le permettent en local.

À configurer une fois dans les paramètres du repo GitHub (`Settings > Secrets and variables >
Actions`) :

| Type     | Nom                   | Valeur                                              |
|----------|-----------------------|------------------------------------------------------|
| Variable | `DOCKER_ACCOUNT`      | `kibatic` (organisation Docker Hub)                   |
| Variable | `CLOUD_BUILDER_NAME`  | `kibatic` (nom du builder Docker Build Cloud)         |
| Secret   | `DOCKER_ACCESS_TOKEN` | Access token Docker Hub avec droit push sur `kibatic` |

Notes
-----

- Le healthcheck cible `UPSTREAM_HOST`/`UPSTREAM_PORT` uniquement (pas le chemin réellement
  demandé par le client) : un vrai 404 applicatif sur une page qui n'existe pas ne déclenche
  donc pas la maintenance, seul l'état de `HEALTH_PATH` compte.
- `RESPONSE_CODE` est un code numérique (`503`), contrairement à l'image d'origine qui prenait
  une ligne de statut complète (`"503 Service Unavailable"`) — nginx génère lui-même le texte
  associé au code.
