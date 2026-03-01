# Деплой n8n через Docker

Сборка и запуск n8n из этого репозитория с помощью Dockerfile и docker-compose.

## Переменные окружения: что нужно для работы

### Обязательно для работы

**Ничего не обязательно** — n8n стартует с дефолтами:

- **БД:** по умолчанию `DB_TYPE=sqlite`, файл `database.sqlite` в папке данных (`N8N_USER_FOLDER`). Для одного инстанса этого достаточно.
- **Порт:** 5678.
- **Данные:** каталог `~/.n8n` (в Docker — volume на `/home/node/.n8n`). В нём хранятся БД, credentials, ключ шифрования (если не задан `N8N_ENCRYPTION_KEY`).

### Рекомендуется для продакшена

| Переменная | Описание |
|------------|----------|
| `N8N_ENCRYPTION_KEY` | Ключ шифрования credentials. Если не задан, при первом запуске создаётся случайный и пишется в файл. Для перезапусков и нескольких инстансов лучше задать один и тот же ключ. |
| `N8N_USER_FOLDER` | Папка данных (в Docker уже `/home/node/.n8n`). |
| `DB_TYPE` | `sqlite` (по умолчанию) или `postgresdb` для внешней БД. |

### База данных (опционально)

**SQLite (по умолчанию):**

- Переменные не нужны.
- Файл БД: `N8N_USER_FOLDER/database.sqlite` (или путь из `DB_SQLITE_DATABASE`).

**PostgreSQL** — задать:

- `DB_TYPE=postgresdb`
- `DB_POSTGRESDB_HOST`
- `DB_POSTGRESDB_PORT` (по умолчанию 5432)
- `DB_POSTGRESDB_DATABASE` (по умолчанию `n8n`)
- `DB_POSTGRESDB_USER`
- `DB_POSTGRESDB_PASSWORD`
- По желанию: `DB_POSTGRESDB_SCHEMA` (по умолчанию `public`), SSL-переменные (`DB_POSTGRESDB_SSL_*`).

### Файл `.env` (рекомендуется)

В папке `deploy/` лежит **`deploy/.env.example`** — шаблон переменных. Скопируй его в **`deploy/.env`** и подставь свои значения. Compose подхватывает `deploy/.env` автоматически. Если переменные не нужны, создай пустой `deploy/.env` (файл должен существовать).

### Подгрузка `.env` из S3 (опционально)

При старте контейнера entrypoint загружает файл с переменными из S3 (если задан `S3_ENV_URI`) и применяет их до запуска n8n. Положи в S3 файл в формате `.env` (строки `KEY=value`). Задай `S3_ENV_URI` (например `s3://my-bucket/env/@n8n.env`) и при необходимости `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`. В образ встроен AWS CLI.

### Полезные опциональные переменные `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION` — это заготовка под **кастомную** загрузку `.env` из S3 (например, своим entrypoint’ом). Сам n8n S3 для конфига не использует. Для обычного деплоя их можно не задавать.

### Полезные опциональные переменные

- `N8N_HOST`, `N8N_PORT`, `N8N_PROTOCOL` — как к n8n обращаются снаружи (для ссылок в письмах, webhook URL и т.д.).
- `N8N_PATH` — если n8n за прокси по подпути (например `/n8n`).
- `GENERIC_TIMEZONE` — таймзона (например `Europe/Moscow`).
- Другие опции — в [документации n8n](https://docs.n8n.io/hosting/environment-variables/).

---

## Быстрый старт

Из **корня репозитория**:

```bash
# Опционально: скопировать шаблон переменных и отредактировать
cp deploy/.env.example deploy/.env

# Сборка и запуск (образ строится из исходников)
docker compose -f deploy/docker-compose.yml up --build
```

После запуска n8n будет доступен по адресу: **http://localhost:5678**. Если не создавал `deploy/.env`, создай пустой файл: `touch deploy/.env`.

## Варианты запуска

### 1. Только Docker (образ из корневого Dockerfile)

```bash
# Из корня репо
docker build -t n8n:local .
docker run -p 5678:5678 -v n8n_data:/home/node/.n8n n8n:local
```

### 2. Docker Compose (тот же образ + volume и env)

```bash
# Из корня репо
docker compose -f deploy/docker-compose.yml up -d
```

В `deploy/docker-compose.yml` настроены:
- чтение переменных из `deploy/.env` (`env_file`)
- порт `5678`
- volume для данных `n8n_data`
- переменные для БД и опционально S3 (дефолты в compose, переопределение через `.env` или S3)

### 3. Сборка через pnpm (как в CI)

Сначала собирается приложение, потом образ из уже собранного `compiled/`:

```bash
pnpm build:docker
# Образ: n8nio/n8n:local
```

## Структура

| Путь | Назначение |
|------|------------|
| `Dockerfile` (в корне) | Multi-stage: сборка из исходников и образ для запуска |
| `deploy/.env.example` | Шаблон переменных окружения (скопировать в `deploy/.env`) |
| `deploy/.env` | Локальные переменные (не в git), подхватываются compose |
| `deploy/docker-compose.yml` | Сервис n8n, volume, env_file, опционально PostgreSQL и S3 |
| `docker/images/n8n/docker-entrypoint.sh` | Entrypoint: при наличии `S3_ENV_URI` загружает .env из S3, затем запускает n8n |
| `docker/images/n8n/Dockerfile` | Образ из уже собранного `compiled/` (используется после `pnpm build:docker`) |
