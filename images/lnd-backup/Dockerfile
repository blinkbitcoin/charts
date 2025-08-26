FROM alpine/k8s:1.23.14

# Install required packages for backup functionality
RUN apk --update add \
    curl \
    jq \
    aws-cli \
    nodejs \
    npm \
    python3 \
    py3-pip

# Install Google Cloud SDK for GCS support
RUN curl -sSL https://sdk.cloud.google.com | bash

# Set working directory
WORKDIR /app

# Copy backup service
COPY backup-service.js /app/backup-service.js

# Install Node.js dependencies
RUN npm init -y && npm install lightning

# Make backup service executable
RUN chmod +x /app/backup-service.js

# Default command
CMD ["node", "/app/backup-service.js"]
