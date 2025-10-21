# https://strimzi.io/docs/operators/latest/full/deploying.html#creating-new-image-from-base-str

FROM quay.io/strimzi/kafka:0.46.0-kafka-3.9.0
USER root:root

WORKDIR /opt/kafka/plugins

# Download and install the mongo source connector from
# https://repo1.maven.org/maven2/org/mongodb/kafka/mongo-kafka-connect/1.10.1/
RUN mkdir mongo-source-connector && cd mongo-source-connector && \
    curl -L -o mongo-source-connector.jar https://repo1.maven.org/maven2/org/mongodb/kafka/mongo-kafka-connect/1.10.1/mongo-kafka-connect-1.10.1-all.jar && \
    curl -L -o mongo-source-connector.jar.sha1 https://repo1.maven.org/maven2/org/mongodb/kafka/mongo-kafka-connect/1.10.1/mongo-kafka-connect-1.10.1-all.jar.sha1 && \
    echo "$(cat mongo-source-connector.jar.sha1) mongo-source-connector.jar" | sha1sum -c - && \
    rm mongo-source-connector.jar.sha1

# Download and install the postgres source connector: https://debezium.io/releases/
# Maven artifacts: https://central.sonatype.com/artifact/io.debezium/debezium-connector-postgres/versions
RUN mkdir postgres-source-connector && cd postgres-source-connector && \
    curl -L -o postgres-source-connector.tar.gz https://repo1.maven.org/maven2/io/debezium/debezium-connector-postgres/2.3.3.Final/debezium-connector-postgres-2.3.3.Final-plugin.tar.gz && \
    curl -L -o postgres-source-connector.tar.gz.sha1 https://repo1.maven.org/maven2/io/debezium/debezium-connector-postgres/2.3.3.Final/debezium-connector-postgres-2.3.3.Final-plugin.tar.gz.sha1 && \
    echo "$(cat postgres-source-connector.tar.gz.sha1) postgres-source-connector.tar.gz" | sha1sum -c - && \
    tar -xzvf postgres-source-connector.tar.gz && \
    rm postgres-source-connector.tar.gz postgres-source-connector.tar.gz.sha1

# Download and install the bigquery sink connector from
# https://repo1.maven.org/maven2/com/wepay/kcbq/kcbq-confluent/1.6.5
RUN mkdir bigquery-sink-connector && cd bigquery-sink-connector && \
    curl -L -o bigquery-sink-connector.zip https://repo1.maven.org/maven2/com/wepay/kcbq/kcbq-confluent/1.6.5/kcbq-confluent-1.6.5.zip && \
    curl -L -o bigquery-sink-connector.zip.sha1 https://repo1.maven.org/maven2/com/wepay/kcbq/kcbq-confluent/1.6.5/kcbq-confluent-1.6.5.zip.sha1 && \
    echo "$(cat bigquery-sink-connector.zip.sha1) bigquery-sink-connector.zip" | sha1sum -c - && \
    unzip bigquery-sink-connector.zip && \
    rm bigquery-sink-connector.zip bigquery-sink-connector.zip.sha1

WORKDIR /opt/kafka

USER 1001
