terraform {
  required_version = ">= 1.0"
  
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

provider "digitalocean" {
  token = var.do_token
}

# SSH Key for accessing the droplet
resource "digitalocean_ssh_key" "a_icon_key" {
  name       = "a-icon-deployment-key"
  public_key = var.ssh_public_key
}

# Droplet - $6/month (s-1vcpu-1gb)
resource "digitalocean_droplet" "a_icon_app" {
  image    = "docker-20-04"
  name     = "a-icon-app"
  region   = "nyc3"
  size     = "s-1vcpu-1gb"
  ssh_keys = [digitalocean_ssh_key.a_icon_key.fingerprint]

  user_data = templatefile("${path.module}/cloud-init.yaml", {
    domain = var.domain
  })

  tags = ["a-icon", "production"]
}

# Firewall
resource "digitalocean_firewall" "a_icon_fw" {
  name = "a-icon-firewall"

  droplet_ids = [digitalocean_droplet.a_icon_app.id]

  # SSH
  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # HTTP
  inbound_rule {
    protocol         = "tcp"
    port_range       = "80"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # HTTPS
  inbound_rule {
    protocol         = "tcp"
    port_range       = "443"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # Allow all outbound
  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}

# DNS A record for root domain
resource "digitalocean_record" "a_icon_root" {
  domain = var.domain
  type   = "A"
  name   = "@"
  value  = digitalocean_droplet.a_icon_app.ipv4_address
  ttl    = 300
}

# DNS A record for www subdomain
resource "digitalocean_record" "a_icon_www" {
  domain = var.domain
  type   = "A"
  name   = "www"
  value  = digitalocean_droplet.a_icon_app.ipv4_address
  ttl    = 300
}

# DNS A record for api subdomain (optional)
resource "digitalocean_record" "a_icon_api" {
  domain = var.domain
  type   = "A"
  name   = "api"
  value  = digitalocean_droplet.a_icon_app.ipv4_address
  ttl    = 300
}

