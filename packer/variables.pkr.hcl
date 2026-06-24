########################################
# User-Variablen (App-Entwickler)
########################################

########################################
# Platform-Contract-Variablen (vom Worker/Platform gesetzt)
########################################

variable "image_name" {
  type        = string
  description = "[PLATFORM] Name des zu erstellenden Images (z.B. online-ide-v1) @openstack:image:name"
  default     = "online-ide-vX"
}

variable "networks" {
  type        = list(string)
  description = "[PLATFORM] Netzwerk-UUIDs für die Build-VM (von Platform-Admin konfiguriert). Der OpenStack-Packer-Builder reicht diese Liste 1:1 an die Nova-API durch, die hier **UUIDs** verlangt — Namen werden mit `Bad networks format: network uuid is not in proper format` abgelehnt. Bitte UUID eintragen. @openstack:network:id:list"
  default     = ["4971e080-966d-485e-a161-3e2b7fefad53"]
}

variable "security_groups" {
  type        = list(string)
  description = "[PLATFORM] Security-Group-Namen für die Build-VM (von Platform-Admin konfiguriert). Im Gegensatz zu `networks` resolved der OpenStack-Packer-Builder dieses Feld selbst — Namen sind hier explizit erlaubt und einfacher zu pflegen. @openstack:security_group:name:list"
  default     = ["default"]
}
