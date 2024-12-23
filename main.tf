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
  # Use your GCP project ID here
  project = "fresh-circle-431620-r4"
  # Region or zone references for your resources
  region  = "europe-west2"
  # You can also set a default zone if you want
}

########################
# 1) VPC + Firewall
########################

resource "google_compute_network" "vpc_demo" {
  name                    = "vpc-demo"
  auto_create_subnetworks = true
}

resource "google_compute_firewall" "allow_8080" {
  name    = "allow-8080"
  network = google_compute_network.vpc_demo.self_link

  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }

  source_ranges = ["0.0.0.0/0"]
}

########################
# 2) Compute Instance
########################

resource "google_compute_instance" "demo_vm" {
  name         = "demo-vm"
  machine_type = "e2-micro"

  # Boot disk with Debian
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  # Ephemeral external IP
  network_interface {
    network = google_compute_network.vpc_demo.self_link
    access_config {}
  }

  # Simple startup script that:
  # 1) Installs Docker
  # 2) Pulls your Docker image from Docker Hub
  # 3) Runs it on port 8080
  metadata_startup_script = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y apt-transport-https ca-certificates curl gnupg
    
    # Add Docker's official GPG key
    curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add -
    echo "deb [arch=amd64] https://download.docker.com/linux/debian buster stable" >> /etc/apt/sources.list

    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io

    # Pull your ephemeral image from DockerHub
    # Notice we reference your GitHub SHA environment variable. 
    # But since it's at runtime on the VM, let's hard-code the tag if you want
    # or pass the tag via an environment var if you prefer. 
    # Example uses the same tag from your pipeline
    # If you want a static tag, e.g., "latest", modify accordingly.
    docker pull marilee/devops:<<TAG_REPLACE>>
    docker run -d -p 8080:8080 --name java-app marilee/devops:<<TAG_REPLACE>>
  EOF

  # We'll dynamically replace <<TAG_REPLACE>> with your GitHub SHA or "latest" 
  # in a Terraform local or variable. We'll do a sed or local variable approach below.
}

########################
# 3) Output the IP
########################
output "public_ip" {
  description = "The public IP of the ephemeral VM"
  value       = google_compute_instance.demo_vm.network_interface[0].access_config[0].nat_ip
}
