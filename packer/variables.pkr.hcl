########################################
# Frontend-Variablen (User)
########################################

variable "cloud" {
  type        = string
  description = "Name der Cloud aus clouds.yaml"
  default     = "openstack"
}

variable "app_name" {
  type        = string
  description = "Logischer Name der Applikation / des Images"
  default     = "online-ide"
}

variable "app_version" {
  type        = string
  description = "Version/Tag des Images"
  default     = "v1"
}

variable "provision_script" {
  type        = string
  description = "Shell-Script für Provisioning"
  default     = "scripts/provision.sh"
}

########################################
# Backend-/Umgebungsvariablen 
########################################

variable "source_image_name" {
  type        = string
  description = "Base-Image Name in OpenStack"
  default     = "Ubuntu 22.04"
}

variable "flavor" {
  type        = string
  description = "Flavor der Build-VM"
  default     = "gp1.small"
}

variable "networks" {
  type        = list(string)
  description = "Netzwerke der Build-VM"
  default     = ["4971e080-966d-485e-a161-3e2b7fefad53"]
}

variable "security_groups" {
  type        = list(string)
  description = "Security Groups für die Build-VM"
  default     = ["simple-webserver-sg-81ec1652"]
}

variable "ssh_username" {
  type        = string
  description = "SSH-User im Base-Image"
  default     = "ubuntu"
}

variable "ssh_timeout" {
  type        = string
  description = "SSH Timeout (erhöht für code-server Installation)"
  default     = "20m"
}

variable "use_blockstorage_volume" {
  type        = bool
  description = "Cinder-Volume verwenden (false = ephemeral storage, empfohlen um hängende Volumes zu vermeiden)"
  default     = false
}

variable "volume_size" {
  type        = number
  description = "Größe des Build-Volumes in GB"
  default     = 10
}

variable "use_floating_ip" {
  type        = bool
  description = "Floating IP für Build-VM verwenden (sollte false sein)"
  default     = false
}

variable "floating_ip_pool" {
  type        = string
  default     = "DHBW"
  description = "External network for floating IP"
}
