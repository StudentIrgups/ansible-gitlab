#!/bin/bash
NAMESPACE=${1:-gitlab}

echo "🔐 Getting GitLab root password..."

PASSWORD=$(kubectl get secret gitlab-gitlab-initial-root-password \
  -n "$NAMESPACE" \
  -o jsonpath="{.data.password}" 2>/dev/null | base64 --decode)

if [ -z "$PASSWORD" ]; then
    PASSWORD=$(kubectl get secret gitlab-secrets \
      -n "$NAMESPACE" \
      -o jsonpath="{.data.initial_root_password}" 2>/dev/null | base64 --decode)
fi

if [ -n "$PASSWORD" ]; then
    echo "=========================================="
    echo "GitLab Root Password: $PASSWORD"
    echo "=========================================="
    
    # Get worker IP
    WORKER_IP=$(kubectl get nodes -o wide --selector='!node-role.kubernetes.io/control-plane' \
      -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
    
    echo ""
    echo "Internal URL: http://${WORKER_IP}:33000"
    echo "Username: root"
    echo ""
    echo "For external access:"
    echo "ssh -L 33000:${WORKER_IP}:33000 ubuntu@<bastion-ip>"
    echo "Then open: http://localhost:33000"
else
    echo "❌ Password not found!"
    exit 1
fi