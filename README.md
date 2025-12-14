# Fellowship - K3s Cluster on Debian 13

Automazione Ansible per il deployment di un cluster Kubernetes (K3s) su Debian 13 Trixie.

## 🏰 Il Cluster

```
                            ┌─────────────────────────────────────┐
                            │          mb.home network            │
                            └─────────────────────────────────────┘
                                            │
            ┌───────────────────────────────┼───────────────────────────────┐
            │                               │                               │
     ┌──────┴──────┐                 ┌──────┴──────┐                 ┌──────┴──────┐
     │   aragorn   │                 │   boromir   │                 │   gandalf   │
     │─────────────│                 │─────────────│                 │─────────────│
     │ k3s server  │◄────────────────│ k3s agent   │                 │ k3s agent   │
     │ NFS server  │                 │             │                 │             │
     │ (master)    │                 │  (worker)   │                 │  (worker)   │
     └─────────────┘                 └─────────────┘                 └─────────────┘
```

## 📦 Stack Tecnologico

| Layer | Componente | Descrizione |
|-------|------------|-------------|
| **Orchestration** | K3s v1.31 | Kubernetes leggero |
| **Networking** | Flannel | CNI |
| **Ingress** | Traefik | Reverse proxy + TLS termination |
| **Load Balancer** | ServiceLB | IP pool: `192.168.1.201-220` |
| **Storage** | NFS + provisioner | Volumi persistenti su aragorn |
| **TLS** | cert-manager | Let's Encrypt via Cloudflare DNS |
| **Monitoring** | Prometheus + Grafana | Metriche e dashboard |
| **GitOps** | ArgoCD | Continuous Delivery |

## 🚀 Quick Start

```bash
# 1. Setup ambiente
./scripts/setup.sh

# 2. Configura inventory (modifica gli IP)
vim inventory/hosts.yml

# 3. Configura secrets Cloudflare
cp vault/secrets.yml.example vault/secrets.yml
vim vault/secrets.yml
ansible-vault encrypt vault/secrets.yml

# 4. Deploy!
ansible-playbook playbooks/site.yml --ask-become-pass --ask-vault-pass
```

👉 **Per istruzioni dettagliate, leggi [SETUP.md](SETUP.md)**

## 📖 Playbooks

| Playbook | Comando | Descrizione |
|----------|---------|-------------|
| **Full deploy** | `ansible-playbook playbooks/site.yml` | Deploy completo |
| **Solo Debian** | `ansible-playbook playbooks/site.yml --tags prepare` | Setup base OS |
| **Solo NFS** | `ansible-playbook playbooks/site.yml --tags nfs` | NFS server |
| **Solo K3s** | `ansible-playbook playbooks/site.yml --tags k3s` | Cluster K3s |
| **Solo Addons** | `ansible-playbook playbooks/site.yml --tags addons` | Helm, monitoring, etc |
| **Add worker** | `ansible-playbook playbooks/add-worker.yml --limit <host>` | Nuovo nodo |
| **Remove worker** | `ansible-playbook playbooks/remove-worker.yml -e node_to_remove=<host>` | Rimuovi nodo |
| **Reset cluster** | `ansible-playbook playbooks/reset-cluster.yml` | Rimuovi tutto |
| **Uptime Kuma** | `ansible-playbook playbooks/apps/uptime-kuma.yml` | Status page |

## 🌐 Servizi

Dopo il deploy:

| Servizio | URL | Credenziali |
|----------|-----|-------------|
| Grafana | `https://grafana.mbianchi.me` | admin / (vedi output) |
| ArgoCD | `https://argocd.mbianchi.me` | admin / (vedi output) |

## 📁 Struttura

```
fellowship/
├── ansible.cfg              # Config Ansible
├── requirements.yml         # Dependencies
├── inventory/
│   ├── hosts.yml           # Server inventory
│   └── group_vars/         # Variabili per gruppo
├── playbooks/              # Tutti i playbook
├── vault/                  # Secrets (encrypted)
└── scripts/                # Script helper
```

## 📜 License

MIT
