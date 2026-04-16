#!/bin/bash
NAMESPACE=${1:-gitlab}

echo "🔍 Checking GitLab status in namespace: $NAMESPACE"
echo ""

echo "📦 Pods:"
kubectl get pods -n "$NAMESPACE"

echo ""
echo "🌐 Services:"
kubectl get svc -n "$NAMESPACE"

echo ""
echo "💾 PVCs:"
kubectl get pvc -n "$NAMESPACE"

echo ""
echo "📊 Pod status summary:"
kubectl get pods -n "$NAMESPACE" --no-headers | \
  awk '{print $3}' | sort | uniq -c

echo ""
echo "🔄 Checking GitLab webservice health..."
kubectl exec -n "$NAMESPACE" deploy/gitlab-webservice-default -- \
  curl -s -o /dev/null -w "%{http_code}" http://localhost:8181/-/health || echo "Not ready"