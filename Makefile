# SDM Infra – Makefile
#
# Todos os comandos devem ser executados a partir de infra/:
#   cd /home/lucas/code/sdm/infra
#   make vps1
#
# O diretório de trabalho pode variar. Os repos são sempre referenciados
# por caminhos relativos (../somdomato, ../stream, ../chat).

MUSIC_PATH ?= /home/lucas/music/sdm

# ─────────────────────────────────────────────
# Stacks completas (simulam as VPS)
# ─────────────────────────────────────────────

.PHONY: vps1
vps1: certs  ## VPS1: site (Next.js + Nginx) + stream (Icecast + Liquidsoap)
	MUSIC_PATH=$(MUSIC_PATH) docker compose --profile vps1 up -d --build
	@echo ""
	@echo "VPS1 pronta:"
	@echo "  Site:    https://localhost"
	@echo "  Stream:  http://localhost:8000/radio.mp3"
	@echo "  Harbor:  localhost:8010  (broadcast ao vivo)"

.PHONY: vps2
vps2:  ## VPS2: chat (Ergo + KiwiIRC + Gamja)
	docker compose --profile vps2 up -d --build
	@echo ""
	@echo "VPS2 pronta:"
	@echo "  KiwiIRC: http://localhost:9080"
	@echo "  Gamja:   http://localhost:9081"
	@echo "  IRC:     irc://localhost:6667"
	@echo "  Oper:    /oper admin hackme"

.PHONY: all
all: certs  ## Sobe tudo (VPS1 + VPS2)
	MUSIC_PATH=$(MUSIC_PATH) docker compose --profile vps1 --profile vps2 up -d --build

.PHONY: down
down:  ## Para todos os containers
	docker compose --profile vps1 --profile vps2 down

.PHONY: down-vps1
down-vps1:  ## Para VPS1
	docker compose --profile vps1 down

.PHONY: down-vps2
down-vps2:  ## Para VPS2
	docker compose --profile vps2 down

# ─────────────────────────────────────────────
# Repos standalone (foco em um serviço só)
# ─────────────────────────────────────────────

.PHONY: site
site: certs  ## Standalone: site somdomato (Next.js + Nginx + Icecast somdomato)
	MUSIC_PATH=$(MUSIC_PATH) docker compose -f docker/somdomato/docker-compose.yml up -d --build
	@echo "Site: https://localhost"

.PHONY: site-down
site-down:
	docker compose -f docker/somdomato/docker-compose.yml down

.PHONY: stream
stream:  ## Standalone: stream (Icecast + Liquidsoap sem Next.js)
	MUSIC_PATH=$(MUSIC_PATH) docker compose -f docker/stream/docker-compose.yml up -d --build
	@echo "Stream: http://localhost:8000/radio.mp3"

.PHONY: stream-down
stream-down:
	docker compose -f docker/stream/docker-compose.yml down

.PHONY: chat
chat:  ## Standalone: chat (Ergo + KiwiIRC + Gamja)
	docker compose -f docker/chat/docker-compose.yml up -d --build
	@echo "KiwiIRC: http://localhost:9080  |  Gamja: http://localhost:9081"

.PHONY: chat-down
chat-down:
	docker compose -f docker/chat/docker-compose.yml down

# ─────────────────────────────────────────────
# Ansible – deploy em produção
# ─────────────────────────────────────────────

.PHONY: deploy-somdomato
deploy-somdomato:  ## Ansible: provisiona VPS1 (somdomato)
	cd ansible/somdomato && ansible-playbook -i inventory.ini playbook.yml

.PHONY: deploy-stream
deploy-stream:  ## Ansible: provisiona VPS1 (stream – icecast/liquidsoap)
	cd ansible/stream && ansible-playbook -i inventory.ini playbook.yml

.PHONY: deploy-chat
deploy-chat:  ## Ansible: provisiona VPS2 (chat)
	cd ansible/chat && \
	    ansible-playbook -i inventory.ini playbook.yml \
	    --vault-password-file ../../../chat/ansible/.vault_pass

# ─────────────────────────────────────────────
# Utilitários
# ─────────────────────────────────────────────

.PHONY: certs
certs:  ## Gera certificados SSL para VPS1 (necessário antes da primeira execução)
	@if [ ! -f docker/somdomato/certs/selfsigned.crt ]; then \
		echo "Gerando certificados SSL..."; \
		bash docker/somdomato/generate-certs.sh; \
	fi

.PHONY: ps
ps:  ## Lista containers ativos
	docker compose --profile vps1 --profile vps2 ps

.PHONY: logs
logs:  ## Logs de todos os containers
	docker compose --profile vps1 --profile vps2 logs -f

.PHONY: logs-vps1
logs-vps1:  ## Logs da VPS1
	docker compose --profile vps1 logs -f

.PHONY: logs-vps2
logs-vps2:  ## Logs da VPS2
	docker compose --profile vps2 logs -f

.PHONY: rebuild
rebuild:  ## Reconstrói todas as imagens sem cache
	MUSIC_PATH=$(MUSIC_PATH) docker compose --profile vps1 --profile vps2 build --no-cache

.PHONY: clean
clean: down  ## Para containers e remove volumes nomeados (⚠ apaga DB do Ergo)
	docker compose --profile vps1 --profile vps2 down -v

.PHONY: help
help:  ## Exibe esta ajuda
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

.DEFAULT_GOAL := help
