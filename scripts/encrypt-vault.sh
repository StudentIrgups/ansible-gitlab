#!/bin/bash

VAULT_FILE="inventory/production/group_vars/all/vault.yml"
PASS_FILE=".vault_pass"

# Check if password file exists
if [ ! -f "$PASS_FILE" ]; then
    echo "Creating vault password file..."
    openssl rand -base64 32 > "$PASS_FILE"
    chmod 600 "$PASS_FILE"
    echo "✅ Vault password saved to $PASS_FILE"
fi

# Create or edit vault file
if [ ! -f "$VAULT_FILE" ]; then
    echo "Creating new vault file..."
    ansible-vault create "$VAULT_FILE" --vault-password-file "$PASS_FILE"
else
    echo "Editing existing vault file..."
    ansible-vault edit "$VAULT_FILE" --vault-password-file "$PASS_FILE"
fi