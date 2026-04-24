FROM debian:bullseye

# Install RabbitMQ server and runtime dependencies
# RabbitMQ package will handle all erlang dependencies automatically
RUN apt-get update && apt-get install -y \
    rabbitmq-server \
    ca-certificates \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Create RabbitMQ logs directory
RUN mkdir -p /var/log/rabbitmq && chown -R rabbitmq:rabbitmq /var/log/rabbitmq

# Expose RabbitMQ ports (5672 for AMQP, 15672 for management)
EXPOSE 5672 15672

# Run RabbitMQ as rabbitmq user
USER rabbitmq

ENTRYPOINT ["/entrypoint.sh"]
