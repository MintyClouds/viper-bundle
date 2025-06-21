# Руководство по автоматизированным резервным копиям с дедупликацией через Restic и восстановлению

Этот документ описывает настройку автоматизированных бекапов с дедупликацией данных на базе Restic для сервера Rocky Linux 8.4 с приложениями, развернутыми через Docker Compose. Также представлены инструкции по восстановлению.

---

## Содержание

1. [Предварительные требования](#prerequisites)
2. [Инициализация репозитория Restic](#init-repo)
3. [Сценарий резервного копирования с Restic](#backup-script)
4. [Планировщик задач (cron) для Restic](#cron)
5. [Политика хранения и дедупликация](#retention)
6. [Процедура восстановления с Restic](#restore)
7. [Мониторинг и проверка](#monitor)

---

## 1. Предварительные требования {#prerequisites}

- Rocky Linux 8.4 с привилегиями `root` или `sudo`.
- Docker и Docker Compose (v2).
- Установленный Restic (v0.15+).
- Доступ к каталогу приложения `/app` с `docker-compose.yml` и `.env`.
- Утилиты: `bash`, `docker`, `cron`.
- Настроенный бэкап-репозиторий (локальный или удалённый S3-совместимый).

---

## 2. Инициализация репозитория Restic {#init-repo}

1. **Создайте папку для локального репозитория (или настройте доступ к удалённому):**
   ```bash
   export RESTIC_REPOSITORY=/backups/restic-repo
   export RESTIC_PASSWORD_FILE=/root/.restic_passwd
   mkdir -p "$RESTIC_REPOSITORY"
   chmod 700 "$RESTIC_REPOSITORY"
   echo "<YOUR_SECURE_PASSWORD>" > "$RESTIC_PASSWORD_FILE"
   chmod 600 "$RESTIC_PASSWORD_FILE"
   ```

2. **Инициализация репозитория:**
   ```bash
   restic init
   ```

_Если используется S3-совместимый удалённый репозиторий, определите дополнительные переменные окружения (например AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, RESTIC_ENDPOINT) до `restic init`._

---

## 3. Сценарий резервного копирования с Restic {#backup-script}

Создайте файл `/usr/local/bin/docker_restic_backup.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Загрузка переменных Restic
export RESTIC_REPOSITORY=/backups/restic-repo
export RESTIC_PASSWORD_FILE=/root/.restic_passwd

# Переменные Docker Compose
COMPOSE_DIR="/app"
ENV_FILE="$COMPOSE_DIR/.env"
source "$ENV_FILE"

# Метка host и тэг snapshot
HOST_TAG="$(hostname -s)"
SNAPSHOT_TAG="docker-backup"

# Запуск backup для каталогов томов
restic backup \
  --host "$HOST_TAG" \
  --tag "$SNAPSHOT_TAG" \
  "$COMPOSE_DIR/.docker_data/postgres" \
  "$COMPOSE_DIR/.docker_data/redis" \
  "$COMPOSE_DIR/.docker_data/minio-data" \
  "$COMPOSE_DIR/.docker_data/vikunja-files" \
  "$COMPOSE_DIR/.docker_data/authelia" \
  --exclude "*socket*" \
  --verbose

# Дополнительно можно добавить дамп PostgreSQL как файл
# restic backup --tag pg-dump <(docker compose -f "$COMPOSE_DIR/docker-compose.yml" run --rm postgres pg_dumpall -U "$POSTGRES_USER")
```

Установите права:
```bash
sudo chown root:root /usr/local/bin/docker_restic_backup.sh
sudo chmod +x /usr/local/bin/docker_restic_backup.sh
```

---

## 4. Планировщик задач (Cron) для Restic {#cron}

Создайте файл `/etc/cron.d/restic_docker_backup`:

```
# Ежедневный бэкап в 02:30
30 2 * * * root /usr/local/bin/docker_restic_backup.sh >> /var/log/restic_backup.log 2>&1
```

Перезапустите демона cron:
```bash
sudo systemctl restart crond
```

---

## 5. Политика хранения и дедупликация {#retention}

Restic автоматически дедуплицирует данные во время backup. Для удаления старых снимков создайте скрипт `/usr/local/bin/restic_prune.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
export RESTIC_REPOSITORY=/backups/restic-repo
export RESTIC_PASSWORD_FILE=/root/.restic_passwd

# Политика хранения: ежедневно за последнюю неделю, еженедельно за месяц, ежемесячно за год
restic forget \
  --prune \
  --keep-daily 7 \
  --keep-weekly 4 \
  --keep-monthly 12 \
  --tag "docker-backup" \
  --verbose
```

Сделайте его исполняемым и добавьте в cron:
```bash
sudo chmod +x /usr/local/bin/restic_prune.sh
```

```cron
# Еженедельное удаление старых снапшотов в воскресенье в 03:00
0 3 * * 0 root /usr/local/bin/restic_prune.sh >> /var/log/restic_prune.log 2>&1
```

---

## 6. Процедура восстановления с Restic {#restore}

1. **Остановите сервисы:**
   ```bash
   cd /app
   docker compose down
   ```

2. **Найдите нужный снапшот:**
   ```bash
   restic snapshots --tag "docker-backup"
   ```

3. **Восстановление всех данных:**
   ```bash
   # Восстановление в указанный каталог (например /restore)
   mkdir -p /restore
   restic restore <SNAPSHOT_ID> --target /restore --verbose

   # Затем переместите папки обратно
   rsync -a /restore/app/.docker_data/postgres/ /app/.docker_data/postgres/
   rsync -a /restore/app/.docker_data/redis/    /app/.docker_data/redis/
   # и так далее для minio-data, vikunja-files, authelia
   ```

4. **(Опционально) Восстановление дампа PostgreSQL:**
   ```bash
   restic restore <SNAPSHOT_ID> --path backup-pg.sql --stdout | \
     docker compose run --rm postgres psql -U ${POSTGRES_USER}
   ```

5. **Запуск сервисов:**
   ```bash
   docker compose up -d
   ```

---

## 7. Мониторинг и проверка {#monitor}

- Логи: `/var/log/restic_backup.log`, `/var/log/restic_prune.log`.
- Регулярно проверяйте доступность репозитория:  
  ```bash
  restic check
  ```
- Тестируйте восстановление раз в квартал на стенде.

---

*Конец документа*

