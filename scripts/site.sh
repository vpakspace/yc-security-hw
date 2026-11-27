#!/usr/bin/env bash
# Статический сайт в Object Storage с HTTPS. По условию задания делается не в Terraform, а через yc CLI.
#
#   scripts/site.sh bucket   — бакет с именем домена, публичное чтение, режим хостинга, страницы
#   scripts/site.sh pages    — заново загрузить страницы из site/
#   scripts/site.sh cert     — запрос сертификата Let's Encrypt и размещение файла HTTP-проверки в бакете
#   scripts/site.sh status   — статус сертификата и проверки домена
#   scripts/site.sh https    — привязать выпущенный сертификат к бакету
#   scripts/site.sh check    — проверить HTTP, HTTPS и сам сертификат
#   scripts/site.sh down     — удалить всё, что создано этим скриптом
#
# Домен 213-180-193-247.sslip.io — это публичный сервис sslip.io: любое такое имя резолвится в IP, записанный
# в нём самом (здесь — адрес website.yandexcloud.net). Свой домен подставляется переменной DOMAIN
# (и тогда нужна DNS-запись CNAME <домен> → <домен>.website.yandexcloud.net).
set -euo pipefail

DOMAIN=${DOMAIN:-vpakspace.213-180-193-247.sslip.io}
CERT_NAME=${CERT_NAME:-netology-site}
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

cert_json() { yc certificate-manager certificate get --name "$CERT_NAME" --full --format json; }

put() { # put <ключ> <файл> <content-type>
  yc storage s3api put-object --bucket "$DOMAIN" --key "$1" --body "$2" --content-type "$3" >/dev/null
  echo "загружен $1"
}

delete_objects() { # delete_objects [префикс] — удалить объекты бакета (без префикса — все)
  yc storage s3api list-objects --bucket "$DOMAIN" --prefix "${1:-}" --format json | jq -r '.contents[]?.key' |
    while read -r key; do
      yc storage s3api delete-object --bucket "$DOMAIN" --key "$key" >/dev/null
      echo "удалён объект $key"
    done
}

# exists <команда get…> — 0: ресурс есть, 1: его нет. Любая другая ошибка (авторизация, сеть) прерывает скрипт,
# иначе down мог бы молча «ничего не найти» при живом стенде.
exists() {
  local err
  if err=$("$@" 2>&1 >/dev/null); then return 0; fi
  if grep -qE 'code = NotFound|certificate with name .* not found' <<<"$err"; then return 1; fi
  echo "$err" >&2
  exit 1
}

upload_pages() {
  put index.html "$ROOT/site/index.html" 'text/html; charset=utf-8'
  put error.html "$ROOT/site/error.html" 'text/html; charset=utf-8'
}

case ${1:-} in
bucket)
  # Бакет сайта — без шифрования KMS: посетители анонимны, а анонимно зашифрованный объект не читается.
  yc storage bucket create --name "$DOMAIN" --public-read >/dev/null
  echo "создан бакет $DOMAIN"
  yc storage bucket update --name "$DOMAIN" \
    --website-settings '{"index":"index.html","error":"error.html"}' >/dev/null
  echo "включён хостинг: index.html, error.html"
  upload_pages
  ;;

pages)
  upload_pages
  ;;

cert)
  yc certificate-manager certificate request --name "$CERT_NAME" --domains "$DOMAIN" --challenge http >/dev/null
  echo "запрошен сертификат $CERT_NAME для $DOMAIN"
  # Параметры проверки появляются не мгновенно.
  for _ in $(seq 1 30); do
    url=$(cert_json | jq -r '.challenges[0].http_challenge.url // empty')
    [[ -n $url ]] && break
    sleep 5
  done
  [[ -n ${url:-} ]] || { echo "Certificate Manager не выдал параметры HTTP-проверки" >&2; exit 1; }
  key=${url#http://"$DOMAIN"/}
  tmp=$(mktemp)
  trap 'rm -f "$tmp"' EXIT
  cert_json | jq -j '.challenges[0].http_challenge.content' >"$tmp"
  put "$key" "$tmp" 'text/plain'
  echo "проверка: GET $url"
  curl -sS -m 30 -o /dev/null -w 'HTTP %{http_code}\n' "$url"
  ;;

status)
  cert_json | jq '{id, name, status, domains, issuer, not_before, not_after,
                   challenges: [.challenges[]? | {domain, type, status, error}]}'
  ;;

https)
  state=$(cert_json | jq -r .status)
  [[ $state == ISSUED ]] || { echo "сертификат ещё не выпущен: статус $state" >&2; exit 1; }
  id=$(cert_json | jq -r .id)
  yc storage bucket set-https --name "$DOMAIN" --certificate-id "$id"
  # Файл проверки прав на домен после выпуска сертификата не нужен.
  delete_objects .well-known/
  ;;

check)
  echo "== DNS"
  getent ahostsv4 "$DOMAIN" | awk 'NR==1{print $1}'
  rc=0
  echo "== http://$DOMAIN/"
  curl -sS -m 30 -o /dev/null -w 'HTTP %{http_code}\n' "http://$DOMAIN/" || rc=1
  echo "== https://$DOMAIN/"
  curl -sS -m 30 -o /dev/null -w 'HTTP %{http_code}, проверка сертификата: %{ssl_verify_result} (0 — без ошибок)\n' \
    "https://$DOMAIN/" || rc=1
  # Сертификат показываем и тогда, когда проверка не прошла: по нему видно, что сервер отдаёт на самом деле.
  echo "== сертификат, который отдаёт сервер"
  openssl s_client -connect "$DOMAIN:443" -servername "$DOMAIN" </dev/null 2>/dev/null |
    openssl x509 -noout -subject -issuer -dates -ext subjectAltName
  exit "$rc"
  ;;

down)
  if exists yc storage bucket get --name "$DOMAIN"; then
    delete_objects
    yc storage bucket delete --name "$DOMAIN"
    echo "удалён бакет $DOMAIN"
  else
    echo "бакета $DOMAIN нет — пропускаю"
  fi
  if exists yc certificate-manager certificate get --name "$CERT_NAME"; then
    yc certificate-manager certificate delete --name "$CERT_NAME" >/dev/null
    echo "удалён сертификат $CERT_NAME"
  else
    echo "сертификата $CERT_NAME нет — пропускаю"
  fi
  ;;

*)
  sed -n '2,14p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit 2
  ;;
esac
