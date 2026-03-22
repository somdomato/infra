# SDM Infra

Orquestração centralizada de Docker e Ansible para os três repositórios da Rádio Som do Mato.

```
sdm/
├── somdomato/   ← site (Next.js)
├── stream/      ← stream (Icecast + Liquidsoap)
├── chat/        ← chat (Ergo + KiwiIRC + Gamja)
└── infra/       ← este repo (Docker + Ansible)
```

Os arquivos de conteúdo (configs do Icecast, scripts do Liquidsoap, binários do Ergo, etc.)
continuam nos seus respectivos repos. Este repo contém apenas a orquestração.

---

## Docker – Desenvolvimento local

### Pré-requisitos

- Docker e Docker Compose v2
- `MUSIC_PATH` apontando para o diretório de músicas

### Comandos

```bash
cd /home/lucas/code/sdm/infra   # ou onde o monorepo estiver

# Simular VPS1 (site + stream)
make vps1

# Simular VPS2 (chat)
make vps2

# Simular tudo
make all

# Standalone (um repo de cada vez)
make site    # só o site
make stream  # só stream (icecast + liquidsoap)
make chat    # só chat (ergo + kiwiirc + gamja)

# Ajuda
make help
```

### Portas locais

| Serviço | Porta | Perfil |
|---------|-------|--------|
| Site HTTPS | `443` | vps1 |
| Site HTTP (redirect) | `8080` | vps1 |
| Icecast | `8000` | vps1 |
| Liquidsoap Harbor | `8010` | vps1 |
| KiwiIRC | `9080` | vps2 |
| Gamja | `9081` | vps2 |
| IRC plaintext | `6667` | vps2 |

### Credenciais de teste

| Serviço | Credencial |
|---------|-----------|
| Icecast admin | user `admin` / senha `hackme` |
| Liquidsoap DJ | user `dj` / senha `hackme` na porta `8010` |
| IRC oper | `/oper admin hackme` |

### Configurando o MUSIC_PATH

```bash
# Opção A: variável de ambiente
export MUSIC_PATH=/home/lucas/music/sdm

# Opção B: arquivo .env na raiz do infra/
echo "MUSIC_PATH=/home/lucas/music/sdm" > .env
```

### Certificados SSL (VPS1)

Gerados automaticamente na primeira execução do `make vps1`.
Ficam em `docker/somdomato/certs/` (ignorado pelo git).

Para regenerar:
```bash
rm -rf docker/somdomato/certs/
bash docker/somdomato/generate-certs.sh
```

---

## Ansible – Deploy em produção

### Estrutura

```
ansible/
├── somdomato/          ← VPS1 – site
│   ├── playbook.yml
│   ├── inventory.ini
│   ├── ansible.cfg
│   └── etc/           → symlink para ../somdomato/ansible/etc/
│
├── stream/             ← VPS1 – stream
│   ├── playbook.yml
│   ├── inventory.ini
│   ├── ansible.cfg
│   ├── etc/           → symlink para ../stream/ansible/etc/
│   └── usr/           → symlink para ../stream/ansible/usr/
│
└── chat/               ← VPS2 – chat
    ├── playbook.yml
    ├── inventory.ini
    ├── ansible.cfg
    ├── group_vars/
    │   ├── all.yml
    │   ├── vault.yml            → symlink para ../chat/ansible/group_vars/vault.yml
    │   └── vault.yml.encrypted  → symlink para ../chat/ansible/group_vars/vault.yml.encrypted
    ├── etc/    → symlink para ../chat/ansible/etc/
    ├── usr/    → symlink para ../chat/ansible/usr/
    ├── opt/    → symlink para ../chat/ansible/opt/
    └── working/ → symlink para ../chat/working/
```

> **Symlinks**: As árvores `etc/`, `usr/`, `opt/`, `working/` são symlinks para os repos
> correspondentes. Os playbooks funcionam com os caminhos relativos originais sem modificação.

### Deploy

```bash
# VPS1 – site
make deploy-somdomato

# VPS1 – stream
make deploy-stream

# VPS2 – chat (requer vault password em chat/ansible/.vault_pass)
make deploy-chat
```

### Vault do chat

O vault fica em `chat/ansible/group_vars/vault.yml` (repo chat).
Para editar:

```bash
cd ../chat
./scripts/vault.sh edit
```

O symlink `ansible/chat/group_vars/vault.yml` garante que o playbook sempre usa
a versão mais atual do vault sem necessidade de cópia manual.

---

## Plano de migração (remover docker/ e ansible/ dos repos)

Os diretórios `docker/` e `ansible/` originais de cada repo **ainda existem** e continuam
funcionando. Este repo é a nova fonte canônica.

### Quando migrar (checklist por repo)

- [ ] Testar `make vps1` e `make vps2` com sucesso
- [ ] Validar deploy Ansible via `make deploy-*` em staging
- [ ] Atualizar CI/CD para usar `infra/` como ponto de entrada
- [ ] Remover `docker/` e `ansible/` dos repos individuais
- [ ] Atualizar READMEs dos repos individuais

### Remover com segurança (por repo, após validação)

```bash
# somdomato
cd ../somdomato
git rm -r docker/ ansible/
git commit -m "chore: mover docker e ansible para infra/"

# stream
cd ../stream
git rm -r docker/ ansible/
git commit -m "chore: mover docker e ansible para infra/"

# chat
cd ../chat
git rm -r docker/ ansible/
git commit -m "chore: mover docker e ansible para infra/"
```

> ⚠ **Não deletar** `stream/ansible/etc/` e `chat/ansible/usr/` — esses diretórios
> contêm os arquivos de conteúdo (configs, binários) referenciados pelos symlinks do infra.
> Apenas `playbook.yml`, `ansible.cfg`, `inventory.ini` devem ser removidos dos repos.

---

## Estrutura de arquivos

```
infra/
├── Makefile
├── docker-compose.yml          ← orquestração completa (perfis vps1/vps2)
├── docker/
│   ├── somdomato/
│   │   ├── docker-compose.yml  ← standalone
│   │   ├── Dockerfile.nextjs
│   │   ├── Dockerfile.liquidsoap
│   │   ├── nginx.dev.conf
│   │   ├── generate-certs.sh
│   │   └── certs/              ← gerado localmente (gitignored)
│   ├── stream/
│   │   ├── docker-compose.yml  ← standalone
│   │   ├── Dockerfile.liquidsoap
│   │   ├── icecast.docker.xml
│   │   └── somdomato.docker.liq
│   └── chat/
│       ├── docker-compose.yml  ← standalone
│       ├── Dockerfile.ergo
│       ├── Dockerfile.webircgateway
│       ├── Dockerfile.nginx
│       ├── ircd.docker.yaml
│       ├── nginx.conf
│       ├── webircgateway.docker.conf
│       ├── kiwiirc.client.json
│       └── gamja.config.json
└── ansible/
    ├── somdomato/
    ├── stream/
    └── chat/
```
