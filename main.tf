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
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "google" {
  project = "fresh-circle-431620-r4"
  region  = "europe-west2"
}

##################################################
# 0) Generate random string to avoid name conflicts
##################################################
# We'll append a short random ID to the network name
# so repeated ephemeral runs won't 409 conflict.
resource "random_id" "rand" {
  byte_length = 2
}

##################################################
# 1) Create a brand new service account
##################################################
resource "google_service_account" "ephemeral_sa" {
  account_id   = "ephemeral-${random_id.rand.dec}"
  display_name = "Ephemeral Demo SA"
}

##################################################
# 2) Assign roles to that new SA
##################################################
# This ensures the new SA can:
# - Be attached to instances (serviceAccountUser)
# - Possibly manage OS Login roles if needed, etc.
# For OS Login as an admin, you might do roles/compute.osAdminLogin
# For basic usage, roles/iam.serviceAccountUser is enough to attach it.
resource "google_project_iam_member" "sa_user_role" {
  project = "fresh-circle-431620-r4"
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.ephemeral_sa.email}"
}

# (Optional) If you want the SA to have OS-level admin login:
resource "google_project_iam_member" "sa_osadmin_role" {
  project = "fresh-circle-431620-r4"
  role    = "roles/compute.osAdminLogin"
  member  = "serviceAccount:${google_service_account.ephemeral_sa.email}"
}

# (Optional) If you want to spin up other compute resources:
# resource "google_project_iam_member" "sa_compute_admin" {
#   project = "fresh-circle-431620-r4"
#   role    = "roles/compute.admin"
#   member  = "serviceAccount:${google_service_account.ephemeral_sa.email}"
# }

##################################################
# 3) VPC & Firewall (All Ports Open for Demo)
##################################################
# Use random_id to avoid name collisions
resource "google_compute_network" "vpc_demo" {
  name                    = "vpc-demo-${random_id.rand.dec}"
  auto_create_subnetworks = true
}

resource "google_compute_firewall" "demo_allow_all" {
  name    = "demo-fw-${random_id.rand.dec}"
  network = google_compute_network.vpc_demo.self_link

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  source_ranges = ["0.0.0.0/0"]
}

##################################################
# 4) Compute Instance (OS Login + ephemeral SA)
##################################################
resource "google_compute_instance" "demo_vm" {
  name         = "demo-vm-${random_id.rand.dec}"
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

  # Attach the ephemeral SA we just created
  service_account {
    email  = google_service_account.ephemeral_sa.email
    scopes = ["cloud-platform"]
  }

  # Ensure instance is created AFTER we've assigned roles
  depends_on = [
    google_project_iam_member.sa_user_role,
    google_project_iam_member.sa_osadmin_role
    # google_project_iam_member.sa_compute_admin (if used)
  ]
}

##################################################
# 5) Output the Public IP
##################################################
output "public_ip" {
  description = "The public IP of the ephemeral VM"
  value       = google_compute_instance.demo_vm.network_interface[0].access_config[0].nat_ip
}
