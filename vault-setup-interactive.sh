#!/bin/bash
# Интерактивная настройка vault с запросом значений

VAULT_FILE="inventory/production/group_vars/all/vault.yml"
VAULT_PASS_FILE=".vault_pass"

echo "🔐 Интерактивная настройка Ansible Vault"
echo "========================================="
echo ""

# Создаем пароль если нет
if [ ! -f "$VAULT_PASS_FILE" ]; then
    echo "Создание пароля vault..."
    openssl rand -base64 32 > "$VAULT_PASS_FILE"
    chmod 600 "$VAULT_PASS_FILE"
    echo "✅ Пароль сохранен в $VAULT_PASS_FILE"
fi

# Запрашиваем значения
echo "Введите значения для vault (оставьте пустым для пропуска):"
echo ""

read -p "GitLab Root Password: " gitlab_password
read -p "GitLab Runner Token: " runner_token
read -p "S3 Access Key (опционально): " s3_access
read -p "S3 Secret Key (опционально): " s3_secret
read -p "SMTP User (опционально): " smtp_user
read -s -p "SMTP Password (опционально): " smtp_pass
echo ""

# Создаем временный файл
TEMP_VAULT=$(mktemp)

cat > "$TEMP_VAULT" << EOF
---
# GitLab Secrets
gitlab_root_password: "${gitlab_password:-changeme}"
gitlab_runner_token: "${runner_token:-token-here}"
gitlab_initial_shared_runners_token: "${runner_token:-token-here}"

# S3 Backup Credentials
s3_access_key: "${s3_access}"
s3_secret_key: "${s3_secret}"

# SMTP Credentials
smtp_user: "${smtp_user}"
smtp_password: "${smtp_pass}"
EOF

# Шифруем файл
ansible-vault encrypt "$TEMP_VAULT" --vault-password-file "$VAULT_PASS_FILE"

# Перемещаем в нужное место
mv "$TEMP_VAULT" "$VAULT_FILE"

echo ""
echo "✅ Vault файл создан: $VAULT_FILE"
echo ""
echo "Для редактирования используйте: make vault-edit"