#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# setup-minio-alias.sh
#
# Читает .env (или окружение) для MINIO_USER и MINIO_PASSWORD,
# и настраивает alias "local" для http://localhost:9000
#
# Usage:
#   ./setup-minio-alias.sh
# -----------------------------------------------------------------------------

ENV_FILE=".env"
if [[ -f "$ENV_FILE" ]]; then
  set -o allexport
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +o allexport
fi

# Проверяем обязательные переменные
: "${MINIO_USER:?Need to set MINIO_USER in env or $ENV_FILE}"
: "${MINIO_PASSWORD:?Need to set MINIO_PASSWORD in env or $ENV_FILE}"

# Параметры
ALIAS_NAME="local"
ENDPOINT="http://localhost:9000"
ACCESS_KEY="$MINIO_USER"
SECRET_KEY="$MINIO_PASSWORD"

# Выполняем mc alias set внутри docker-контейнера
docker compose exec minio \
    mc alias set "$ALIAS_NAME" "$ENDPOINT" "$ACCESS_KEY" "$SECRET_KEY" --api S3v4

echo "✅ Alias '$ALIAS_NAME' → '$ENDPOINT' настроен успешно."

