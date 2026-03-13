# DevSecOps Diploma Project

## Описание
Проект представляет собой веб-приложение Flaskr (учебный блог на Flask). Цель - построить безопасный CI/CD пайплайн с интеграцией инструментов безопасности.

## CI/CD Pipeline (GitHub Actions)
- При каждом пуше в ветку `main` или создании Pull Request запускается workflow.
- **Шаги**:
  1. Установка Python и зависимостей.
  2. Запуск тестов (pytest).
  3. Сборка Docker-образа.
  4. Публикация образа в Docker Hub (`username/devsecops-diploma:latest`).
