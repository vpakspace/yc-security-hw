terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
    # Только для time_sleep — паузы после назначения ролей (iam.tf).
    time = {
      source = "hashicorp/time"
    }
  }
  required_version = "~>1.12.0"
}

provider "yandex" {
  # Аутентификация ключом сервисного аккаунта `terraform` (роль editor в folder).
  # Ключ лежит вне репозитория — в $HOME, в git он не попадает.
  service_account_key_file = file(var.sa_key_file)
  cloud_id                 = var.cloud_id
  folder_id                = var.folder_id
  zone                     = var.zone
}
