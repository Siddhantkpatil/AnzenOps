FROM python:3.11-slim

WORKDIR /app

# Upgrade Python packaging tools to patched versions
RUN pip install --no-cache-dir --upgrade \
    pip \
    setuptools \
    wheel

# Copy application dependencies
COPY requirements.txt .

# Install application dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application source code
COPY . .

EXPOSE 5000

CMD ["python", "app.py"]
