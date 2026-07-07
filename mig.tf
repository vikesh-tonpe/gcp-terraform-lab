/**
 * Copyright 2017 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * limitations under the License.
 */

provider "google" {
  project = var.project
}

provider "google-beta" {
  project = var.project
}

resource "google_sql_database_instance" "instance" {
  project          = var.project
  name             = "cepf-instance"
  region           = var.group1_region
  root_password    = "postgres"
  
  # TODO 2: Specify the database version
  database_version = "POSTGRES_14"
  
  settings {
    tier = "db-custom-8-30720"
    availability_type = "REGIONAL"
    ip_configuration {
      authorized_networks {
          name = "Enable All"
          value = "0.0.0.0/0"
      }
    }
  }

  deletion_protection  = "false"
}

resource "google_sql_database" "database" {
  name     = "cepf-db"
  instance = google_sql_database_instance.instance.name
}

module "mig1_template" {
  source     = "terraform-google-modules/vm/google//modules/instance_template"
  version    = "~> 7.9"
  network    = google_compute_network.default.self_link
  subnetwork = google_compute_subnetwork.group1.self_link
  service_account = {
    email  = ""
    scopes = ["cloud-platform"]
  }
  name_prefix          = "${var.network_prefix}-group1"
  startup_script       = file(format("%s/start-up.sh", path.module))
  source_image_family  = "debian-12"
  source_image_project = "debian-cloud"
  tags = [
    "${var.network_prefix}-group1",
    module.cloud-nat-group1.router_name
  ]
  depends_on = [
    google_sql_database_instance.instance
  ]
}

module "mig1" {
  source            = "terraform-google-modules/vm/google//modules/mig"
  version           = "~> 7.9"
  instance_template = module.mig1_template.self_link
  region            = var.group1_region
  hostname          = "${var.network_prefix}-group1"
  
  # TODO 3: Specify the target size for the managed instance group
  target_size       = var.target_size
  min_replicas=3
  
  autoscaling_enabled = true
  autoscaling_cpu = [{
    target : 0.6
  }]
  max_replicas = 4  
  named_ports = [{
    name = "http",
    port = 80
  }]
  network    = google_compute_network.default.self_link
  subnetwork = google_compute_subnetwork.group1.self_link
  
  # TODO 5: Add min_replicas parameter for GitOps update (Task 3)
}



