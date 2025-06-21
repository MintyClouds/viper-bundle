#!/usr/bin/env bash
set -euo pipefail

# --- Настройки ---
CONTAINER_NAME=${CONTAINER_NAME:-postgres}  # или задайте своё имя контейнера

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

# проверяем, что ключевые переменные заданы
: "${OUTLINE_POSTGRES_DB_NAME:?Не задана переменная OUTLINE_POSTGRES_DB_NAME в .env}"
: "${POSTGRES_USER:?Не задана переменная POSTGRES_USER в .env}"
: "${POSTGRES_PASSWORD:?Не задана переменная POSTGRES_PASSWORD в .env}"

DB_NAME="public"
DB_USER="$POSTGRES_USER"
DB_PASS="$POSTGRES_PASSWORD"
DB_NON_ROOT_USER="$POSTGRES_NON_ROOT_USER"
DB_NON_ROOT_PASS="$POSTGRES_NON_ROOT_PASSWORD"

# --- Находим контейнер с Postgres 16 ---
CONTAINER_ID=$(docker ps \
  --filter "name=${CONTAINER_NAME}" \
  --filter "ancestor=postgres:16" \
  --format "{{.ID}}" | head -n1)

if [[ -z "$CONTAINER_ID" ]]; then
  echo "Ошибка: не найден запущенный контейнер Postgres 16 с именем '${CONTAINER_NAME}'." >&2
  exit 1
fi
echo "→ Контейнер: $CONTAINER_ID"

# --- Выполняем SQL: создаём роль, БД и тестируем таблицу ---
docker exec -i "$CONTAINER_ID" psql -v ON_ERROR_STOP=1 -U $DB_USER <<-SQL
  -- 1) Создаём роль (если ещё нет)
  DO \$\$
  BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '$DB_NON_ROOT_USER') THEN
      CREATE ROLE "$DB_NON_ROOT_USER" LOGIN PASSWORD '$DB_NON_ROOT_PASS';
    END IF;
  END
  \$\$;

  -- 2) Создаём базу данных
  CREATE DATABASE "$DB_NAME"
    WITH OWNER = "$DB_NON_ROOT_USER"
         ENCODING = 'UTF8'
         LC_COLLATE = 'C'
         LC_CTYPE   = 'C'
         TEMPLATE   = template0;

  GRANT ALL PRIVILEGES ON DATABASE "$DB_NAME" TO "$DB_NON_ROOT_USER";
SQL

docker exec -i "$CONTAINER_ID" psql -v ON_ERROR_STOP=1 -U $DB_NON_ROOT_USER -d $DB_NAME <<-SQL
  -- 3) Тест: подключаемся, создаём временную таблицу, вставляем строку и удаляем таблицу
  CREATE TABLE IF NOT EXISTS temp_test (
    id SERIAL PRIMARY KEY,
    test_val TEXT DEFAULT 'ok'
  );
  INSERT INTO temp_test DEFAULT VALUES;
  DROP TABLE temp_test;
SQL

echo "✔ Пользователь '$DB_NON_ROOT_USER' и база '$DB_NAME' созданы."
echo "✔ Тест создания/вставки/удаления таблицы прошёл успешно."

