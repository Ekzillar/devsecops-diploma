# DevSecOps Diploma Project

## Описание проекта
Веб-приложение **Flaskr** — учебный блог на Flask. Цель проекта — построить безопасный CI/CD пайплайн с интеграцией инструментов безопасности (DevSecOps).

## Этап 1: CI/CD

### Настроенный пайплайн (GitHub Actions)
При каждом пуше в ветку `main` или создании Pull Request автоматически запускается workflow, описанный в файле `.github/workflows/ci.yml`.

**Шаги пайплайна:**
1. **Установка Python 3.11** и зависимостей проекта (`pip install -e .`).
2. **Запуск тестов** с помощью `pytest` (папка `tests/`).
3. **Сборка Docker-образа** на основе `Dockerfile`.
4. **Публикация образа** в Docker Hub (реестр `username/devsecops-diploma:latest`).

### Используемые облачные сервисы
- **GitHub Actions** — для выполнения CI/CD задач.
- **Docker Hub** — для хранения собранных образов.

### Настройка секретов для Docker Hub
Для публикации образа необходимы учётные данные Docker Hub. Они хранятся в **Secrets** репозитория:
- `DOCKER_USERNAME` — логин от Docker Hub.
- `DOCKER_PASSWORD` — **токен доступа** (не пароль!).  
  Инструкция по созданию токена: [Docker Hub Access Tokens](https://docs.docker.com/docker-hub/access-tokens/).

Секреты добавляются в разделе `Settings` → `Secrets and variables` → `Actions`.

### Проверка работы пайплайна
- Перейдите на вкладку **Actions** вашего репозитория на GitHub.
- Выберите последний запуск workflow — он должен быть зелёным (успешно завершён).
- В логах можно увидеть все выполненные шаги.
- Готовый образ доступен на Docker Hub: [https://hub.docker.com/r/username/devsecops-diploma](https://hub.docker.com/r/username/devsecops-diploma)

### Структура репозитория (ключевые файлы)
```
├── .github/workflows/ci.yml       # CI/CD сценарий
├── flaskr/                         # исходный код приложения
├── tests/                           # тесты
├── Dockerfile                       # инструкция для сборки образа
├── pyproject.toml                   # конфигурация пакета (зависимости, метаданные)
├── README.md                        # документация (текущий файл)
└── requirements.txt (опционально)   # альтернативный способ фиксации зависимостей
```
**Дата завершения этапа:** 13 марта 2026 г.


## Этап 2: SAST (Static Application Security Testing)
