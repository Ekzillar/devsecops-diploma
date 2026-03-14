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

## Этап 4: Security Checks

**Цель:** автоматическая проверка кода на наличие секретов и сканирование Docker-образа на уязвимости.

### Проверка на секреты (Gitleaks)

- **Инструмент:** [Gitleaks](https://github.com/gitleaks/gitleaks) - статический анализатор для обнаружения паролей, ключей API и других секретов в репозитории.
- **Интеграция:** запускается параллельно в отдельном job `gitleaks`.
- **Конфигурация:** используется образ `zricethezav/gitleaks:latest`, сканирование выполняется с сохранением отчёта в формате JSON. Pipeline не останавливается при находках (`continue-on-error: true`), чтобы можно было анализировать отчёты без блокировки.
- **Результат:** отчёт `gitleaks-report.json` сохраняется как артефакт сборки.

### Сканирование образа (Trivy)

- **Инструмент:** [Trivy](https://github.com/aquasecurity/trivy) - сканер уязвимостей для контейнеров и файловых систем.
- **Интеграция:** job `trivy` запускается после успешной сборки образа (`needs: test-and-build`).
- **Параметры:**
  - Сканируется образ `${{ secrets.DOCKER_USERNAME }}/devsecops-diploma:latest`.
  - Формат отчёта - SARIF (поддерживается GitHub Security tab).
  - Уровень серьёзности: `CRITICAL,HIGH`.
  - `exit-code: '0'` - пайплайн не останавливается при обнаружении уязвимостей (позволяет сохранить отчёт).
- **Результаты:**
  - Отчёт загружается во вкладку **Security** репозитория GitHub.
  - Копия отчёта сохраняется как артефакт `trivy-report.sarif`.

---

## Этап 5: Security Gateway

**Цель:** автоматическая остановка пайплайна при обнаружении уязвимостей критического уровня и обратная связь в Pull Request.

### Реализованные механизмы

<table>
  <thead>
    <tr>
      <th>Инструмент</th>
      <th>Статус остановки</th>
      <th>Детали</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>Bandit (SAST)</strong></td>
      <td><strong>Останавливает</strong></td>
      <td>Запускается без <code>|| true</code>; при наличии уязвимостей уровня HIGH и выше job <code>test-and-build</code> завершается ошибкой, прерывая весь пайплайн.</td>
    </tr>
    <tr>
      <td><strong>OWASP ZAP (DAST)</strong></td>
      <td>Не останавливает</td>
      <td>Используется <code>|| true</code>, что позволяет сканированию выполняться без прерывания. В дальнейшем можно настроить анализ результатов.</td>
    </tr>
    <tr>
      <td><strong>Gitleaks</strong></td>
      <td>Не останавливает</td>
      <td>Установлен <code>continue-on-error: true</code>. Отчёт сохраняется, но pipeline продолжается.</td>
    </tr>
    <tr>
      <td><strong>Trivy</strong></td>
      <td>Не останавливает</td>
      <td>Параметр <code>exit-code: 'θ'</code> отключает остановку при находках. При желании можно изменить на <code>'1'</code> для остановки пайплайна при уязвимостях.</td>
    </tr>
  </tbody>
</table>

### Комментарии в Pull Request

Добавлен отдельный job `comment-pr`, который срабатывает только при событии `pull_request` и после завершения всех проверок. Он оставляет в PR комментарий со ссылками на все артефакты безопасности, что упрощает доступ к отчётам для ревьюеров.

```yaml
comment-pr:
  if: github.event_name == 'pull_request'
  needs: [test-and-build, dast, gitleaks, trivy]
  runs-on: ubuntu-latest
  steps:
    - name: Comment PR with artifact links
      uses: actions/github-script@v7
      with:
        script: |
          const artifactsUrl = `${context.serverUrl}/${context.repo.owner}/${context.repo.repo}/actions/runs/${context.runId}`;
          github.rest.issues.createComment({
            issue_number: context.issue.number,
            owner: context.repo.owner,
            repo: context.repo.repo,
            body: `## ✅ Security pipeline completed\n\n` +
                  `- [SAST Bandit report](${artifactsUrl})\n` +
                  `- [DAST OWASP ZAP report](${artifactsUrl})\n` +
                  `- [Gitleaks secrets report](${artifactsUrl})\n` +
                  `- [Trivy image scan report](${artifactsUrl})\n\n` +
                  `_Click on the links to download the artifacts._`
          });
