terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.75.0"
  backend "s3" {
    endpoint   = "storage.yandexcloud.net"
    bucket     = "mos-tf"
    region     = "ru-central1"
    key        = "terraform.tfstate"

    skip_region_validation = true
    skip_credentials_validation = true

  }
}

provider "yandex" {
  cloud_id  = "b1g7jn7va51ie1na46qt"
  folder_id = "b1gja3q0vkl04tb3cc71"
  zone      = "ru-central1-b"
}

resource "yandex_vpc_network" "net" {
  folder_id = "b1gja3q0vkl04tb3cc71"
}

resource "yandex_vpc_subnet" "subnet" {
  name           = "Main"
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.net.id
  folder_id      = "b1gja3q0vkl04tb3cc71"
  v4_cidr_blocks = ["10.94.11.0/24"]
}

// Sa account for kube cluster
resource "yandex_iam_service_account" "sa-kube" {
  name        = "sa-kube"
  description = "service account to manage  VMs"
  folder_id   = "b1gja3q0vkl04tb3cc71"
}

// Sa account role
resource "yandex_iam_service_account_iam_binding" "k8s-admin" {
  service_account_id  = "${yandex_iam_service_account.sa-kube.id}"
  role                = "vpc.publicAdmin"
  members             = [
    "serviceAccount:${yandex_iam_service_account.sa-kube.id}",
  ]
}

resource "yandex_iam_service_account_iam_binding" "k8s-clagent" {
  service_account_id  = "${yandex_iam_service_account.sa-kube.id}"
  role                = "k8s.clusters.agent"
  members             = [
    "serviceAccount:${yandex_iam_service_account.sa-kube.id}",
  ]
}

resource "yandex_iam_service_account_iam_binding" "k8s-editor" {
  service_account_id  = "${yandex_iam_service_account.sa-kube.id}"
  role                = "editor"
  members             = [
    "serviceAccount:${yandex_iam_service_account.sa-kube.id}",
  ]
}

resource "yandex_resourcemanager_cloud_iam_binding" "k8s-editor" {
  cloud_id    = "b1g7jn7va51ie1na46qt"
  role        = "editor"
  members     = [
    "serviceAccount:${yandex_iam_service_account.sa-kube.id}",
  ]
}

// Kube cluster
resource "yandex_kubernetes_cluster" "momo-cluster" {
  name        = "momo-cluster"

  network_id  = yandex_vpc_network.net.id
  folder_id   = "b1gja3q0vkl04tb3cc71"
  cluster_ipv4_range = "10.11.0.0/16"
  service_ipv4_range = "10.12.0.0/16"

  master {
    version = "1.21"
    zonal {
      zone      = yandex_vpc_subnet.subnet.zone
      subnet_id = yandex_vpc_subnet.subnet.id
    }

    public_ip = true

    maintenance_policy {
      auto_upgrade = true

      maintenance_window {
        start_time = "06:00"
        duration   = "3h"
      }
    }
  }

  service_account_id      = yandex_iam_service_account.sa-kube.id
  node_service_account_id = yandex_iam_service_account.sa-kube.id

  labels = {
    env       = "testing"
  }

  release_channel = "REGULAR"

  depends_on = [
    yandex_iam_service_account.sa-kube
  ]

}

resource "yandex_kubernetes_node_group" "group" {
  cluster_id  = yandex_kubernetes_cluster.momo-cluster.id
  name        = "momostore"
  version     = "1.21"

  labels = {
    "env" = "testing"
  }

  instance_template {
    platform_id = "standard-v2"

    network_interface {
      nat                = true
      subnet_ids         = [yandex_vpc_subnet.subnet.id]
    }

    resources {
      memory = 4
      cores  = 2
    }

    boot_disk {
      type = "network-hdd"
      size = 64
    }

  }

  scale_policy {
    fixed_scale {
      size = 1
    }
  }

  allocation_policy {
    location {
      zone = "ru-central1-b"
    }
  }

  maintenance_policy {
    auto_upgrade = true
    auto_repair  = true

    maintenance_window {
      day        = "monday"
      start_time = "04:00"
      duration   = "3h"
    }

    maintenance_window {
      day        = "friday"
      start_time = "04:00"
      duration   = "3h"
    }
  }
}
