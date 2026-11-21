#!/bin/bash
# Deploy Pool TV on the server. Run from anywhere:
#   ssh <server> /var/www/pool-tv/deploy.sh
#
# Pulls the latest code, builds the frontend (served by nginx from frontend/build)
# and rebuilds/restarts the backend container. Migrations run when the backend
# starts (bin/docker-entrypoint -> db:prepare). Data stays in the Docker volumes.
# Never run `docker compose down -v`: it deletes the database and uploads.
set -euo pipefail

cd "$(dirname "$0")"

for f in .env frontend/.env.production; do
  if [ ! -f "$f" ]; then
    echo "Missing $f (see README / nginx.conf). Aborting." >&2
    exit 1
  fi
done

echo "==> Pulling latest code"
git pull --ff-only

echo "==> Building frontend"
(
  cd frontend
  npm ci
  npm run build
)

echo "==> Rebuilding and restarting backend"
docker compose up -d --build backend
docker image prune -f

echo "==> Waiting for backend health check"
for _ in $(seq 1 30); do
  if curl -fsS http://127.0.0.1:3010/up >/dev/null 2>&1; then
    echo "==> Deploy done"
    exit 0
  fi
  sleep 2
done

echo "Backend did not answer on /up after 60s. Logs:" >&2
docker compose logs --tail=50 backend >&2
exit 1
