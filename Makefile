.PHONY: deploy check backup encrypt decrypt password vault-init vault-edit vault-view vault-rekey vault-rotate clean install-deps test logs help

# Переменные
VAULT_FILE = inventory/production/group_vars/all/vault.yml
VAULT_PASS_FILE = .vault_pass
ANSIBLE_PLAYBOOK = deploy-gitlab.yml
INVENTORY = inventory/production/hosts.yml

help: ## Показать эту справку
	@echo "Доступные команды:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

# Основные команды
deploy: ## Развернуть GitLab
	ansible-playbook -i $(INVENTORY) $(ANSIBLE_PLAYBOOK) --vault-password-file $(VAULT_PASS_FILE)

check: ## Проверить плейбук без выполнения
	ansible-playbook -i $(INVENTORY) $(ANSIBLE_PLAYBOOK) --check --vault-password-file $(VAULT_PASS_FILE)

diff: ## Показать изменения
	ansible-playbook -i $(INVENTORY) $(ANSIBLE_PLAYBOOK) --diff --vault-password-file $(VAULT_PASS_FILE)

syntax: ## Проверить синтаксис
	ansible-playbook -i $(INVENTORY) $(ANSIBLE_PLAYBOOK) --syntax-check

# Vault команды
vault-init: ## Инициализировать vault (создать пароль и файл)
	@echo "🔐 Инициализация Ansible Vault..."
	@if [ ! -f $(VAULT_PASS_FILE) ]; then \
		echo "Создание файла пароля vault..."; \
		openssl rand -base64 32 > $(VAULT_PASS_FILE); \
		chmod 600 $(VAULT_PASS_FILE); \
		echo "✅ Пароль vault сохранен в $(VAULT_PASS_FILE)"; \
	else \
		echo "⚠️  Файл пароля уже существует: $(VAULT_PASS_FILE)"; \
	fi
	@if [ ! -f $(VAULT_FILE) ]; then \
		echo "📝 Создание нового зашифрованного файла vault..."; \
		echo "Вставьте следующее содержимое:"; \
		echo "---"; \
		echo "gitlab_root_password: \"\""; \
		echo "gitlab_runner_token: \"\""; \
		echo "gitlab_initial_shared_runners_token: \"\""; \
		echo "s3_access_key: \"\""; \
		echo "s3_secret_key: \"\""; \
		echo "smtp_user: \"\""; \
		echo "smtp_password: \"\""; \
		ansible-vault create $(VAULT_FILE) --vault-password-file $(VAULT_PASS_FILE); \
		echo "✅ Vault файл создан: $(VAULT_FILE)"; \
	else \
		echo "⚠️  Vault файл уже существует: $(VAULT_FILE)"; \
	fi

vault-create: ## Принудительно создать новый vault файл
	@if [ ! -f $(VAULT_PASS_FILE) ]; then \
		openssl rand -base64 32 > $(VAULT_PASS_FILE); \
		chmod 600 $(VAULT_PASS_FILE); \
		echo "✅ Создан пароль vault: $(VAULT_PASS_FILE)"; \
	fi
	@echo "📝 Создание vault файла с шаблоном..."
	@ansible-vault create $(VAULT_FILE) --vault-password-file $(VAULT_PASS_FILE)

vault-edit: ## Редактировать vault файл
	ansible-vault edit $(VAULT_FILE) --vault-password-file $(VAULT_PASS_FILE)

vault-view: ## Просмотреть vault файл
	ansible-vault view $(VAULT_FILE) --vault-password-file $(VAULT_PASS_FILE)

vault-decrypt: ## Расшифровать vault файл (создаст незашифрованную копию)
	ansible-vault decrypt $(VAULT_FILE) --vault-password-file $(VAULT_PASS_FILE)

vault-encrypt: ## Зашифровать существующий файл
	ansible-vault encrypt $(VAULT_FILE) --vault-password-file $(VAULT_PASS_FILE)

vault-rekey: ## Сменить пароль vault
	ansible-vault rekey $(VAULT_FILE) --vault-password-file $(VAULT_PASS_FILE)

vault-rotate: ## Сгенерировать новый пароль и перешифровать
	@echo "🔄 Смена пароля vault..."
	@cp $(VAULT_PASS_FILE) $(VAULT_PASS_FILE).old
	@openssl rand -base64 32 > $(VAULT_PASS_FILE)
	@chmod 600 $(VAULT_PASS_FILE)
	@ansible-vault rekey --new-vault-password-file $(VAULT_PASS_FILE) \
		--vault-password-file $(VAULT_PASS_FILE).old $(VAULT_FILE)
	@rm $(VAULT_PASS_FILE).old
	@echo "✅ Пароль vault обновлен"

vault-pass-show: ## Показать текущий пароль vault
	@if [ -f $(VAULT_PASS_FILE) ]; then \
		echo "📋 Текущий пароль vault:"; \
		cat $(VAULT_PASS_FILE); \
	else \
		echo "❌ Файл пароля не найден: $(VAULT_PASS_FILE)"; \
	fi

vault-backup: ## Создать бэкап vault файла
	@mkdir -p backups
	@cp $(VAULT_FILE) backups/vault-$(shell date +%Y%m%d_%H%M%S).yml
	@echo "✅ Бэкап vault создан в директории backups/"

vault-restore: ## Восстановить vault из бэкапа
	@echo "Доступные бэкапы:"
	@ls -1 backups/vault-*.yml 2>/dev/null || echo "Бэкапы не найдены"
	@read -p "Введите имя файла для восстановления: " file; \
	if [ -f "backups/$$file" ]; then \
		cp "backups/$$file" $(VAULT_FILE); \
		echo "✅ Vault восстановлен из backups/$$file"; \
	else \
		echo "❌ Файл не найден"; \
	fi

vault-template: ## Показать шаблон для vault файла
	@echo "Шаблон для $(VAULT_FILE):"
	@echo "---"
	@echo "# GitLab Secrets"
	@echo "gitlab_root_password: \"SuperSecretPassword123!\""
	@echo "gitlab_runner_token: \"GR1348941your-runner-token-here\""
	@echo "gitlab_initial_shared_runners_token: \"your-shared-runner-token\""
	@echo ""
	@echo "# S3 Backup Credentials (опционально)"
	@echo "s3_access_key: \"YCAJE...\""
	@echo "s3_secret_key: \"YCM7W...\""
	@echo ""
	@echo "# SMTP Credentials (опционально)"
	@echo "smtp_user: \"gitlab@your-domain.com\""
	@echo "smtp_password: \"smtp-password\""

vault-check: ## Проверить что vault доступен
	@echo "🔍 Проверка vault..."
	@if [ ! -f $(VAULT_PASS_FILE) ]; then \
		echo "❌ Файл пароля не найден: $(VAULT_PASS_FILE)"; \
		echo "Выполните: make vault-init"; \
		exit 1; \
	fi
	@if [ ! -f $(VAULT_FILE) ]; then \
		echo "❌ Vault файл не найден: $(VAULT_FILE)"; \
		echo "Выполните: make vault-init"; \
		exit 1; \
	fi
	@if ansible-vault view $(VAULT_FILE) --vault-password-file $(VAULT_PASS_FILE) > /dev/null 2>&1; then \
		echo "✅ Vault доступен и может быть расшифрован"; \
	else \
		echo "❌ Ошибка расшифровки vault. Проверьте пароль."; \
		exit 1; \
	fi

# Статус и мониторинг
status: ## Проверить статус GitLab
	./scripts/check-gitlab-status.sh

password: ## Получить пароль root
	./scripts/get-gitlab-password.sh

logs: ## Показать логи GitLab
	kubectl logs -n gitlab -l app=webservice --tail=100

describe: ## Описать поды GitLab
	kubectl describe pods -n gitlab

# Бэкап и восстановление
backup: ## Создать бэкап GitLab
	./scripts/backup-gitlab.sh

backup-list: ## Показать список бэкапов
	@ls -lh /tmp/gitlab-backups/ 2>/dev/null || echo "Бэкапы не найдены"

# Установка и настройка
install-deps: ## Установить зависимости Ansible
	ansible-galaxy collection install -r requirements.yml
	@command -v kubectl > /dev/null || echo "⚠️  kubectl не установлен"
	@command -v helm > /dev/null || echo "⚠️  helm не установлен"

setup: install-deps vault-init ## Полная настройка окружения
	@echo "✅ Окружение настроено. Теперь выполните:"
	@echo "   1. make vault-edit  (добавьте секреты)"
	@echo "   2. make deploy      (развернуть GitLab)"

# Очистка
clean: ## Очистить временные файлы
	rm -f /tmp/gitlab-values.yaml
	rm -f /tmp/gitlab-access.txt
	rm -f *.retry

clean-all: clean ## Очистить все включая vault (ОПАСНО!)
	@read -p "Это удалит vault файлы! Вы уверены? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		rm -f $(VAULT_PASS_FILE); \
		rm -f $(VAULT_FILE); \
		echo "✅ Vault файлы удалены"; \
	else \
		echo "❌ Отменено"; \
	fi

# Тестирование
test: syntax ## Запустить все тесты
	@echo "✅ Все тесты пройдены"

inventory: ## Показать инвентарь
	ansible-inventory -i $(INVENTORY) --list

inventory-graph: ## Показать структуру инвентаря
	ansible-inventory -i $(INVENTORY) --graph

# Debug команды
debug-vars: ## Показать все переменные
	ansible -i $(INVENTORY) bastion -m setup

debug-gitlab: ## Отладка GitLab установки
	@echo "=== Namespace ==="
	kubectl get namespace $(gitlab_namespace) 2>/dev/null || echo "Не найден"
	@echo ""
	@echo "=== Pods ==="
	kubectl get pods -n gitlab 2>/dev/null || echo "Не найдены"
	@echo ""
	@echo "=== Services ==="
	kubectl get svc -n gitlab 2>/dev/null || echo "Не найдены"
	@echo ""
	@echo "=== PVC ==="
	kubectl get pvc -n gitlab 2>/dev/null || echo "Не найдены"
	@echo ""
	@echo "=== Secrets ==="
	kubectl get secrets -n gitlab 2>/dev/null || echo "Не найдены"

# Хелперы для CI/CD
ci-check: vault-check syntax ## Проверки для CI/CD
	@echo "✅ CI проверки пройдены"

ci-deploy: ci-check deploy ## Деплой для CI/CD
	@echo "✅ Деплой завершен"

# Информация о доступе
info: ## Показать информацию о доступе
	@echo "📊 Информация о доступе к GitLab:"
	@if [ -f /tmp/gitlab-access.txt ]; then \
		cat /tmp/gitlab-access.txt; \
	else \
		echo "Информация не найдена. Выполните деплой: make deploy"; \
	fi
	@echo ""
	@echo "🌐 Для доступа используйте SSH туннель:"
	@WORKER_IP=$$(kubectl get nodes -o wide --selector='!node-role.kubernetes.io/control-plane' -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null); \
	if [ -n "$$WORKER_IP" ]; then \
		echo "ssh -L 33000:$$WORKER_IP:33000 ubuntu@<bastion-ip>"; \
		echo "Затем откройте: http://localhost:33000"; \
	else \
		echo "Не удалось определить IP worker ноды"; \
	fi