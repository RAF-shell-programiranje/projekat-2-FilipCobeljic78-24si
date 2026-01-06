[![Review Assignment Due Date](https://classroom.github.com/assets/deadline-readme-button-22041afd0340ce965d47ae6ef1cefeee28c7c493a6346c4f15d667ab976d596c.svg)](https://classroom.github.com/a/32TZnzb7)

# Projekat 2 - Automatizovani Deployment i Monitoring Dummy Service Aplikacije

## 📋 Sadržaj

- [Opis Rešenja](#-opis-rešenja)
- [Arhitektura Sistema](#-arhitektura-sistema)
- [Preduslov](#-preduslov)
- [Brzo Pokretanje](#-brzo-pokretanje)
- [Glavna Skripta - automatic_deploy.sh](#-glavna-skripta---automatic_deploysh)
- [Komponente Sistema](#-komponente-sistema)
- [Monitoring i Alerting](#-monitoring-i-alerting)
- [Troubleshooting](#-troubleshooting)
- [Dodatne Informacije](#-dodatne-informacije)

---

## 🎯 Opis Rešenja

Ovo rešenje implementira **potpuno automatizovan deployment pipeline** za Java Dummy Service aplikaciju na Azure cloud infrastrukturu, sa integrisanim monitoring sistemom i email alerting-om.

### Ključne Karakteristike:

✅ **Infrastruktura kao Kod (IaC)** - Terraform za Azure resurse  
✅ **Automatizacija Konfiguracije** - Ansible playbooks za deployment  
✅ **Centralizovana Orkestracija** - Pojedinačna skripta (`automatic_deploy.sh`) za sve operacije  
✅ **Monitoring u Realnom Vremenu** - SSH-bazirana provera servisa i analiza logova  
✅ **Email Alerting** - Postfix + Mailtrap integracija za notifikacije  
✅ **Production-Ready** - Systemd servis, automatski restart, logovanje  

---

## 🏗️ Arhitektura Sistema

### Infrastrukturni Dijagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         Azure Cloud                              │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │  Resource Group: dummy-service-dev-rg                      │ │
│  │  Region: Norway East (swedencentral)                       │ │
│  │                                                             │ │
│  │  ┌──────────────────────┐    ┌──────────────────────────┐ │ │
│  │  │   App VM             │    │   Monitoring VM          │ │ │
│  │  │ ┌──────────────────┐ │    │ ┌──────────────────────┐ │ │ │
│  │  │ │ Dummy Service    │ │    │ │ Monitoring Scripts   │ │ │ │
│  │  │ │ Java 17 + JAR    │◄────┤ │ - check-service.sh   │ │ │ │
│  │  │ │ Systemd Service  │ SSH  │ │ - parse-logs.sh      │ │ │ │
│  │  │ │ Port: 8080       │      │ │ - monitor-resources  │ │ │ │
│  │  │ └──────────────────┘ │    │ └──────────────────────┘ │ │ │
│  │  │                      │    │           │               │ │ │
│  │  │ IP: 10.0.1.4         │    │ IP: 10.0.1.5             │ │ │
│  │  │ Public: 4.219.3.73   │    │ Public: 51.107.219.42    │ │ │
│  │  └──────────────────────┘    └──────────┬───────────────┘ │ │
│  │                                          │                 │ │
│  │                              ┌───────────▼──────────────┐  │ │
│  │                              │   Postfix SMTP Relay    │  │ │
│  │                              │   + SASL Auth           │  │ │
│  │                              └───────────┬─────────────┘  │ │
│  └────────────────────────────────────────┼─────────────────┘ │
└─────────────────────────────────────────┼───────────────────┘
                                          │ SMTP (TLS)
                                          ▼
                        ┌─────────────────────────────┐
                        │   Mailtrap.io               │
                        │   Email Notifications       │
                        │   test@mailtrap.io          │
                        └─────────────────────────────┘
```

### Komponente Arhitekture

#### 1. **Terraform Layer** (`terraform/`)
- **Odgovornost**: Kreiranje i upravljanje Azure resursima
- **Resursi**:
  - Resource Group
  - Virtual Network (VNet) sa subnet-om
  - Network Security Group (NSG) - SSH + Internal Traffic
  - 2× Linux Virtual Machines (Ubuntu 22.04 LTS)
  - 2× Public IP Addresses
  - 2× Network Interfaces

#### 2. **Ansible Layer** (`ansible/`)
- **Odgovornost**: Konfiguracija VM-ova i deployment aplikacije
- **Roles**:
  - **java-app**: Deploy dummy service aplikacije
    - Instalacija Java 17
    - Kreiranje system user/group (`dummyservice`)
    - Deploy JAR fajla
    - Konfiguracija systemd servisa
    - Auto-start i restart politika
  - **monitoring**: Setup monitoring sistema
    - Instalacija Postfix + SASL
    - Konfiguracija SMTP relay (Mailtrap)
    - Deploy monitoring skripti
    - Setup cron jobs za automatsko izvršavanje

#### 3. **Application Layer** (`app/`)
- **Dummy Service Java Aplikacija**
  - CLI batch processing aplikacija
  - Multi-threaded agent processing
  - Thread pool executor sa 500 agenata
  - Strukturisano logovanje (INFO/WARN/ERROR)
  - JVM parametri: `-Xmx512m -Xms256m`

#### 4. **Monitoring Layer** (`monitoring/`)
- **check-service.sh**: SSH provera systemd servisa (svakih 5 min)
- **parse-logs.sh**: Analiza journalctl logova preko SSH (svakih 10 min)
- **monitor-resources.sh**: CPU/RAM/Disk monitoring (svakih 15 min)
- **Email alerting**: Postfix → Mailtrap SMTP relay

#### 5. **Orchestration Layer** (`automatic_deploy.sh`)
- Centralizovana skripta za upravljanje kompletnim lifecycle-om
- Integracija Terraform + Ansible + Monitoring
- Interaktivna pomoć i validacija preduslov

---

## ⚙️ Preduslov

Pre pokretanja deployment-a, potrebno je instalirati sledeće alate:

### 1. **Azure CLI**
```bash
# Instalacija
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Login
az login

# Provera
az account show
```

### 2. **Terraform**
```bash
# Instalacija (Linux)
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# Provera
terraform version
```

### 3. **Ansible**
```bash
# Instalacija
sudo apt update
sudo apt install ansible -y

# Provera
ansible --version
```

### 4. **SSH Keys**
```bash
# Generisanje SSH ključa (ako ne postoji)
ssh-keygen -t rsa -b 4096 -C "your_email@example.com" -f ~/.ssh/id_rsa -N ""
```

### 5. **Git**
```bash
# Instalacija
sudo apt install git -y

# Kloniranje repozitorijuma
git clone https://github.com/RAF-shell-programiranje/projekat-2-FilipCobeljic78-24si.git
cd projekat-2-FilipCobeljic78-24si
```

---

## 🚀 Brzo Pokretanje

### Kompletan Deployment (Od Nule do Produkcije)

```bash
# 1. Navigacija u direktorijum projekta
cd projekat-2-FilipCobeljic78-24si

# 2. Učiniti skriptu izvršnom (prvi put)
chmod +x automatic_deploy.sh

# 3. Izvršiti kompletan deployment
./automatic_deploy.sh full-deploy
```

**Ova jedna komanda će:**
1. ✅ Kreirati Azure infrastrukturu (Terraform)
2. ✅ Deploy-ovati Java aplikaciju (Ansible)
3. ✅ Postaviti monitoring sistem (Ansible + SSH)
4. ✅ Konfigurisati email alerting (Postfix + Mailtrap)

**Vreme izvršavanja:** ~5-7 minuta

---

## 🛠️ Glavna Skripta - automatic_deploy.sh

### Pregled Komandi

| Komanda | Opis | Trajanje |
|---------|------|----------|
| `provision` | Kreira Azure infrastrukturu sa Terraform | ~2-3 min |
| `deploy` | Deploy-uje aplikaciju sa Ansible | ~2-3 min |
| `monitor` | Postavlja monitoring sistem | ~1-2 min |
| `check-status` | Prikazuje status aplikacije | ~5 sec |
| `full-deploy` | Izvršava provision → deploy → monitor | ~5-7 min |
| `teardown` | Briše sve resurse sa Azure-a | ~2-3 min |
| `help` | Prikazuje pomoć i dokumentaciju | instant |

### Detaljno Uputstvo po Komandama

#### 1️⃣ **PROVISION** - Kreiranje Infrastrukture

```bash
./automatic_deploy.sh provision
```

**Šta radi:**
- Inicijalizuje Terraform (`.terraform/` direktorijum)
- Validira konfiguraciju
- Prikazuje plan promena (12 resursa)
- Kreira Azure resurse:
  - Resource Group: `dummy-service-dev-rg`
  - VNet + Subnet (10.0.0.0/16)
  - NSG (SSH + internal traffic)
  - 2× VMs (Standard_D2s_v3, 2 vCPU, 8GB RAM)
  - 2× Public IPs
- Generiše Ansible inventory (`ansible/inventory.ini`)

**Output:**
```
[SUCCESS] Terraform provision završen!
[INFO] App VM IP: 4.219.3.73
[INFO] Monitoring VM IP: 51.107.219.42
[SUCCESS] Ansible inventory kreiran
```

**Provera:**
```bash
# Azure Portal
az group show -n dummy-service-dev-rg

# Terraform stanje
cd terraform && terraform show

# Ansible inventory
cat ansible/inventory.ini
```

---

#### 2️⃣ **DEPLOY** - Deployment Aplikacije

```bash
./automatic_deploy.sh deploy
```

**Šta radi:**
- Proverava konekciju sa VM-ovima (Ansible ping)
- Instalira Java 17 (OpenJDK)
- Kreira system korisnika `dummyservice:dummyservice`
- Kopira JAR fajl (`app/dummy-service.jar` → `/opt/dummy-service/`)
- Kreira systemd servis `/etc/systemd/system/dummy-service.service`
- Aktivira i pokreće servis
- Konfiguruje auto-restart politiku

**Ansible Tasks:**
```yaml
- Update apt cache
- Install Java 17
- Create system user/group
- Deploy JAR file
- Configure systemd service
- Enable and start service
- Verify deployment
```

**Output:**
```
PLAY RECAP *********************************************************
dummy-service-dev-app-vm   : ok=24   changed=10   unreachable=0    failed=0

[SUCCESS] Aplikacija uspešno deploy-ovana!
```

**Provera:**
```bash
# SSH na App VM
ssh azureuser@4.219.3.73

# Status servisa
sudo systemctl status dummy-service

# Logovi
sudo journalctl -u dummy-service -f
tail -f /var/log/dummy-service/application.log
```

---

#### 3️⃣ **MONITOR** - Postavljanje Monitoring Sistema

```bash
./automatic_deploy.sh monitor
```

**Šta radi:**

**Faza 1: SSH Key Setup**
- Generiše passwordless SSH ključ na monitoring-vm (`id_rsa_monitoring`)
- Dodaje public key u `authorized_keys` na app-vm
- Kopira ključ u `/root/.ssh/` (monitoring skripte se izvršavaju kao root)

**Faza 2: Ansible Deployment**
- Instalira Postfix + mailutils + libsasl2-modules
- Konfigurише SMTP relay (sandbox.smtp.mailtrap.io:2525)
- Postavlja SASL autentifikaciju
- Deploy-uje monitoring skripte:
  - `/usr/local/bin/monitoring/check-service.sh`
  - `/usr/local/bin/monitoring/parse-logs.sh`
  - `/usr/local/bin/monitoring/monitor-resources.sh`
- Kreira `/etc/monitoring.conf` sa parametrima
- Postavlja cron jobs (*/5, */10, */15 minuta)
- Šalje test email

**Output:**
```
[SUCCESS] SSH ključevi postavljeni!
PLAY RECAP *********************************************************
dummy-service-dev-monitoring-vm : ok=20   changed=13   failed=0

[SUCCESS] Monitoring sistem uspešno postavljen!
```

**Provera:**
```bash
# SSH na Monitoring VM
ssh azureuser@51.107.219.42

# Cron jobs
sudo crontab -l

# Test SSH komunikacije
sudo -i
ssh -i ~/.ssh/id_rsa_monitoring azureuser@10.0.1.4 "sudo systemctl is-active dummy-service"

# Postfix status
sudo systemctl status postfix

# Mailtrap inbox
https://mailtrap.io/inboxes
```

---

#### 4️⃣ **CHECK-STATUS** - Provera Statusa

```bash
./automatic_deploy.sh check-status
```

**Šta radi:**
- SSH na App VM
- Izvršava `systemctl status dummy-service`
- Prikazuje poslednjih 20 linija journalctl logova

**Output:**
```
[INFO] === STATUS DUMMY SERVICE ===
● dummy-service.service - Dummy Service
   Active: active (running) since Tue 2026-01-06 14:28:03 UTC
   Main PID: 6082 (java)
   Memory: 66.7M
   CPU: 2.789s

[INFO] === NEDAVNI LOGOVI ===
Jan 06 14:28:03 dummy-service-dev-app-vm systemd[1]: Started Dummy Service
```

---

#### 5️⃣ **FULL-DEPLOY** - Kompletan Deployment

```bash
./automatic_deploy.sh full-deploy
```

**Redosled izvršavanja:**
1. `provision` - Kreiranje infrastrukture
2. **Čekanje 60s** - VM-ovi spremni za SSH
3. `deploy` - Deployment aplikacije
4. `monitor` - Setup monitoring sistema

**Idealno za:**
- ✅ Prvi deployment od nule
- ✅ Testing kompletne automatizacije
- ✅ CI/CD pipeline integracija
- ✅ Reprodukcija produkcijskog okruženja

---

#### 6️⃣ **TEARDOWN** - Brisanje Resursa

```bash
./automatic_deploy.sh teardown
```

**Šta radi:**
- Traži potvrdu korisnika (`yes/no`)
- Izvršava `terraform destroy`
- Briše sve Azure resurse (12 resursa)
- Čisti Ansible inventory fajl

**⚠️ UPOZORENJE:** Ova akcija je **IREVERZIBILNA**!

**Output:**
```
[WARNING] Da li ste sigurni? (yes/no)
yes

Destroy complete! Resources: 12 destroyed.
[SUCCESS] Svi resursi obrisani!
```

---

#### 7️⃣ **HELP** - Pomoć

```bash
./automatic_deploy.sh help
# ili
./automatic_deploy.sh
# ili
./automatic_deploy.sh --help
```

Prikazuje detaljnu dokumentaciju sa primerima upotrebe.

---

## 🔧 Komponente Sistema

### 1. Terraform Konfiguracija (`terraform/`)

#### Fajlovi:
- `main.tf` - Glavna konfiguracija resursa
- `variables.tf` - Input varijable
- `outputs.tf` - Output vrednosti (IP adrese, SSH komande)
- `terraform.tfvars` - Override varijabli

#### Ključni Resursi:

```hcl
# Resource Group
resource "azurerm_resource_group" "main" {
  name     = "dummy-service-dev-rg"
  location = "norwayeast"  # swedencentral region
}

# Virtual Machines
resource "azurerm_linux_virtual_machine" "app_vm" {
  size = "Standard_D2s_v3"  # 2 vCPU, 8GB RAM
  # Ubuntu 22.04 LTS
  # Java 17, systemd service
}

resource "azurerm_linux_virtual_machine" "monitoring_vm" {
  size = "Standard_D2s_v3"
  # Monitoring scripts, Postfix, cron
}
```

#### Terraform Outputs:

```bash
# Prikazivanje outputa
cd terraform
terraform output

# JSON format
terraform output -json
```

### 2. Ansible Playbooks (`ansible/`)

#### Struktura:

```
ansible/
├── ansible.cfg              # Ansible konfiguracija
├── inventory.ini            # Generisan od Terraform
├── deploy-app.yml           # Playbook za app deployment
├── setup-monitoring.yml     # Playbook za monitoring
├── group_vars/
│   └── all.yml             # Globalne varijable
└── roles/
    ├── java-app/           # Role za Java aplikaciju
    │   ├── defaults/
    │   ├── tasks/
    │   ├── handlers/
    │   └── templates/
    │       └── dummy-service.service.j2
    └── monitoring/         # Role za monitoring
        ├── defaults/
        ├── tasks/
        ├── handlers/
        └── templates/
            ├── check-service.sh.j2
            ├── parse-logs.sh.j2
            ├── monitor-resources.sh.j2
            └── monitoring.conf.j2
```

#### Ključne Varijable (`group_vars/all.yml`):

```yaml
# Java konfiguracija
java_version: "17"
java_opts: "-Xmx512m -Xms256m"

# SMTP konfiguracija
smtp_server: "sandbox.smtp.mailtrap.io"
smtp_port: "2525"
smtp_username: "6eb856c27440cc"
smtp_password: "bc5711d699f015"

# Monitoring
dummy_service_name: "dummy-service"
monitoring_email: "test@mailtrap.io"
```

### 3. Systemd Service (`dummy-service.service`)

```ini
[Unit]
Description=Dummy Service - Simple Java Application for Logging
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=dummyservice
Group=dummyservice
WorkingDirectory=/opt/dummy-service

ExecStart=/usr/bin/java -Xmx512m -Xms256m -jar /opt/dummy-service/dummy-service.jar

StandardOutput=append:/var/log/dummy-service/application.log
StandardError=append:/var/log/dummy-service/application.log

Restart=on-failure
RestartSec=10
StartLimitInterval=200
StartLimitBurst=5

[Install]
WantedBy=multi-user.target
```

**Karakteristike:**
- ✅ Auto-restart na failure
- ✅ Logovanje u `/var/log/dummy-service/application.log`
- ✅ Non-root korisnik (`dummyservice`)
- ✅ JVM memory limits (512MB max heap)

---

## 📊 Monitoring i Alerting

### Monitoring Skripte

#### 1. **check-service.sh** (Svakih 5 minuta)

**Funkcionalnost:**
- SSH na app-vm
- Proverava `systemctl is-active dummy-service`
- Ako je DOWN: šalje email alert

**Email Alert:**
```
Subject: [ALERT] Dummy Service is DOWN!
Body:
Service dummy-service is DOWN on app-vm (10.0.1.4)!

Timestamp: 2026-01-06 14:30:00
Status: inactive

Please investigate immediately.
```

#### 2. **parse-logs.sh** (Svakih 10 minuta)

**Funkcionalnost:**
- SSH na app-vm
- Izvlači poslednje logove sa `journalctl -u dummy-service`
- Analizira broj INFO/WARN/ERROR poruka
- Izvlači nedavne ERROR poruke
- Šalje summary email

**Email Summary:**
```
Subject: [LOG ANALYSIS] Dummy Service Logs
Body:
Log Analysis for dummy-service (last 100 lines):

Statistics:
  INFO messages: 89
  WARN messages: 8
  ERROR messages: 3

Recent ERRORs:
  - [14:25:03] Connection timeout to database
  - [14:26:11] Failed to process agent #42
  - [14:27:45] Out of memory in thread pool
```

#### 3. **monitor-resources.sh** (Svakih 15 minuta)

**Funkcionalnost:**
- Lokalna provera na monitoring-vm
- CPU usage (threshold: 80%)
- Memory usage (threshold: 85%)
- Disk usage (threshold: 90%)
- Šalje alert ako je pređen threshold

**Email Alert:**
```
Subject: [WARNING] High Resource Usage on monitoring-vm
Body:
Resource usage exceeded thresholds:

CPU: 85.3% (threshold: 80%)
Memory: 78.2% (threshold: 85%)
Disk: 65.1% (threshold: 90%)

Timestamp: 2026-01-06 14:45:00
```

### Cron Konfiguracija

```bash
# SSH na monitoring-vm i provera cron jobs
ssh azureuser@51.107.219.42
sudo crontab -l

# Output:
*/5  * * * * /usr/local/bin/monitoring/check-service.sh
*/10 * * * * /usr/local/bin/monitoring/parse-logs.sh
*/15 * * * * /usr/local/bin/monitoring/monitor-resources.sh
```

### Mailtrap Email Inbox

**Pristup:**
1. Login na https://mailtrap.io
2. Inbox: **"My Inbox"** ili custom inbox
3. Email adresa: `test@mailtrap.io`

**Filtriranje:**
- `[ALERT]` - Kritični problemi (service DOWN)
- `[WARNING]` - Upozorenja (resources)
- `[LOG ANALYSIS]` - Redovni izveštaji

---

## 🐛 Troubleshooting

### Problem 1: Terraform Provision Fails

**Simptomi:**
```
Error: creating Linux Virtual Machine: compute.VirtualMachinesClient#CreateOrUpdate
```

**Rešenje:**
```bash
# 1. Provera Azure login
az account show

# 2. Ponovno logovanje
az logout
az login

# 3. Provera quota
az vm list-usage --location swedencentral -o table

# 4. Clean Terraform state
cd terraform
rm -rf .terraform* terraform.tfstate*
terraform init
```

---

### Problem 2: Ansible Deployment Fails - apt lock

**Simptomi:**
```
E: Could not get lock /var/lib/dpkg/lock-frontend
```

**Razlog:** Cloud-init još uvek radi u pozadini

**Rešenje:**
```bash
# Sačekaj 60-120 sekundi, pa ponovo:
./automatic_deploy.sh deploy

# Ili SSH na VM i proveri cloud-init status
ssh azureuser@<APP_VM_IP>
cloud-init status
```

---

### Problem 3: Service ne startuje (JVM greška)

**Simptomi:**
```
Invalid maximum heap size: -Xmx512m -Xms256m
Error: Could not create the Java Virtual Machine
```

**Razlog:** Systemd ne može parsirati Environment sa 2 opcije

**Rešenje:** (Već popravljeno u kodu)
```bash
# Umesto:
Environment="JAVA_OPTS=-Xmx512m -Xms256m"
ExecStart=/usr/bin/java ${JAVA_OPTS} -jar ...

# Koristi:
ExecStart=/usr/bin/java -Xmx512m -Xms256m -jar ...
```

---

### Problem 4: Monitoring ne šalje email-ove

**Dijagnostika:**
```bash
# 1. SSH na monitoring-vm
ssh azureuser@51.107.219.42

# 2. Provera Postfix statusa
sudo systemctl status postfix

# 3. Provera mail logova
sudo tail -f /var/log/mail.log

# 4. Test slanje email-a
echo "Test body" | mail -s "Test Subject" test@mailtrap.io

# 5. Provera cron izvršavanja
sudo grep CRON /var/log/syslog | tail -20
```

**Česta rešenja:**
```bash
# Restart Postfix
sudo systemctl restart postfix

# Provera SASL autentifikacije
sudo cat /etc/postfix/sasl_passwd
sudo postmap /etc/postfix/sasl_passwd

# Test SSH komunikacije monitoring → app
sudo ssh -i /root/.ssh/id_rsa_monitoring azureuser@10.0.1.4 "sudo systemctl status dummy-service"
```

---

### Problem 5: SSH Key Permission Denied

**Simptomi:**
```bash
Permission denied (publickey)
```

**Rešenje:**
```bash
# 1. Provera da li ključ postoji
ls -la ~/.ssh/id_rsa

# 2. Provera permissions
chmod 600 ~/.ssh/id_rsa
chmod 644 ~/.ssh/id_rsa.pub

# 3. Dodavanje ključa u ssh-agent
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_rsa

# 4. Test konekcije
ssh -v azureuser@<VM_IP>
```

---

## 📚 Dodatne Informacije

### Konfiguracija i Customization

#### Promena Azure Regiona

```bash
# Edituj terraform/terraform.tfvars
vim terraform/terraform.tfvars

# Izmeni:
location = "swedencentral"  # Promeni u željeni region

# Lista dostupnih regiona:
az account list-locations -o table
```

#### Promena VM Size-a

```bash
# Edituj terraform/terraform.tfvars
vim terraform/terraform.tfvars

# Izmeni:
vm_size = "Standard_D2s_v3"  # Promeni u željeni size

# Lista dostupnih VM sizes:
az vm list-sizes --location swedencentral -o table
```

#### Promena Monitoring Frekvencije

```bash
# Edituj ansible/roles/monitoring/defaults/main.yml
vim ansible/roles/monitoring/defaults/main.yml

# Izmeni cron_schedule varijable
# Trenutno: */5, */10, */15 (minuti)
# Možeš promeniti na:
# - */1 (svaki minut - za testing)
# - 0 */1 * * * (svakih sat vremena)
# - 0 0 * * * (jednom dnevno)
```

#### Promena Email Destinacije

```bash
# Edituj ansible/roles/monitoring/defaults/main.yml
monitoring_email: "your-email@example.com"

# Za produkciju, zameni Mailtrap sa pravim SMTP serverom
smtp_server: "smtp.gmail.com"
smtp_port: "587"
smtp_username: "your-email@gmail.com"
smtp_password: "your-app-password"
```

### Dummy Service Aplikacija

#### Pokretanje Lokalno (Za Testiranje)

```bash
# Navigacija u app direktorijum
cd app

# Pokretanje sa default parametrima
java -jar dummy-service.jar

# Pokretanje sa custom parametrima
java -jar dummy-service.jar /tmp/custom.log 100

# Parametri:
#   - Argument 1: Lokacija log fajla (default: logs/app.log)
#   - Argument 2: Broj agenata (default: 500)
```

#### Log Format

```
2026-01-06 14:28:15.123 [pool-2-thread-42] INFO  agents.AgentRunnable - 8.35 + 38.56 = 46.91
2026-01-06 14:28:15.456 [pool-2-thread-89] WARN  agents.AgentRunnable - Division by zero avoided
2026-01-06 14:28:15.789 [main] ERROR main.Main - Failed to initialize agent pool
```

### Network Security

#### NSG Rules (Network Security Group)

```hcl
# SSH Access (Port 22)
source: 0.0.0.0/0 (Internet)
destination: App VM + Monitoring VM
priority: 1001

# Monitoring Traffic (Port 9090)
source: 10.0.0.0/16 (VNet internal)
destination: App VM
priority: 1003

# VNet Internal Traffic
source: VirtualNetwork
destination: VirtualNetwork
priority: 1004
```

**Security Best Practices:**
- ✅ SSH samo preko public key (password disabled)
- ✅ Internal monitoring traffic preko private IPs
- ✅ Systemd service radi kao non-root user
- ✅ Firewall rules ograničeni na minimum

### Backup i Disaster Recovery

#### Backup Terraform State

```bash
# Lokalni backup
cp terraform/terraform.tfstate terraform/terraform.tfstate.backup-$(date +%Y%m%d)

# Azure Blob Storage backend (preporučeno za produkciju)
# Dodaj u terraform/main.tf:
terraform {
  backend "azurerm" {
    resource_group_name  = "terraform-state-rg"
    storage_account_name = "tfstate"
    container_name       = "tfstate"
    key                  = "dummy-service.tfstate"
  }
}
```

#### Recreate iz Backup-a

```bash
# 1. Restore terraform state
cp terraform/terraform.tfstate.backup-20260106 terraform/terraform.tfstate

# 2. Terraform refresh
cd terraform
terraform refresh

# 3. Re-deploy aplikaciju
cd ..
./automatic_deploy.sh deploy
```

### Cost Optimization

#### Azure Costs (Estimate za 1 mesec)

| Resurs | Quantity | Est. Cost/Month |
|--------|----------|-----------------|
| VM Standard_D2s_v3 | 2× | $140.16 |
| Public IP (Static) | 2× | $7.30 |
| Managed Disk (30GB SSD) | 2× | $4.80 |
| VNet + NSG | 1× | $0.00 (free tier) |
| **UKUPNO** | | **~$152.26/month** |

**⚠️ VAŽNO:** Koristite `teardown` kada ne testirate da izbegnete nepotrebne troškove!

```bash
# Brisanje resursa kada završite
./automatic_deploy.sh teardown
```

### CI/CD Integration

#### GitHub Actions Primer

```yaml
# .github/workflows/deploy.yml
name: Deploy to Azure

on:
  push:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v1
      
      - name: Setup Ansible
        run: |
          sudo apt update
          sudo apt install ansible -y
      
      - name: Deploy
        run: ./automatic_deploy.sh full-deploy
```

### Logs i Debugging

#### Lokacije Važnih Logova

```bash
# App VM
/var/log/dummy-service/application.log  # Aplikacioni log
journalctl -u dummy-service              # Systemd log

# Monitoring VM
/var/log/mail.log                        # Postfix SMTP log
/var/log/syslog                          # Cron execution log
/var/log/auth.log                        # SSH authentication log
```

#### Live Log Monitoring

```bash
# App VM - Aplikacioni logovi
ssh azureuser@4.219.3.73
tail -f /var/log/dummy-service/application.log

# App VM - Systemd logovi
sudo journalctl -u dummy-service -f

# Monitoring VM - Email sending
ssh azureuser@51.107.219.42
sudo tail -f /var/log/mail.log
```

### FAQ

**Q: Koliko dugo traje full deployment?**  
A: ~5-7 minuta od nule do potpuno funkcionalnog sistema.

**Q: Mogu li koristiti postojeći Resource Group?**  
A: Da, edituj `terraform/terraform.tfvars` i postavi `resource_group_name`.

**Q: Kako da promenim broj agenata u Java aplikaciji?**  
A: Trenutno je hardcoded na 500. Moraš recompile-ovati JAR sa novim parametrom.

**Q: Da li monitoring radi ako je service DOWN?**  
A: Da! `check-service.sh` će detektovati DOWN status i poslati email alert.

**Q: Mogu li deployovati na AWS ili GCP umesto Azure?**  
A: Ne direktno - Terraform konfiguracija je specifična za Azure provider. Potrebna je adaptacija.

**Q: Šta se dešava ako Mailtrap rate limit pređem?**  
A: Email-ovi će biti odbijeni. Preporučujem smanjenje cron frekvencije (trenutno */5, */10, */15 min je ok).

---

## 📞 Kontakt i Podrška

**Student:** Filip Cobeljic  
**Email:** fcobeljic5724rn@raf.rs  
**GitHub:** [@FilipCobeljic78-24si](https://github.com/FilipCobeljic78-24si)

**Repozitorijum:** [projekat-2-FilipCobeljic78-24si](https://github.com/RAF-shell-programiranje/projekat-2-FilipCobeljic78-24si)

---

## 📄 Licenca

Ovaj projekat je razvijen za potrebe kursa **Shell Programiranje** na Računarskom fakultetu.

---

## 🎓 Zaključak

Ovo rešenje demonstrira:
- ✅ **Infrastructure as Code** best practices sa Terraform
- ✅ **Configuration Management** sa Ansible
- ✅ **Production-ready deployment** sa systemd servisi
- ✅ **Monitoring i alerting** sa email notifikacijama
- ✅ **Automation** sa jednom centralnom skriptom
- ✅ **Cloud-native arhitektura** na Azure platformi

**Sve komponente su testirane i potpuno funkcionalne!** 🚀
