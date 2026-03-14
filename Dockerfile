FROM python:3.11-slim

WORKDIR /app

COPY pyproject.toml README.rst LICENSE.txt ./
COPY flaskr/ ./flaskr/
COPY tests/ ./tests/

RUN pip install --no-cache-dir -e .

RUN useradd --create-home appuser

RUN mkdir -p /app/instance && chown -R appuser:appuser /app/instance

USER appuser

RUN flask --app flaskr init-db

EXPOSE 5000

CMD ["flask", "--app", "flaskr", "run", "--host=0.0.0.0"]
