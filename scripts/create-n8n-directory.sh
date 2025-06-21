set -euo pipefail

# --- Проверяем наличие .env и загружаем его ---
if [[ ! -f .env ]]; then
  echo "Ошибка: файл .env не найден в текущей директории." >&2
  exit 1
fi

# экспортируем все переменные из .env
set -a
# shellcheck disable=SC1091
source ./.env
set +a



: "${N8N_FILES_DIR:?Не задана переменная POSTGRES_PASSWORD в .env}"

mkdir -p $N8N_FILES_DIR 
chown 1000:1000 $N8N_FILES_DIR
