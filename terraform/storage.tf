###--- бакет Object Storage ---###
# Конфигурация из предыдущего ДЗ; добавлен только блок server_side_encryption_configuration.
resource "yandex_storage_bucket" "this" {
  bucket = var.bucket_name

  # Флаги публичного доступа оставлены как были: на объектах видно, что меняет именно шифрование —
  # анонимное чтение разрешено в обоих случаях.
  anonymous_access_flags {
    read = true
    list = false
  }

  # Шифрование по умолчанию: каждый новый объект шифруется ключом KMS перед записью на диск.
  # Объекты, загруженные раньше, остаются как были — их нужно записать заново.
  dynamic "server_side_encryption_configuration" {
    for_each = var.encryption_enabled ? [yandex_kms_symmetric_key.bucket.id] : []

    content {
      rule {
        apply_server_side_encryption_by_default {
          kms_master_key_id = server_side_encryption_configuration.value
          sse_algorithm     = "aws:kms"
        }
      }
    }
  }

  # При destroy удалить вместе с содержимым: иначе непустой бакет не удалится.
  force_destroy = true
}

###--- картинка ---###
# Объекты в бакет пишутся через S3 API, поэтому здесь нужен статический ключ storage-sa.
# Параметров шифрования у объекта нет намеренно: их задаёт настройка бакета.
resource "yandex_storage_object" "picture" {
  bucket       = yandex_storage_bucket.this.bucket
  key          = var.picture_key
  source       = "${path.module}/${var.picture_file}"
  content_type = "image/png"
  # Без source_hash провайдер сравнивает только путь к файлу: правка картинки не попала бы в бакет.
  source_hash = filemd5("${path.module}/${var.picture_file}")

  access_key = yandex_iam_service_account_static_access_key.storage.access_key
  secret_key = yandex_iam_service_account_static_access_key.storage.secret_key

  depends_on = [time_sleep.wait_for_iam]
}
