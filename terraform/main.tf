terraform {
  required_version = ">= 1.0"

  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.53"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

# OpenStack Provider mit explizitem clouds.yaml Pfad
provider "openstack" {
  cloud = "openstack"
}

############################
# APP-DEFAULTS (vom App-Entwickler vorgegeben)
############################

locals {
  # Diese Werte sind App-spezifisch und werden vom App-Entwickler definiert
  app_name           = "online-ide"
  image_name         = "online-ide-v1"
  flavor             = "gp1.small"
  key_pair           = "" # Leer = nur Passwort-Auth
  enable_floating_ip = true
  allow_icmp         = true
}

# Packer-Image aus Glance laden
data "openstack_images_image_v2" "image" {
  name        = local.image_name
  most_recent = true
}

# External Network für Floating IPs
data "openstack_networking_network_v2" "external" {
  name = var.floating_ip_pool
}

############################
# USER MANAGEMENT (CONTRACT)
############################

# Flatten users from teams - EXAKT wie im Contract vorgegeben
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

# Passwörter für jeden User generieren
resource "random_password" "user_passwords" {
  for_each = local.users_map
  length   = 16
  special  = true
  # Mindestens: 1 Uppercase, 1 Lowercase, 1 Zahl, 1 Sonderzeichen
  min_upper   = 1
  min_lower   = 1
  min_numeric = 1
  min_special = 1
}

############################
# TEAM-BASED VMs
############################

# Pro Team eine VM deployen
resource "openstack_compute_instance_v2" "team_ide" {
  for_each = toset(local.teams_list)

  name        = "${local.app_name}-${each.key}"
  image_id    = data.openstack_images_image_v2.image.id
  flavor_name = local.flavor
  key_pair    = local.key_pair != "" ? local.key_pair : null

  security_groups = [openstack_networking_secgroup_v2.team_sg[each.key].name]

  network {
    uuid = var.network_uuid
  }

  # cloud-init user-data: User und Gruppen für dieses Team
  user_data = templatefile("${path.module}/user-data.yaml.tpl", {
    teams     = [each.key]
    users     = { for uid, u in local.users_map : uid => u if u.team == each.key }
    passwords = { for uid, u in local.users_map : uid => random_password.user_passwords[uid].result if u.team == each.key }
  })

  metadata = merge(
    var.metadata,
    {
      team = each.key
    }
  )
}

# Security Group pro Team
resource "openstack_networking_secgroup_v2" "team_sg" {
  for_each = toset(local.teams_list)

  name        = "${local.app_name}-${each.key}-sg"
  description = "Security group for team ${each.key} IDE"
}

# SSH-Zugriff
resource "openstack_networking_secgroup_rule_v2" "ssh" {
  for_each = toset(local.teams_list)

  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = var.ssh_cidr
  security_group_id = openstack_networking_secgroup_v2.team_sg[each.key].id
}

# code-server Ports 8080-8089 (für bis zu 10 User pro Team)
resource "openstack_networking_secgroup_rule_v2" "code_server" {
  for_each = toset(local.teams_list)

  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 8080
  port_range_max    = 8089
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.team_sg[each.key].id
}

# ICMP (optional)
resource "openstack_networking_secgroup_rule_v2" "icmp" {
  for_each = local.allow_icmp ? toset(local.teams_list) : []

  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.team_sg[each.key].id
}

############################
# FLOATING IPs
############################

# Floating IP pro Team-VM
resource "openstack_networking_floatingip_v2" "team_fip" {
  for_each = local.enable_floating_ip ? toset(local.teams_list) : []

  pool = data.openstack_networking_network_v2.external.name
}

resource "openstack_compute_floatingip_associate_v2" "team_fip_assoc" {
  for_each = local.enable_floating_ip ? toset(local.teams_list) : []

  floating_ip = openstack_networking_floatingip_v2.team_fip[each.key].address
  instance_id = openstack_compute_instance_v2.team_ide[each.key].id

  depends_on = [openstack_compute_instance_v2.team_ide]
}

############################
# OUTPUT CONTRACT
############################

# User Accounts gemäß OUTPUT-CONTRACT
locals {
  # Gruppiere User nach Team und erstelle Index
  users_by_team = {
    for team in local.teams_list : team => [
      for uid, user in local.users_map : uid if user.team == team
    ]
  }

  # Map: user_id -> index innerhalb des Teams (für Port-Berechnung)
  user_indices = merge([
    for team in local.teams_list : {
      for idx, uid in local.users_by_team[team] : uid => idx
    }
  ]...)

  user_accounts = {
    for uid, user in local.users_map : uid => {
      type     = "password"
      ip       = local.enable_floating_ip ? openstack_networking_floatingip_v2.team_fip[user.team].address : openstack_compute_instance_v2.team_ide[user.team].network[0].fixed_ip_v4
      port     = 8080 + local.user_indices[uid]
      username = user.username
      auth     = random_password.user_passwords[uid].result
    }
  }
}
