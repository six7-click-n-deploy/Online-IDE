########################################
# User-Variablen (App-Entwickler)
########################################

########################################
# Platform-Contract-Variablen (vom Worker/Platform gesetzt)
########################################

variable "image_name" {
  type        = string
  description = "[PLATFORM] Name des zu erstellenden Images (z.B. online-ide-v1)"
  default     = "online-ide-vX"
}

variable "networks" {
  type        = list(string)
  description = "[PLATFORM] Netzwerk-UUIDs für Build-VM (von Platform-Admin konfiguriert)"
  default     = ["4971e080-966d-485e-a161-3e2b7fefad53"]
}

variable "security_groups" {
  type        = list(string)
  description = "[PLATFORM] Security Groups für Build-VM (von Platform-Admin konfiguriert)"
  default     = ["simple-webserver-sg-81ec1652"]
}
