output "bucket_name" {
  description = "Имя бакета"
  value       = yandex_storage_bucket.this.bucket
}

output "picture_key" {
  description = "Имя объекта в бакете"
  value       = yandex_storage_object.picture.key
}

output "picture_url" {
  description = "Прямой адрес объекта (после шифрования анонимно не читается)"
  value       = "https://${yandex_storage_bucket.this.bucket_domain_name}/${yandex_storage_object.picture.key}"
}

output "kms_key_id" {
  description = "ID симметричного ключа KMS"
  value       = yandex_kms_symmetric_key.bucket.id
}
