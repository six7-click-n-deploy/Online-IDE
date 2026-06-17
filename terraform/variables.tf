########################################
# CUSTOM-Variablen (Optional)
# Werden vom User gesetzt
########################################

variable "users" {
  description = "[CONTRACT] Teams mit User-Emails (vom Dozenten übermittelt)"
  type = map(list(object({
    email = string
  })))
  default = {}
}

# File-Upload-Beispiel: der Lehrende lädt im Wizard eine Datei
# (z.B. eine PDF-Aufgabenstellung) hoch, die platform-seitig
# base64-encodiert in dieser Variable landet. Das ``user-data.yaml.tpl``
# unten dekodiert sie und legt sie unter ``/opt/material/`` ab.
#
# Der ``@openstack:file:all``-Marker steuert das Wizard-UI:
#   * ``all``  → eine FileDropZone, geteilte Datei für alle VMs
#   * ``team`` → eine FileDropZone pro Team (map(map(object(...))))
#   * ``user`` → eine FileDropZone pro User (Composite-Key Team-User)
#
# Der innere ``map``-Wrapper hält Raum offen für künftiges
# Multi-File-pro-Slot — heute kommt immer genau ein Eintrag mit Key
# ``"uploaded"`` an.
variable "assignment_files" {
  description = "[CONTRACT] Vom Dozenten hochgeladene Begleitmaterialien @openstack:file:all"
  type = map(object({
    name         = string
    content_b64  = string
    size         = number
    content_type = string
  }))
  default = {}
}

########################################
# CONTRACT-Variablen (PFLICHT)
# Werden vom Worker/Platform gesetzt
########################################

variable "image_name" {
  description = "[BACKEND] Name des Packer-Images aus Glance (z.B. online-ide-v1) @openstack:image:name"
  type        = string
  default     = "online-ide-vX"
}

variable "network_uuid" {
  description = "[BACKEND] UUID des internen Netzwerks (von Platform-Admin konfiguriert) @openstack:network:id"
  type        = string
  default     = "34a00b87-57ce-42c4-8e1b-9ea8a657ec2e"
}

variable "floating_ip_pool" {
  description = "[BACKEND] Name des External Networks für Floating IPs (von Platform-Admin konfiguriert) @openstack:floating_ip_pool:name"
  type        = string
  default     = "DHBW"
}

variable "shared_secgroup_id" {
  description = "[BACKEND] ID der gemeinsamen Security Group für alle VMs @openstack:security_group:id"
  type        = string
  default     = "4ffaf007-df66-4250-9118-1bd99378d34a"
}