---
# Optional: Kubernetes Dashboard Installation
# Provides visual monitoring of cluster resources
#
# Install with: kubectl apply -f Manifests/optional-kubernetes-dashboard.yaml
# Access with: kubectl proxy then visit http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/

apiVersion: v1
kind: Namespace
metadata:
  name: kubernetes-dashboard
---

# Note: The actual Kubernetes Dashboard is installed from the official repository

# Run these commands manually after cluster is running:

#

# kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml

#

# Then access via:

# kubectl proxy

# Visit: http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/

#

# Get authentication token:

# kubectl -n kubernetes-dashboard create token admin-user

#

# Note: This is a recommended optional component for monitoring and auditing purposes
