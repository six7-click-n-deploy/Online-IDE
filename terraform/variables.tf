############################
# Frontend-Variablen (vom Dozenten im App Store gesetzt)
############################

variable "users" {
  description = "[CONTRACT] Teams mit User-Emails (vom Dozenten übermittelt)"
  type = map(list(object({
    email = string
  })))
  default = {}
}

############################
# Backend-Defaults (von Platform/App-Entwickler vorgegeben)
############################

variable "network_uuid" {
  description = "[BACKEND] UUID des internen Netzwerks (von Platform-Admin konfiguriert)"
  type        = string
  default     = "34a00b87-57ce-42c4-8e1b-9ea8a657ec2e"
}

variable "floating_ip_pool" {
  description = "[BACKEND] Name des External Networks für Floating IPs (von Platform-Admin konfiguriert)"
  type        = string
  default     = "DHBW"
}

variable "ssh_cidr" {
  description = "[BACKEND] CIDR für SSH-Zugriff (von Platform-Admin konfiguriert)"
  type        = string
  default     = "0.0.0.0/0"
}

variable "metadata" {
  description = "[BACKEND] Zusätzliche Metadata (wird vom Backend gesetzt)"
  type        = map(string)
  default     = {}
}
