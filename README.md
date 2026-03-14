# DevSecOps Diploma Project

## Описание проекта
Веб-приложение **Flaskr** - учебный блог на Flask. Цель проекта - построить безопасный CI/CD пайплайн с интеграцией инструментов безопасности (DevSecOps).

## Этап 1: CI/CD (непрерывная интеграция и доставка)

**Цель:** автоматизировать сборку, тестирование и развёртывание приложения.

**Платформа:** GitHub Actions.

**Что реализовано:**
- При каждом пуше в ветку `main` запускается workflow (файл `.github/workflows/ci.yml`).
- **Шаги:**
  1. Установка Python 3.11 и зависимостей.
  2. Запуск юнит-тестов (`pytest`).
  3. Сборка Docker-образа на основе `Dockerfile`.
  4. Публикация образа в Docker Hub (`ekzillar/devsecops-diploma:latest`).
  5. Автоматический деплой на VPS-сервер (`194.87.131.127`) через SSH.
- Для деплоя используются секреты GitHub: `SERVER_HOST`, `SERVER_USER`, `SERVER_SSH_KEY`, а также учётные данные Docker Hub.

**Результат:** после каждого пуша обновлённая версия приложения доступна по адресу `http://194.87.131.127:5000`.

## Этап 2: SAST (Static Application Security Testing)

**Цель:** добавить статический анализ кода для выявления потенциальных уязвимостей на ранних этапах разработки.

### Выбор инструмента: [Bandit](https://github.com/PyCQA/bandit)

**Почему Bandit:**
- Специализирован для Python (проект написан на Flask).
- Простая установка через `pip`, легко встраивается в GitHub Actions.
- Гибкие форматы отчётов (JSON, HTML) - можно сохранять как артефакты.
- Поддерживает настройку уровней критичности и игнорирование ложных срабатываний.

### Интеграция в CI/CD

- Шаг добавлен в workflow после установки зависимостей:
  ```yaml
  - name: Run Bandit SAST
    run: |
      pip install bandit
      bandit -r flaskr -f json -o bandit-report.json || true
  - name: Upload Bandit report
    uses: actions/upload-artifact@v4
    with:
      name: bandit-report
      path: bandit-report.json

### Результаты

При первом запуске Bandit обнаружил потенциальную проблему: **хардкоженный секретный ключ** в `flaskr/__init__.py` (строка 11).  
После исправления (ключ вынесен в переменные окружения) все последующие запуски завершаются без замечаний. Это демонстрирует эффективность SAST - уязвимость была выявлена и устранена до попадания в продакшен.
Отчёты Bandit доступны для скачивания во вкладке **Actions** -> конкретный запуск -> **Artifacts**.

## Этап 3: DAST (Dynamic Application Security Testing)

**Цель:** тестирование запущенного приложения на уязвимости, доступные извне.

**Инструмент:** [OWASP ZAP](https://www.zaproxy.org/) в режиме baseline-сканирования.

**Интеграция в CI/CD:**
- Добавлен отдельный job `dast`, который запускается после успешного деплоя (`needs: test-and-build`).
- Шаги в workflow:

  ```yaml
  - name: Run OWASP ZAP DAST
    run: |
      mkdir -p zap_output && chmod 777 zap_output
      docker run --rm --user root -v $(pwd)/zap_output:/zap/wrk:rw -w /zap/wrk -t ghcr.io/zaproxy/zaproxy:stable zap-baseline.py \
        -t http://${{ secrets.SERVER_HOST }}:5000 -r dast_report.html || true
      cp zap_output/dast_report.html ./
  - name: Upload DAST report
    uses: actions/upload-artifact@v4
    with:
      name: dast-report
      path: dast_report.html

Для корректной записи отчёта контейнер запускается от root, а локальная папка zap_output монтируется в контейнер.

### Результаты:

- После каждого деплоя автоматически выполняется сканирование.
- Отчёт доступен во вкладке Actions (артефакты сборки).
- Пример найденных предупреждений (уровня Medium/Low):
    Отсутствие Anti-CSRF токенов.
    Отсутствие заголовков безопасности (CSP, X-Frame-Options и др.)
    Утечка версии сервера.

