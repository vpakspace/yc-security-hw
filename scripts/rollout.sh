#!/usr/bin/env bash
# Раз в 30 с делает 20 запросов по HTTPS (каждый — новое соединение) и считает, сколько из них прошло, включая
# проверку сертификата. Неуспехом считается любая ошибка запроса.
# Останавливается после трёх раундов 20 из 20 подряд.
D=${DOMAIN:-vpakspace.213-180-193-247.sslip.io}
good=0
while [ $good -lt 3 ]; do
  ok=0
  for _ in $(seq 1 20); do curl -sS -m 20 -o /dev/null "https://$D/" 2>/dev/null && ok=$((ok+1)); done
  echo "$(date -u +%H:%M:%SZ)  HTTPS с проверкой сертификата: $ok из 20"
  if [ $ok -eq 20 ]; then good=$((good+1)); else good=0; fi
  if [ $good -lt 3 ]; then sleep 30; fi
done
