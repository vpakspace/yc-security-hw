###--- доступ к облаку ---###

variable "cloud_id" {
  type        = string
  description = "ID облака (https://console.yandex.cloud/cloud)"
}

variable "folder_id" {
  type        = string
  description = "ID каталога (folder), в котором создаются все ресурсы"
}

variable "zone" {
  type        = string
  default     = "ru-central1-a"
  description = "Зона доступности по умолчанию для провайдера (KMS и Object Storage к зоне не привязаны)"
}

variable "sa_key_file" {
  type        = string
  default     = "~/.authorized_key.json"
  description = "Путь к авторизованному ключу сервисного аккаунта terraform (вне репозитория)"
}

###--- Object Storage (из ДЗ «Вычислительные мощности. Балансировщики нагрузки») ---###

variable "bucket_name" {
  type        = string
  default     = "vpakspace-20261125"
  description = "Имя бакета из предыдущего ДЗ. Имена бакетов уникальны на весь Yandex Cloud"
}

variable "picture_key" {
  type        = string
  default     = "picture.png"
  description = "Имя объекта (картинки) в бакете"
}

variable "picture_file" {
  type        = string
  default     = "files/picture.png"
  description = "Локальный файл картинки (создаётся scripts/make_picture.py)"
}

###--- шифрование ---###

variable "kms_key_name" {
  type        = string
  default     = "netology-bucket-key"
  description = "Имя симметричного ключа в KMS"
}

variable "encryption_enabled" {
  type        = bool
  default     = true
  description = <<-EOT
    Включено ли в бакете шифрование по умолчанию ключом KMS. Значение false нужно только для того, чтобы сначала
    воспроизвести бакет из предыдущего ДЗ (без шифрования) и сравнить поведение «до» и «после».
  EOT
}
