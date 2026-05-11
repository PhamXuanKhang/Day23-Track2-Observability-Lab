#!/usr/bin/env bash
## Trigger an alert by killing the app, wait for it to fire, then restore.
## Used in: deck §10 demo, lab Track 02 grading checkpoint.

set -euo pipefail

echo "Step 1: kill app container"
docker stop day23-app >/dev/null

echo "Step 2: wait up to 150s for ServiceDown alert to fire"
fired=0
for i in {1..30}; do
  sleep 5
  prom_alerts=$(curl -fsS http://localhost:9090/api/v1/alerts 2>/dev/null | grep -c '"alertname":"ServiceDown".*"state":"firing"' || true)
  am_alerts=$(curl -fsS http://localhost:9093/api/v2/alerts 2>/dev/null | grep -c '"alertname":"ServiceDown"' || true)
  if [ "$prom_alerts" -gt 0 ] || [ "$am_alerts" -gt 0 ]; then
    echo "  ServiceDown fired (after ${i}*5s)"
    fired=1
    break
  fi
  echo "  no alert yet (${i}*5s)"
done

if [ "$fired" -ne 1 ]; then
  echo "ServiceDown did not fire; restarting app before exit" >&2
  docker start day23-app >/dev/null || true
  exit 1
fi

echo "Step 3: restart app"
docker start day23-app >/dev/null

echo "Step 4: wait 60s for alert to resolve"
for i in {1..12}; do
  sleep 5
  alerts=$(curl -fsS http://localhost:9093/api/v2/alerts 2>/dev/null | grep -c '"state":"active"' || true)
  if [ "$alerts" -eq 0 ]; then
    echo "  alert resolved; waiting 20s for Slack resolved notification"
    sleep 20
    exit 0
  fi
done

echo "alert did not resolve within 60s" >&2
exit 1
