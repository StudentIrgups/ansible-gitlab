#!/bin/bash
NAMESPACE=${1:-gitlab}
BACKUP_DIR=${2:-/tmp/gitlab-backups}

mkdir -p "$BACKUP_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/gitlab-backup-$TIMESTAMP.tar"

echo "💾 Creating GitLab backup..."

# Get GitLab pod
POD=$(kubectl get pods -n "$NAMESPACE" -l app=toolbox -o jsonpath='{.items[0].metadata.name}')

if [ -z "$POD" ]; then
    echo "❌ GitLab toolbox pod not found!"
    exit 1
fi

# Create backup
kubectl exec -n "$NAMESPACE" "$POD" -- \
  gitlab-backup create BACKUP=$TIMESTAMP

# Copy backup to local
kubectl cp "$NAMESPACE/$POD:/var/opt/gitlab/backups/${TIMESTAMP}_gitlab_backup.tar" "$BACKUP_FILE"

echo "✅ Backup saved to: $BACKUP_FILE"

# Clean old backups (keep last 7 days)
find "$BACKUP_DIR" -name "gitlab-backup-*.tar" -mtime +7 -delete