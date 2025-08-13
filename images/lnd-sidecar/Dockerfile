FROM lightninglabs/lnd:v0.18.5-beta as lnd

FROM alpine/k8s:1.23.14

COPY --from=lnd /bin/lncli /bin/lncli

# Install required packages including Node.js
RUN apk --update add expect curl jq aws-cli google-cloud-sdk nodejs npm

# Create app directory
WORKDIR /app

# Copy backup service
COPY backup-service.js /app/backup-service.js

# Install Node.js dependencies
RUN npm init -y && npm install lightning

# Make backup service executable
RUN chmod +x /app/backup-service.js

ENTRYPOINT []
