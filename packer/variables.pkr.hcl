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
  description = "[PLATFORM] Netzwerk-Namen für die Build-VM (von Platform-Admin konfiguriert). Der OpenStack-Packer-Builder akzeptiert Namen ODER UUIDs in diesem Feld — wir bevorzugen Namen, weil sie cloud-übergreifend stabiler sind. @openstack:network:name:list"
  default     = ["NAT"]
}

variable "security_groups" {
  type        = list(string)
  description = "[PLATFORM] Security-Group-Namen für die Build-VM (von Platform-Admin konfiguriert). Wie ``networks`` akzeptiert das Packer-Builder-Feld Namen oder UUIDs. @openstack:security_group:name:list"
  default     = ["default"]
}
