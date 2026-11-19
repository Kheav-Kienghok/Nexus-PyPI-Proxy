# Build through the Nexus cache. Pin the tag (and the digest once you know it).
FROM nexus.example.com/library/python:3.12.7-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
CMD ["python", "main.py"]
