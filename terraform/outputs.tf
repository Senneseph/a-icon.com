output "droplet_ip" {
  description = "Public IP address of the droplet"
  value       = digitalocean_droplet.a_icon_app.ipv4_address
}

output "droplet_id" {
  description = "ID of the droplet"
  value       = digitalocean_droplet.a_icon_app.id
}

output "domain_records" {
  description = "DNS records created"
  value = {
    root = digitalocean_record.a_icon_root.fqdn
    www  = digitalocean_record.a_icon_www.fqdn
    api  = digitalocean_record.a_icon_api.fqdn
  }
}

