variable "do_token" {
  description = "DigitalOcean API token"
  type        = string
  sensitive   = true
}

variable "ssh_public_key" {
  description = "SSH public key for accessing the droplet"
  type        = string
}

variable "domain" {
  description = "Domain name for the application"
  type        = string
  default     = "a-icon.com"
}

