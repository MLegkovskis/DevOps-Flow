terraform {
  required_version = ">= 1.0.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
}

provider "google" {
  project = "fresh-circle-431620-r4"
  region  = "europe-west2"
}

# VPC + firewall opens all TCP ports for demo
resource "google_compute_network" "vpc_demo" {
  name                    = "vpc-demo"
  auto_create_subnetworks = true
}

resource "google_compute_firewall" "demo_allow_all" {
  name    = "demo-allow-all"
  network = google_compute_network.vpc_demo.self_link

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_instance" "demo_vm" {
  name         = "demo-vm"
  machine_type = "e2-micro"
  zone         = "europe-west2-a"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  # ephemeral external IP
  network_interface {
    network = google_compute_network.vpc_demo.self_link
    access_config {}
  }

  # OS Login enabled - no local metadata SSH keys
  metadata = {
    enable-oslogin = "TRUE"
  }

  # (Optional) attach a service account that has osLogin roles or just your user logs in with your personal account
  service_account {
    email  = var.service_account_email
    scopes = ["cloud-platform"] 
  }
}

output "public_ip" {
  description = "The public IP of the ephemeral VM"
  value       = google_compute_instance.demo_vm.network_interface[0].access_config[0].nat_ip
}
