#!/usr/bin/env bash
# Проверка шифрования объекта: настройка бакета, метаданные объекта, анонимный и авторизованный доступ.
# Ничего не меняет. Нужны: yc (с настроенным профилем), curl, terraform (для чтения outputs).
#
# Использование: scripts/check.sh [бакет] [ключ_объекта]
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
BUCKET=${1:-$(terraform -chdir="$ROOT/terraform" output -raw bucket_name)}
KEY=${2:-picture.png}
SOURCE="$ROOT/terraform/files/$KEY"
URL="https://$BUCKET.storage.yandexcloud.net/$KEY"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "== 1. Настройки бакета $BUCKET (yc storage bucket get --full)"
yc storage bucket get --name "$BUCKET" --full |
  sed -n -E '/^(anonymous_access_flags|encryption):/,/^[a-z_]+:/p' |
  grep -v -E '^(default_storage_class|versioning|acl|created_at|website_settings|resource_id):' || true

echo
echo "== 2. Метаданные объекта $KEY (head-object)"
yc storage s3api head-object --bucket "$BUCKET" --key "$KEY" --format yaml | grep -v '^request_id:'

echo
echo "== 3. Анонимный запрос: curl $URL"
code=$(curl -sS -m 30 -o "$TMP/anon" -w '%{http_code}' "$URL")
echo "HTTP $code, получено $(stat -c %s "$TMP/anon") байт"
if [[ $code != 200 ]]; then
  cat "$TMP/anon"
  echo
fi

echo
echo "== 4. Авторизованное скачивание (yc storage s3api get-object) и сравнение с исходным файлом"
yc storage s3api get-object --bucket "$BUCKET" --key "$KEY" "$TMP/auth" >/dev/null
printf 'исходный файл : %s\n' "$(sha256sum <"$SOURCE" | cut -d' ' -f1)"
printf 'из бакета     : %s\n' "$(sha256sum <"$TMP/auth" | cut -d' ' -f1)"
if cmp -s "$SOURCE" "$TMP/auth"; then
  echo "содержимое совпадает"
else
  echo "СОДЕРЖИМОЕ ОТЛИЧАЕТСЯ"
  exit 1
fi
