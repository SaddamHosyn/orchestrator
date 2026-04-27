---
# Optional: Logging Stack (Loki + Grafana)
# Provides centralized log aggregation and visualization
#
# This is an optional enhancement recommended for production environments
# Installation requires Helm

apiVersion: v1
kind: Namespace
metadata:
  name: monitoring
---

# Note: Loki + Grafana setup requires Helm

#

# Installation Steps:

#

# 1. Add Grafana Helm repository:

# helm repo add grafana https://grafana.github.io/helm-charts

# helm repo update

#

# 2. Install Loki Stack:

# helm install loki grafana/loki-stack \

# -n monitoring \

# --create-namespace

#

# 3. Port-forward to Grafana:

# kubectl port-forward -n monitoring svc/loki-grafana 3000:80

#

# 4. Access Grafana:

# URL: http://localhost:3000

# Default credentials: admin / prom-operator

#

# 5. Add Loki as data source:

# - URL: http://loki:3100

# - Save and test

#

# This provides:

# - Centralized logging from all pods

# - Log querying and aggregation

# - Visual dashboards

# - Alert capabilities

#

# Note: This is a recommended optional component for production environments

# Demonstrates observability and DevOps best practices
