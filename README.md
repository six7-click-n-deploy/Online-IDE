# Online-IDE

Eine OpenStack-basierte Online-IDE-Lösung mit **code-server** (VS Code im Browser) für Lehrveranstaltungen.

## Architektur

```
Professor wählt App im Store
    ↓
Übergibt Teams + User-E-Mails
    ↓
Terraform deployed pro Team eine VM
    ↓
cloud-init erstellt Linux-User
    ↓
Jeder User erhält:
  - Browser-IDE (code-server)
  - Eigenes Login
  - Zugriff auf Team-VM
```

### Kernkonzepte

- **Eine VM pro Team** (nicht pro User!)
- **Linux-Gruppen = Teams**
- **Linux-User = Studenten**
- **code-server** läuft auf Port 8080
- **Passwort-basierter Zugriff** über Browser

---

## Ordnerstruktur

```
Online-IDE/
├── packer/               # Image-Erstellung
│   ├── template.pkr.hcl
│   ├── variables.pkr.hcl
│   └── scripts/
│       └── provision.sh  # code-server Installation
└── terraform/            # VM-Deployment
    ├── main.tf           # Team-VMs + User Management
    ├── variables.tf      # Input-Variablen
    ├── outputs.tf        # User Accounts (Contract)
    ├── user-data.yaml.tpl # cloud-init Template
    └── terraform.tfvars.example
```

---

## Voraussetzungen

### Software

- **Packer** >= 1.9
- **Terraform** >= 1.0
- **OpenStack** Cloud-Zugang
- **clouds.yaml** unter `~/config/clouds.yaml`

### OpenStack Ressourcen

- Netzwerk (internes Netz)
- Floating IP Pool (externes Netz)
- SSH Key Pair
- Ubuntu 22.04 Base Image

---

## Deployment

### 1. Image mit Packer bauen

```bash
cd packer/

# Optional: Variablen anpassen
export PKR_VAR_app_name="online-ide"
export PKR_VAR_app_version="v1"

# Image bauen
packer init .
packer build .

# Resultat: Image "online-ide-v1" in Glance
```

Das Provisioning-Script installiert:
- code-server
- Node.js, npm
- Python 3, pip
- Git, Build-Tools

### 2. VMs mit Terraform deployen

```bash
cd terraform/

# Konfiguration anpassen
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars

# Wichtig: users Variable mit Teams + E-Mails befüllen!
# users = {
#   "team-a" = [
#     { email = "alice.smith@example.com" }
#   ]
# }

# Terraform initialisieren
terraform init

# Plan anzeigen
terraform plan

# Deployen
terraform apply
```

### 3. User-Zugangsdaten abrufen

```bash
# Alle User-Accounts ausgeben
terraform output -json user_accounts | jq

# Beispiel-Output:
# {
#   "team-a-alice-smith": {
#     "type": "password",
#     "ip": "141.72.123.45",
#     "port": 8080,
#     "username": "alice-smith",
#     "auth": "Xy9z!Ab7cD2e"
#   }
# }

# Team-VMs Übersicht
terraform output team_vms
```

---

## User Management Contract

### Input

```hcl
variable "users" {
  type = map(list(object({
    email = string
  })))
}
```

### Verarbeitung (verbindlich!)

```hcl
locals {
  all_users = flatten([
    for team, members in var.users : [
      for member in members : {
        id       = "${team}-${replace(split("@", member.email)[0], ".", "-")}"
        team     = team
        email    = member.email
        username = replace(split("@", member.email)[0], ".", "-")
      }
    ]
  ])
  
  users_map  = { for user in local.all_users : user.id => user }
  teams_list = distinct([for user in local.all_users : user.team])
}
```

### Output (Contract)

```hcl
output "user_accounts" {
  value = {
    "<team>-<username>" = {
      type     = "password"
      ip       = "<floating-ip>"
      port     = 8080
      username = "<username>"
      auth     = "<password>"
    }
  }
}
```

---

## Nutzung

### Als Student

1. Zugangsdaten vom Professor erhalten:
   - IP-Adresse
   - Port (8080)
   - Username
   - Passwort

2. Browser öffnen:
   ```
   http://<IP>:8080
   ```

3. Mit Passwort einloggen

4. VS Code im Browser nutzen!

### Als Professor

Nach dem Deployment:

```bash
# User-Accounts exportieren
terraform output -json user_accounts > user_accounts.json

# An Studenten verteilen (z.B. per CSV)
cat user_accounts.json | jq -r 'to_entries[] | 
  [.key, .value.ip, .value.port, .value.username, .value.auth] | 
  @csv' > users.csv
```

---

## Technische Details

### code-server Konfiguration

Jeder User erhält eine eigene `~/.config/code-server/config.yaml`:

```yaml
bind-addr: 0.0.0.0:8080
auth: password
password: <generiertes-passwort>
cert: false
```

### Security Groups

Pro Team-VM werden folgende Ports geöffnet:
- **22** (SSH) - eingeschränkt auf `ssh_cidr`
- **8080** (code-server) - öffentlich
- **ICMP** (optional)

### cloud-init Prozess

1. Linux-Gruppen erstellen (Team-Namen)
2. Linux-User erstellen (Team-Mitglieder)
3. Passwörter setzen
4. SSH-Passwort-Auth aktivieren
5. code-server pro User konfigurieren
6. systemd user services starten

---

## Troubleshooting

### code-server startet nicht

```bash
# Auf Team-VM einloggen
ssh <username>@<floating-ip>

# Service-Status prüfen
systemctl --user status code-server

# Logs anzeigen
journalctl --user -u code-server -f
```

### Login funktioniert nicht

```bash
# Passwort-Auth prüfen
grep PasswordAuthentication /etc/ssh/sshd_config

# cloud-init Logs
sudo cat /var/log/cloud-init-output.log
```

### Floating IP nicht erreichbar

```bash
# Security Groups prüfen
openstack security group rule list <sg-name>

# Port 8080 muss offen sein
```

---

## clouds.yaml Konfiguration

Die `clouds.yaml` Datei muss unter `~/config/clouds.yaml` liegen:

```yaml
clouds:
  openstack:
    auth:
      auth_url: <AUTH_URL>
      username: "<USERNAME>"
      password: "<PASSWORD>"
      project_name: "<PROJECT_NAME>"
      user_domain_name: "<USER_DOMAIN_NAME>"
    region_name: "<REGION_NAME>"
    interface: "public"
    identity_api_version: 3
```

Terraform ist so konfiguriert, dass es diese Datei automatisch findet:
```hcl
provider "openstack" {
  cloud       = "openstack"
  cloud_yaml  = pathexpand("~/config/clouds.yaml")
}
```

---

## Kosten-Optimierung

### Nach Kurssitzung VMs pausieren

```bash
# VMs stoppen (Daten bleiben erhalten)
openstack server list --name online-ide | grep ACTIVE | awk '{print $2}' | \
  xargs -I {} openstack server stop {}

# Später wieder starten
openstack server list --name online-ide | grep SHUTOFF | awk '{print $2}' | \
  xargs -I {} openstack server start {}
```

### Am Kursende aufräumen

```bash
cd terraform/
terraform destroy
```

---

## Erweiterungen

### Zusätzliche Software installieren

In [packer/scripts/provision.sh](packer/scripts/provision.sh) ergänzen:

```bash
# Docker installieren
sudo apt-get install -y docker.io
sudo usermod -aG docker ubuntu

# Weitere Tools...
```

### Mehr Ports öffnen

In [terraform/main.tf](terraform/main.tf) weitere Security Group Rules hinzufügen:

```hcl
resource "openstack_networking_secgroup_rule_v2" "custom_port" {
  for_each = toset(local.teams_list)
  
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 3000
  port_range_max    = 3000
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.team_sg[each.key].id
}
```

---

## Lizenz

Siehe `LICENSE`
# -> packer.pkrvars.hcl ausfüllen
# -> provision.sh mit eigener App füllen
packer init .
packer build -var-file=packer.pkrvars.hcl .

# 3) Deploy
cd ../terraform
cp terraform.tfvars.example terraform.tfvars
# -> terraform.tfvars ausfüllen (image_name!)
terraform init
terraform apply
```

---

## Best Practices

### Sicherheit
- **Secrets niemals hardcoden**: Nutze Umgebungsvariablen, Vault oder Cloud-Init
- **SSH-Zugriff beschränken**: Setze `ssh_cidr` auf deine spezifische IP statt `0.0.0.0/0`
- **Security Groups minimalistisch**: Nur benötigte Ports öffnen

### Entwicklung
- **Idempotenz**: `provision.sh` muss mehrfach ausführbar sein
- **Versionierung**: Nutze semantische Versionierung für Image-Namen
- **Testing**: Teste Image-Builds in separater Umgebung

### Operations
- **Monitoring**: Implementiere Health-Checks in deiner App
- **Logs**: Nutze structured logging (JSON) für bessere Auswertung
- **Backups**: Plane Backup-Strategien für persistente Daten