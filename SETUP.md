# Setup Guide - Fellowship K3s Cluster

Guida passo-passo per il deployment del cluster K3s su Debian 13.

---

## 📋 Indice

1. [Prerequisiti](#1-prerequisiti)
2. [Preparazione Server Debian](#2-preparazione-server-debian)
3. [Setup Ambiente Locale](#3-setup-ambiente-locale)
4. [Configurazione Inventory](#4-configurazione-inventory)
5. [Configurazione Secrets](#5-configurazione-secrets)
6. [Deploy del Cluster](#6-deploy-del-cluster)
7. [Verifica Installazione](#7-verifica-installazione)
8. [Configurazione DNS](#8-configurazione-dns)
9. [Aggiungere Worker Nodes](#9-aggiungere-worker-nodes)
10. [Rimuovere Worker Nodes](#10-rimuovere-worker-nodes)
11. [Troubleshooting](#11-troubleshooting)

---

## 1. Prerequisiti

### Sul tuo Mac/PC (control node)

- **Python 3.10+**
- **Ansible 2.15+**
- **SSH client**
- Chiave SSH (consigliato Ed25519)

### Sui server Debian

- **Debian 13 (Trixie)** freshly installed
- **Accesso SSH** come root (o utente con sudo)
- **IP statico** configurato
- **Connettività di rete** tra tutti i nodi

### Requisiti di rete

| Porta | Protocollo | Uso |
|-------|------------|-----|
| 22 | TCP | SSH |
| 6443 | TCP | Kubernetes API |
| 10250 | TCP | Kubelet |
| 8472 | UDP | Flannel VXLAN |
| 2379-2380 | TCP | etcd (solo master) |
| 80, 443 | TCP | Traefik Ingress |

### Account Cloudflare

Per i certificati Let's Encrypt via DNS challenge:

1. Account Cloudflare con il dominio `mbianchi.me`
2. API Token con permessi `Zone:DNS:Edit`

---

## 2. Preparazione Server Debian

### 2.1 Installazione Debian 13

Durante l'installazione di Debian 13:

1. Seleziona **installazione minimale** (no desktop)
2. Configura **IP statico** durante il setup di rete
3. Crea l'utente **root** con password
4. Non installare altri pacchetti extra

### 2.2 Configurazione IP Statico (se non fatto durante install)

Su ogni server, modifica `/etc/network/interfaces`:

```bash
# Esempio per aragorn
auto eth0
iface eth0 inet static
    address 192.168.1.10
    netmask 255.255.255.0
    gateway 192.168.1.1
    dns-nameservers 192.168.1.1 8.8.8.8
```

Riavvia networking:

```bash
systemctl restart networking
```

### 2.3 Configurazione SSH

Sul tuo Mac/PC, copia la chiave SSH su tutti i server:

```bash
# Se non hai una chiave SSH, creala
ssh-keygen -t ed25519 -C "fellowship-cluster"

# Copia su ogni server
ssh-copy-id root@192.168.1.10  # aragorn
ssh-copy-id root@192.168.1.11  # boromir
ssh-copy-id root@192.168.1.12  # gandalf
```

Verifica l'accesso:

```bash
ssh root@192.168.1.10 "hostname"  # Deve stampare: aragorn
ssh root@192.168.1.11 "hostname"  # Deve stampare: boromir
ssh root@192.168.1.12 "hostname"  # Deve stampare: gandalf
```

### 2.4 Configurazione Hostname (opzionale, Ansible lo fa)

Se vuoi farlo manualmente:

```bash
# Su aragorn
hostnamectl set-hostname aragorn

# Su boromir
hostnamectl set-hostname boromir

# Su gandalf
hostnamectl set-hostname gandalf
```

---

## 3. Setup Ambiente Locale

### 3.1 Clona il repository

```bash
cd ~/repos
git clone <repository-url> fellowship
cd fellowship
```

### 3.2 Crea Virtual Environment Python

```bash
# Crea venv
python3 -m venv .venv

# Attiva venv
source .venv/bin/activate

# Verifica
which python  # Deve mostrare .venv/bin/python
```

### 3.3 Installa Ansible e dipendenze

```bash
# Installa pip packages
pip install --upgrade pip
pip install ansible kubernetes

# Verifica versione
ansible --version
# Deve essere >= 2.15
```

### 3.4 Installa Ansible Collections

```bash
ansible-galaxy collection install -r requirements.yml
```

Output atteso:

```
Starting galaxy collection install process
Process install dependency map
Installing 'ansible.posix:>=1.5.0' to '~/.ansible/collections/ansible_collections/ansible/posix'
Installing 'community.general:>=8.0.0' to '~/.ansible/collections/ansible_collections/community/general'
Installing 'kubernetes.core:>=3.0.0' to '~/.ansible/collections/ansible_collections/kubernetes/core'
```

### 3.5 (Opzionale) Script automatico

Puoi usare lo script helper:

```bash
chmod +x scripts/setup.sh
./scripts/setup.sh
```

---

## 4. Configurazione Inventory

### 4.1 Modifica hosts.yml

Apri `inventory/hosts.yml` e inserisci gli IP reali:

```yaml
---
all:
  children:
    k3s_cluster:
      children:
        k3s_masters:
          hosts:
            aragorn:
              ansible_host: 192.168.1.10  # <- IP reale di aragorn
              k3s_role: server
        k3s_workers:
          hosts:
            boromir:
              ansible_host: 192.168.1.11  # <- IP reale di boromir
              k3s_role: agent
            gandalf:
              ansible_host: 192.168.1.12  # <- IP reale di gandalf
              k3s_role: agent

    nfs_servers:
      hosts:
        aragorn:

  vars:
    ansible_user: root
    ansible_python_interpreter: /usr/bin/python3
```

### 4.2 Verifica connettività

```bash
# Ping di tutti i server
ansible all -m ping
```

Output atteso:

```
aragorn | SUCCESS => {
    "ping": "pong"
}
boromir | SUCCESS => {
    "ping": "pong"
}
gandalf | SUCCESS => {
    "ping": "pong"
}
```

### 4.3 Personalizza variabili (opzionale)

Se vuoi cambiare qualcosa, modifica `inventory/group_vars/all.yml`:

```yaml
# Dominio interno
internal_domain: mb.home

# Dominio pubblico
public_domain: mbianchi.me

# Timezone
timezone: Europe/Rome

# Range IP per ServiceLB
k3s_servicelb_range: "192.168.1.201-192.168.1.220"
```

---

## 5. Configurazione Secrets

### 5.1 Crea API Token Cloudflare

1. Vai su [Cloudflare Dashboard](https://dash.cloudflare.com/profile/api-tokens)
2. Clicca **Create Token**
3. Usa template **Edit zone DNS** o crea custom:
   - **Permissions**: Zone → DNS → Edit
   - **Zone Resources**: Include → Specific zone → `mbianchi.me`
4. Copia il token generato

### 5.2 Configura secrets.yml

```bash
# Copia template
cp vault/secrets.yml.example vault/secrets.yml

# Modifica con i tuoi valori
vim vault/secrets.yml
```

Contenuto:

```yaml
---
cloudflare_api_token: "il-tuo-token-cloudflare-qui"
cloudflare_email: "tua-email@example.com"
```

### 5.3 Cripta con Ansible Vault

```bash
# Cripta il file
ansible-vault encrypt vault/secrets.yml
```

Ti chiederà una password. **Ricordala!** Ti servirà per ogni deploy.

### 5.4 (Opzionale) File password

Per evitare di digitare la password ogni volta:

```bash
# Crea file password (NON committarlo!)
echo "la-tua-password-vault" > ~/.vault_pass_fellowship
chmod 600 ~/.vault_pass_fellowship
```

Poi usa:

```bash
ansible-playbook playbooks/site.yml --vault-password-file ~/.vault_pass_fellowship
```

---

## 6. Deploy del Cluster

### 6.1 Deploy Completo

```bash
# Con password interattiva
ansible-playbook playbooks/site.yml --ask-vault-pass

# Oppure con file password
ansible-playbook playbooks/site.yml --vault-password-file ~/.vault_pass_fellowship
```

Il deploy richiede circa **15-30 minuti** e include:

1. ✅ Preparazione Debian (packages, kernel params, swap off)
2. ✅ Setup NFS server su aragorn
3. ✅ Installazione K3s master
4. ✅ Join dei worker nodes
5. ✅ Deploy Helm
6. ✅ Deploy NFS provisioner
7. ✅ Deploy cert-manager + ClusterIssuers
8. ✅ Deploy Prometheus + Grafana
9. ✅ Deploy ArgoCD

### 6.2 Deploy per Fasi

Se preferisci fare un passo alla volta:

```bash
# Solo preparazione Debian
ansible-playbook playbooks/site.yml --tags prepare --ask-vault-pass

# Solo NFS
ansible-playbook playbooks/site.yml --tags nfs --ask-vault-pass

# Solo K3s
ansible-playbook playbooks/site.yml --tags k3s --ask-vault-pass

# Solo addons
ansible-playbook playbooks/site.yml --tags addons --ask-vault-pass
```

### 6.3 Output del Deploy

Alla fine vedrai un summary come:

```
============================================================
K3s Addons Deployment Complete!
============================================================

NFS Provisioner:
  - Storage Class: nfs-client (default)
  - NFS Server: 192.168.1.10:/srv/nfs/k3s

cert-manager:
  - ClusterIssuers: letsencrypt-staging, letsencrypt-prod
  - DNS Challenge: Cloudflare

Monitoring:
  - Grafana: https://grafana.mbianchi.me
  - Default password: admin (CHANGE IT!)

GitOps:
  - ArgoCD: https://argocd.mbianchi.me
  - Password: <mostrata qui>

============================================================
```

---

## 7. Verifica Installazione

### 7.1 Configura kubectl locale

```bash
# Il kubeconfig è stato salvato automaticamente
export KUBECONFIG=$(pwd)/kubeconfig.yaml

# Aggiungi al tuo .zshrc/.bashrc per persistenza
echo 'export KUBECONFIG=~/repos/fellowship/kubeconfig.yaml' >> ~/.zshrc
```

### 7.2 Verifica nodi

```bash
kubectl get nodes
```

Output atteso:

```
NAME      STATUS   ROLES                  AGE   VERSION
aragorn   Ready    control-plane,master   10m   v1.31.2+k3s1
boromir   Ready    <none>                 8m    v1.31.2+k3s1
gandalf   Ready    <none>                 6m    v1.31.2+k3s1
```

### 7.3 Verifica pods

```bash
kubectl get pods -A
```

Tutti i pods devono essere `Running` o `Completed`.

### 7.4 Verifica storage

```bash
# Storage class
kubectl get storageclass
```

Output:

```
NAME                   PROVISIONER                            AGE
nfs-client (default)   cluster.local/nfs-provisioner-...      5m
local-path             rancher.io/local-path                  10m
```

### 7.5 Verifica cert-manager

```bash
# ClusterIssuers
kubectl get clusterissuers
```

Output:

```
NAME                  READY   AGE
letsencrypt-staging   True    5m
letsencrypt-prod      True    5m
```

### 7.6 Verifica servizi

```bash
# Grafana
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana

# ArgoCD
kubectl get pods -n argocd
```

---

## 8. Configurazione DNS

### 8.1 DNS Pubblico (Cloudflare)

Aggiungi record DNS su Cloudflare per `mbianchi.me`:

| Type | Name | Content | Proxy |
|------|------|---------|-------|
| A | grafana | (IP Tailscale o pubblico) | Off |
| A | argocd | (IP Tailscale o pubblico) | Off |

### 8.2 DNS Interno (mb.home)

Se hai un DNS interno (Pi-hole, Unbound, etc.), aggiungi:

```
aragorn.mb.home    -> 192.168.1.10
boromir.mb.home    -> 192.168.1.11
gandalf.mb.home    -> 192.168.1.12
```

### 8.3 Con Tailscale

Se usi Tailscale per accedere al cluster:

1. Installa Tailscale su aragorn
2. Usa l'IP Tailscale per i record DNS Cloudflare
3. I certificati Let's Encrypt funzioneranno comunque (DNS challenge)

---

## 9. Aggiungere Worker Nodes

### 9.1 Prepara il nuovo server

1. Installa Debian 13 sul nuovo server
2. Configura IP statico
3. Copia chiave SSH:

```bash
ssh-copy-id root@192.168.1.13  # legolas
```

### 9.2 Aggiungi all'inventory

Modifica `inventory/hosts.yml`:

```yaml
k3s_workers:
  hosts:
    boromir:
      ansible_host: 192.168.1.11
    gandalf:
      ansible_host: 192.168.1.12
    legolas:                          # <- Nuovo!
      ansible_host: 192.168.1.13
      k3s_role: agent
```

### 9.3 Esegui il playbook

```bash
# Solo sul nuovo nodo
ansible-playbook playbooks/add-worker.yml --limit legolas --ask-vault-pass
```

### 9.4 Verifica

```bash
kubectl get nodes
```

---

## 10. Rimuovere Worker Nodes

### 10.1 Drain e rimuovi

```bash
ansible-playbook playbooks/remove-worker.yml -e "node_to_remove=legolas" --ask-vault-pass
```

Questo:

1. Fa drain del nodo (sposta i pods)
2. Rimuove il nodo dal cluster
3. Disinstalla k3s dal server

### 10.2 Rimuovi dall'inventory

Modifica `inventory/hosts.yml` e rimuovi l'host.

---

## 11. Troubleshooting

### K3s non parte

```bash
# Sul master
journalctl -u k3s -f

# Sui worker
journalctl -u k3s-agent -f
```

Problemi comuni:

- **Port già in uso**: Altro processo usa la porta 6443
- **Firewall**: Porte bloccate tra i nodi
- **Swap attivo**: K3s funziona ma può dare warning

### NFS non funziona

```bash
# Sul master (aragorn)
systemctl status nfs-kernel-server
cat /etc/exports
exportfs -v

# Sui worker
showmount -e 192.168.1.10
```

### Pods in Pending (PVC)

```bash
# Controlla NFS provisioner
kubectl get pods -n nfs-provisioner
kubectl logs -n nfs-provisioner -l app=nfs-subdir-external-provisioner

# Controlla PVC
kubectl get pvc -A
kubectl describe pvc <nome> -n <namespace>
```

### Certificati non generati

```bash
# Stato certificati
kubectl get certificates -A
kubectl describe certificate <nome> -n <namespace>

# Stato challenges
kubectl get challenges -A

# Logs cert-manager
kubectl logs -n cert-manager -l app=cert-manager
```

Problemi comuni:

- **API Token errato**: Verifica il token Cloudflare
- **Permessi DNS**: Il token deve avere `Zone:DNS:Edit`
- **Rate limit**: Usa `letsencrypt-staging` per i test

### ArgoCD password dimenticata

```bash
# Reset password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### Grafana password dimenticata

Default: `admin` / `admin`

Per reset:

```bash
kubectl exec -n monitoring -it deploy/kube-prometheus-stack-grafana -- grafana-cli admin reset-admin-password newpassword
```

---

## 🎉 Fatto!

Il tuo cluster K3s è pronto. Prossimi passi consigliati:

1. **Cambia le password di default** di Grafana e ArgoCD
2. **Configura i backup** della directory NFS `/srv/nfs/k3s`
3. **Esplora ArgoCD** per deployare le tue applicazioni in modo GitOps
4. **Configura alerting** in Prometheus/Alertmanager

Buon Kubernetes! 🚀

