###--- сервисный аккаунт для работы с объектами ---###
# Как в предыдущем ДЗ: объекты кладутся в бакет статическим ключом отдельного аккаунта storage-sa.
# Новое — вторая роль, на ключ KMS: по документации YC для загрузки и скачивания объектов зашифрованного бакета
# кроме прав на бакет нужны права на ключ.
#
# ⚠️ Назначать роли может только аккаунт с правом на изменение привязок. У SA `terraform` роль editor его не включает,
# поэтому владелец облака на время apply и destroy выдаёт ему admin на folder (команды — в README, «Как запустить»).

resource "yandex_iam_service_account" "storage" {
  name        = "storage-sa"
  description = "Загрузка объектов в бакет Object Storage"
}

# Права на бакет и объекты.
resource "yandex_resourcemanager_folder_iam_member" "storage" {
  folder_id = var.folder_id
  role      = "storage.editor"
  member    = "serviceAccount:${yandex_iam_service_account.storage.id}"
}

# Права на конкретный ключ (а не на все ключи каталога): шифровать при записи и расшифровывать при чтении.
resource "yandex_kms_symmetric_key_iam_member" "storage" {
  symmetric_key_id = yandex_kms_symmetric_key.bucket.id
  role             = "kms.keys.encrypterDecrypter"
  member           = "serviceAccount:${yandex_iam_service_account.storage.id}"
}

resource "yandex_iam_service_account_static_access_key" "storage" {
  service_account_id = yandex_iam_service_account.storage.id
  description        = "Статический ключ storage-sa для загрузки объектов в бакет"
}

# Роли в YC раздаются асинхронно: сразу после назначения операции этим аккаунтом падают с AccessDenied.
resource "time_sleep" "wait_for_iam" {
  depends_on = [
    yandex_resourcemanager_folder_iam_member.storage,
    yandex_kms_symmetric_key_iam_member.storage,
  ]
  create_duration = "30s"
}
