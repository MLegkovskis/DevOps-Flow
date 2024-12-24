##################################################
# main.tf
##################################################
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

##################################################
# 1) Grant the SA "iam.serviceAccountUser" role
##################################################
# This ensures that the service account can be attached
# to the compute instance by Terraform.
resource "google_project_iam_member" "grant_sa_user_role" {
  project = "fresh-circle-431620-r4"
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:demo-cv@fresh-circle-431620-r4.iam.gserviceaccount.com"
}

##################################################
# 2) VPC & Firewall (All Ports Open for Demo)
##################################################
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

##################################################
# 3) Compute Instance (OS Login + SA attached)
##################################################
resource "google_compute_instance" "demo_vm" {
  name         = "demo-vm"
  machine_type = "e2-micro"
  zone         = "europe-west2-a"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network = google_compute_network.vpc_demo.self_link
    access_config {}
  }

  # Enable OS Login
  metadata = {
    enable-oslogin = "TRUE"
  }

  # Attach the same SA. Must have roles/iam.serviceAccountUser 
  # via google_project_iam_member above
  service_account {
    email  = "demo-cv@fresh-circle-431620-r4.iam.gserviceaccount.com"
    scopes = ["cloud-platform"]
  }

  # Wait for the IAM role to be granted before creation
  depends_on = [
    google_project_iam_member.grant_sa_user_role
  ]
}

##################################################
# 4) Public IP Output
##################################################
output "public_ip" {
  description = "The public IP of the ephemeral VM"
  value       = google_compute_instance.demo_vm.network_interface[0].access_config[0].nat_ip
}
