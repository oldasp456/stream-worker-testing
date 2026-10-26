#!/usr/bin/env bash
set -e

echo "=========================================================="
echo "           Cloud Stream Service - Worker 24/7             "
echo "=========================================================="

echo "[Daemon] Configuring permissions..."
mkdir -p /var/lib/tor /var/log/tor
chown -R debian-tor:debian-tor /var/lib/tor /var/log/tor 2>/dev/null || true
chmod 700 /var/lib/tor 2>/dev/null || true

echo "[Daemon] Starting background proxy..."
tor -f /etc/tor/torrc --User debian-tor --RunAsDaemon 1

echo "[Daemon] Waiting for Tor SOCKS to bootstrap (real fetch through 9050)..."
ready=0
deadline=$((SECONDS + 120))
while [ "$SECONDS" -lt "$deadline" ]; do
  if curl -s --max-time 10 --socks5-hostname 127.0.0.1:9050 https://check.torproject.org/api/ip | grep -q '"IsTor":true'; then
    ready=1
    break
  fi
  sleep 1
done
if [ "$ready" -ne 1 ]; then
  echo "[Daemon] Timed out waiting for a bootstrapped Tor circuit."
  exit 1
fi
echo "[Daemon] Tor SOCKS proxy is bootstrapped and reachable."

echo "[System] Starting supervisor server..."
exec node server.mjs
