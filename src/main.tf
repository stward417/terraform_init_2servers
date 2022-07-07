terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  token     = ""
  cloud_id  = ""
  folder_id = ""
  zone      = "ru-central1-a"
}




resource "yandex_iam_service_account" "admin417-sa" {
  name        = "admin417-sa"
  description = "service account to manage IG"
}

resource "yandex_resourcemanager_folder_iam_binding" "editor" {
  folder_id = ""
  role      = "editor"
  members   = [
    "serviceAccount:${yandex_iam_service_account.admin417-sa.id}",
  ]
  depends_on = [
    yandex_iam_service_account.admin417-sa,
  ]
}




data "yandex_compute_image" "my_image" {
  family = "lemp"
}

resource "yandex_vpc_network" "network-1" {
  name = "network1"
}

resource "yandex_vpc_subnet" "subnet-1" {
  name           = "subnet1"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network-1.id
  v4_cidr_blocks = ["192.168.10.0/24"]
}




resource "yandex_compute_instance_group" "ig-1" {
  name               = "ig-1"
  folder_id          = ""
  service_account_id = "${yandex_iam_service_account.admin417-sa.id}"
  depends_on          = [yandex_resourcemanager_folder_iam_binding.editor]
  instance_template {
    platform_id = "standard-v3"
    resources {
      core_fraction = 20
      memory = 2
      cores  = 2
    }

    boot_disk {
      mode = "READ_WRITE"
      initialize_params {
        image_id = data.yandex_compute_image.my_image.id
      }
    }

    network_interface {
      network_id = "${yandex_vpc_network.network-1.id}"
      subnet_ids = ["${yandex_vpc_subnet.subnet-1.id}"]
    }

    metadata = {
      ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
    }
  }

  scale_policy {
    fixed_scale {
      size = 2
    }
  }

  allocation_policy {
    zones = ["ru-central1-a"]
  }

  deploy_policy {
    max_unavailable = 1
    max_expansion = 0
  }

  load_balancer {
    target_group_name        = "target-group"
    target_group_description = "target_group"
  }
}




resource "yandex_lb_network_load_balancer" "lb-1" {
  name        = "lb-1"
  description = "lb-1"
  region_id   = "ru-central1"
  listener {
    name        = "listener"
    port        = 80
    target_port = 80
    protocol    = "tcp"
    external_address_spec {
      ip_version = "ipv4"
    }
  }
  attached_target_group {
    target_group_id = "${yandex_compute_instance_group.ig-1.load_balancer.0.target_group_id}"
    healthcheck {
      name = "target-group"
      http_options {
        port = 80
        path = "/"
      }
      interval            = 2
      timeout             = 1
      healthy_threshold   = 5
      unhealthy_threshold = 5
    }
  }
}
