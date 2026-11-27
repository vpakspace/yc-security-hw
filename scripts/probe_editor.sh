#!/usr/bin/env bash
# Читает объект бакета IAM-токеном сервисного аккаунта terraform (роль editor на каталоге, ролей на ключе KMS нет)
# и для сравнения — без токена. Ничего не меняет, токен не печатается.
#
# Токен получается по авторизованному ключу самого аккаунта, поэтому он заведомо принадлежит этому аккаунту.
# Нужны python3 с PyJWT и cryptography, curl.
#
# Переменные: SA_KEY_FILE (по умолчанию ~/.authorized_key.json), BUCKET, KEY.
set -euo pipefail

SA_KEY_FILE=${SA_KEY_FILE:-$HOME/.authorized_key.json}
URL="https://${BUCKET:-vpakspace-20261125}.storage.yandexcloud.net/${KEY:-picture.png}"

TOKEN=$(
  python3 - "$SA_KEY_FILE" <<'EOF'
import json, sys, time, urllib.request

import jwt

key = json.load(open(sys.argv[1]))
url = "https://iam.api.cloud.yandex.net/iam/v1/tokens"
pem = key["private_key"]
pem = pem[pem.index("-----BEGIN"):]  # перед PEM в файле ключа YC идёт служебная строка
now = int(time.time())
signed = jwt.encode({"aud": url, "iss": key["service_account_id"], "iat": now, "exp": now + 600},
                    pem, algorithm="PS256", headers={"kid": key["id"]})
request = urllib.request.Request(url, data=json.dumps({"jwt": signed}).encode(),
                                 headers={"Content-Type": "application/json"})
print(json.load(urllib.request.urlopen(request, timeout=30))["iamToken"])
EOF
)

printf 'токен получен по авторизованному ключу аккаунта %s\n' \
  "$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1]))["service_account_id"])' "$SA_KEY_FILE")"

out=$(mktemp)
trap 'rm -f "$out"' EXIT
curl -sS -m 30 -o "$out" -w 'без токена : HTTP %{http_code}, %{size_download} байт\n' "$URL"
# Заголовок передаётся через stdin, чтобы токен не был виден в списке процессов.
printf 'header = "Authorization: Bearer %s"\n' "$TOKEN" |
  curl -sS -m 30 -K - -o "$out" -w 'с токеном  : HTTP %{http_code}, %{size_download} байт\n' "$URL"
printf 'sha256 ответа с токеном: %s\n' "$(sha256sum <"$out" | cut -d' ' -f1)"
