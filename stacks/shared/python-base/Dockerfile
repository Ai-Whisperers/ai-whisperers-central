FROM python:3.12-alpine
RUN pip install --no-cache-dir redis
COPY app.py /app.py
CMD ["python", "/app.py"]
