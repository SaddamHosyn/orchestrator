# Dockerfiles Build Guide

This folder contains all Dockerfiles and necessary files to build Docker images for the microservices.

## Directory Structure

```
Dockerfiles/
├── api-gateway/
│   ├── Dockerfile
│   └── requirements.txt
├── inventory-app/
│   ├── Dockerfile
│   └── requirements.txt
├── billing-app/
│   ├── Dockerfile
│   └── requirements.txt
├── inventory-database/
│   ├── Dockerfile
│   └── entrypoint.sh
├── billing-database/
│   ├── Dockerfile
│   └── entrypoint.sh
└── rabbitmq/
    ├── Dockerfile
    └── entrypoint.sh
```

## Building Images

### Prerequisites

- Docker installed and running
- Docker Hub account
- All source code from `../srcs/` directory available

### Step-by-Step Build Instructions

#### 1. Copy Application Source Code

Copy the application code from `srcs/` into each Dockerfile directory:

```bash
# From the orchestrator/ root directory

# API Gateway
cp srcs/api-gateway-app/app Dockerfiles/api-gateway/
cp srcs/api-gateway-app/server.py Dockerfiles/api-gateway/

# Inventory App
cp srcs/inventory-app/app Dockerfiles/inventory-app/
cp srcs/inventory-app/server.py Dockerfiles/inventory-app/

# Billing App
cp srcs/billing-app/app Dockerfiles/billing-app/
cp srcs/billing-app/server.py Dockerfiles/billing-app/
```

#### 2. Build Each Image

Replace `YOUR_USERNAME` with your Docker Hub username:

```bash
# Build API Gateway
docker build -t YOUR_USERNAME/api-gateway:1.0 ./Dockerfiles/api-gateway/
docker push YOUR_USERNAME/api-gateway:1.0

# Build Inventory App
docker build -t YOUR_USERNAME/inventory-app:1.0 ./Dockerfiles/inventory-app/
docker push YOUR_USERNAME/inventory-app:1.0

# Build Billing App
docker build -t YOUR_USERNAME/billing-app:1.0 ./Dockerfiles/billing-app/
docker push YOUR_USERNAME/billing-app:1.0

# Build Inventory Database
docker build -t YOUR_USERNAME/inventory-database:1.0 ./Dockerfiles/inventory-database/
docker push YOUR_USERNAME/inventory-database:1.0

# Build Billing Database
docker build -t YOUR_USERNAME/billing-database:1.0 ./Dockerfiles/billing-database/
docker push YOUR_USERNAME/billing-database:1.0

# Build RabbitMQ
docker build -t YOUR_USERNAME/rabbitmq:1.0 ./Dockerfiles/rabbitmq/
docker push YOUR_USERNAME/rabbitmq:1.0
```

#### 3. Verify Images on Docker Hub

Visit https://hub.docker.com/repositories to confirm all 6 images are:

- ✅ Public (not private)
- ✅ Tagged as `1.0`
- ✅ Ready to pull

#### 4. Update Kubernetes Manifests

Once images are pushed, update all Kubernetes manifests in `Manifests/` folder:

```bash
# Replace all instances of 'yourusername' with your actual Docker Hub username
sed -i 's/yourusername/YOUR_USERNAME/g' ../Manifests/*.yaml
```

## Image Specifications

### Application Images (Python Flask)

- **Base Image**: `debian:bullseye`
- **Python Version**: 3.9
- **Ports**: 3000 (api-gateway), 8080 (inventory-app, billing-app)
- **Dependencies**: Flask, requests, psycopg2-binary, pika, python-dotenv

### Database Images (PostgreSQL)

- **Base Image**: `debian:bullseye`
- **PostgreSQL Version**: 13
- **Port**: 5432
- **Features**: Auto-initialization, network access configuration

### Message Broker Image (RabbitMQ)

- **Base Image**: `debian:bullseye`
- **RabbitMQ Version**: Latest from Debian repo
- **Ports**: 5672 (AMQP), 15672 (Management UI)
- **Features**: Management plugin enabled, user setup automation

## Troubleshooting

### Build Fails - Application Code Not Found

```
Error: source code not found or missing files
Solution: Ensure you copied app/ and server.py from srcs/ before building
```

### Push Fails - Authentication Required

```
Error: denied: requested access to the resource is denied
Solution: docker login with your Docker Hub credentials
```

### Image Size Issues

If images are too large:

1. Use `.dockerignore` to exclude unnecessary files
2. Consider multi-stage builds for optimization
3. Use alpine-based images instead of debian (optional)

### Local Testing

Test images locally before pushing:

```bash
# Run a database container
docker run -e POSTGRES_PASSWORD=testpass -p 5432:5432 YOUR_USERNAME/inventory-database:1.0

# Run an app container
docker run -e INVENTORY_IP=localhost -e GATEWAY_PORT=3000 -p 3000:3000 YOUR_USERNAME/api-gateway:1.0
```

## Important Notes

1. **Image Naming**
   - Format: `YOUR_USERNAME/service-name:1.0`
   - Do NOT use `latest` tag
   - Use semantic versioning (1.0, 1.1, etc.)

2. **Public vs Private**
   - All images MUST be public
   - Kubernetes won't be able to pull private images without authentication

3. **Image Tags**
   - Tag format: `service:version`
   - Example: `johndoe/api-gateway:1.0`

4. **Reproducibility**
   - Always use specific base image versions
   - Document any custom configurations
   - Keep Dockerfiles simple and maintainable

## Build Automation

For convenience, create a build script `build-all.sh`:

```bash
#!/bin/bash

USERNAME=$1

if [ -z "$USERNAME" ]; then
    echo "Usage: ./build-all.sh YOUR_DOCKER_HUB_USERNAME"
    exit 1
fi

services=("api-gateway" "inventory-app" "billing-app" "inventory-database" "billing-database" "rabbitmq")

for service in "${services[@]}"; do
    echo "Building $service..."
    docker build -t $USERNAME/$service:1.0 ./Dockerfiles/$service/
    docker push $USERNAME/$service:1.0
    echo "✅ $service pushed to Docker Hub"
done

echo "✅ All images built and pushed successfully!"
```

Run with:

```bash
chmod +x build-all.sh
./build-all.sh YOUR_USERNAME
```

## Next Steps

1. ✅ Ensure all Dockerfiles are in place
2. ⬜ Copy application source code from srcs/
3. ⬜ Build all Docker images locally
4. ⬜ Push to Docker Hub
5. ⬜ Verify images are PUBLIC
6. ⬜ Update Kubernetes manifests with your username
7. ⬜ Deploy to K3s cluster

## Support

For issues with building:

1. Check Docker is running: `docker ps`
2. Verify authentication: `docker login`
3. Check image exists locally: `docker images`
4. Review Docker build output for errors
5. Consult Docker documentation: https://docs.docker.com/

---

**Last Updated**: April 27, 2026
