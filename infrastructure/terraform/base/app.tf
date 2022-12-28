resource "yandex_resourcemanager_cloud" "cloud" {
  organization_id = "b1gja3q0vkl04tb3cc71"
  name            = var.env
}

resource "yandex_resourcemanager_folder" "folder" {
  cloud_id = yandex_resourcemanager_cloud.cloud.id
  name     = var.env
}

resource "yandex_vpc_network" "net" {
  folder_id = yandex_resourcemanager_folder.folder.id
}

resource "yandex_vpc_subnet" "subnet" {
  name           = "Main"
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.net.id
  folder_id      = yandex_resourcemanager_folder.folder.id
  v4_cidr_blocks = var.v4_cidr_blocks
}

# // Create SA
# resource "yandex_iam_service_account" "sa" {
#   folder_id = yandex_resourcemanager_folder..id
#   name      = "storage-editor"
# }

# // Grant permissions
# resource "yandex_resourcemanager_folder_iam_member" "sa-editor" {
#   folder_id = yandex_resourcemanager_folder..id
#   role      = "storage.editor"
#   member    = "serviceAccount:${yandex_iam_service_account.sa.id}"
# }

# // Create Static Access Keys
# resource "yandex_iam_service_account_static_access_key" "sa-static-key" {
#   service_account_id = yandex_iam_service_account.sa.id
#   description        = "static access key for object storage"
# }

# // Use keys to create bucket
# resource "yandex_storage_bucket" "-images-pelmen23" {
#   bucket     = "pelmen-static-bucket"
#   folder_id  = yandex_resourcemanager_folder..id
#   access_key = yandex_iam_service_account_static_access_key.sa-static-key.access_key
#   secret_key = yandex_iam_service_account_static_access_key.sa-static-key.secret_key
#   anonymous_access_flags {
#     read     = true
#     list     = false
#   }
# }

// Sa account for kube cluster
resource "yandex_iam_service_account" "sa-kube" {
  name        = "sa-kube"
  description = "service account to manage  VMs"
  folder_id   = yandex_resourcemanager_folder.folder.id
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
  cloud_id    = yandex_resourcemanager_cloud.cloud.id
  role        = "editor"
  members     = [
    "serviceAccount:${yandex_iam_service_account.sa-kube.id}",
  ]
}

// Kube cluster
resource "yandex_kubernetes_cluster" "zonal_pelmen_cluster" {
  name        = "${var.env}-cluster"

  network_id  = yandex_vpc_network.net.id
  folder_id   = yandex_resourcemanager_folder.folder.id
  cluster_ipv4_range = "10.11.0.0/16"
  service_ipv4_range = "10.12.0.0/16"

  master {
    version = "1.21"
    zonal {
      zone      = yandex_vpc_subnet.subnet.zone
      subnet_id = yandex_vpc_subnet.subnet.id
    }

    public_ip = true

    #security_group_ids = [yandex_vpc_security_group.kube-.id]
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
    env       = "${var.env}"
  }

  release_channel = "REGULAR"

  depends_on = [
    yandex_iam_service_account.sa-kube
  ]

}

resource "yandex_kubernetes_node_group" "group" {
  cluster_id  = yandex_kubernetes_cluster.zonal_pelmen_cluster.id
  name        = "${var.env}-node-group"
  version     = "1.21"

  labels = {
    "env" = "${var.env}"
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
