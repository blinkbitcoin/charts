# Build stage - install dependencies and tools
FROM alpine:3.18 AS builder

# Install required packages for backup functionality
RUN apk --update add \
    curl \
    jq \
    nodejs \
    npm \
    python3 \
    py3-pip \
    bash

# Install Google Cloud SDK for GCS support
RUN curl -sSL https://sdk.cloud.google.com | bash -s -- --disable-prompts
ENV PATH="/root/google-cloud-sdk/bin:${PATH}"

# Set working directory
WORKDIR /app

# Copy backup service
COPY backup-service.js /app/backup-service.js

# Create package.json with all required dependencies
RUN echo '{\
  "name": "lnd-backup-service",\
  "version": "1.0.0",\
  "description": "LND Static Channel Backup service",\
  "main": "backup-service.js",\
  "dependencies": {\
    "lightning": "^10.17.0",\
    "@aws-sdk/client-s3": "^3.658.1",\
    "@aws-sdk/lib-storage": "^3.658.1",\
    "@google-cloud/storage": "^7.12.1"\
  }\
}' > package.json

# Install Node.js dependencies
RUN npm install --omit=dev

# Production stage - minimal runtime with SDK dependencies but no shell
FROM alpine:3.18

# Install runtime dependencies (no AWS CLI needed since we use SDK)
RUN apk --update add --no-cache \
    nodejs \
    python3 \
    curl \
    ca-certificates

# Copy Node.js application and dependencies from builder
COPY --from=builder /app /app

# Copy Google Cloud SDK from builder (for GCS support)
COPY --from=builder /root/google-cloud-sdk /google-cloud-sdk
ENV PATH="/google-cloud-sdk/bin:${PATH}"

# Remove shell binaries to prevent interactive access (do this last)
RUN rm -f /bin/sh /bin/ash /bin/bash /usr/bin/sh /usr/bin/ash /usr/bin/bash && \
    # Remove other potentially dangerous binaries
    rm -f /bin/su /usr/bin/su /sbin/su && \
    rm -f /usr/bin/wget /bin/wget

# Set working directory
WORKDIR /app

# Default command - direct Node.js execution
ENTRYPOINT ["node", "/app/backup-service.js"]
