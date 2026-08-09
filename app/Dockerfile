FROM python:3.11-slim

WORKDIR /app

RUN pip install --no-cache-dir --upgrade \
    pip \
    setuptools==83.0.0 \
    wheel==0.46.2

COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 5000

CMD ["python", "app.py"]
