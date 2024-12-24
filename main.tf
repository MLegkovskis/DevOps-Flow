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

###################################
# 1) VPC + Firewall
###################################
resource "google_compute_network" "vpc_demo" {
  name                    = "vpc-demo"
  auto_create_subnetworks = true
}

# DEMO only: opens ALL ports from anywhere
resource "google_compute_firewall" "demo_allow_all" {
  name    = "demo-allow-all"
  network = google_compute_network.vpc_demo.self_link

  allow {
    protocol = "tcp"
    # All TCP ports
    ports = ["0-65535"]
  }

  source_ranges = ["0.0.0.0/0"]
}

###################################
# 2) Compute Instance
###################################
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

  # The startup script references <<TAG_REPLACE>> or var.docker_tag
  metadata_startup_script = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y apt-transport-https ca-certificates curl gnupg
    
    # Add Docker's official GPG key
    curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add -
    echo "deb [arch=amd64] https://download.docker.com/linux/debian buster stable" >> /etc/apt/sources.list

    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io

    # Example with placeholder. Will be replaced by sed or var
    docker pull marilee/devops:<<TAG_REPLACE>>
    docker run -d -p 8080:8080 --name java-app marilee/devops:<<TAG_REPLACE>>
  EOF
}

###################################
# 3) Output the IP
###################################
output "public_ip" {
  description = "The public IP of the ephemeral VM"
  value       = google_compute_instance.demo_vm.network_interface[0].access_config[0].nat_ip
}
