#!/usr/bin/env bash
# Runs on the VPS. Builds the Astro site in /opt/<domain> and serves dist/ with Caddy.
set -euo pipefail

SITE_DOMAIN="${SITE_DOMAIN:?SITE_DOMAIN required}"
REPO_DIR="${REPO_DIR:-/opt/${SITE_DOMAIN}}"
CADDY_FILE="${CADDY_FILE:-/etc/caddy/Caddyfile}"

echo "==> Site: ${SITE_DOMAIN}"
echo "==> Repo dir: ${REPO_DIR}"
echo "==> Caddyfile: ${CADDY_FILE}"

cd "${REPO_DIR}"

echo "==> Pulling latest"
git fetch origin --prune
git pull --ff-only origin main

echo "==> Installing dependencies"
npm ci

echo "==> Building site"
npm run build

if [ -f "${REPO_DIR}/dist/sitemap-index.xml" ] && [ ! -f "${REPO_DIR}/dist/sitemap.xml" ]; then
  cp "${REPO_DIR}/dist/sitemap-index.xml" "${REPO_DIR}/dist/sitemap.xml"
  echo "==> Copied sitemap-index.xml -> sitemap.xml"
fi

BUILD_DIR="${REPO_DIR}/dist"
if [ ! -d "${BUILD_DIR}" ]; then
  echo "!! Build output ${BUILD_DIR} not found" >&2
  exit 1
fi

MARKER="# casablanca-nettopro-static:${SITE_DOMAIN}"
MARKER_END="# /casablanca-nettopro-static:${SITE_DOMAIN}"
SITE_BLOCK="$(cat <<EOF
${MARKER}
${SITE_DOMAIN} {
	encode zstd gzip

	header {
		-Server
		Strict-Transport-Security "max-age=15552000"
		X-Content-Type-Options "nosniff"
		X-Frame-Options "SAMEORIGIN"
		Referrer-Policy "strict-origin-when-cross-origin"
		Permissions-Policy "camera=(), geolocation=(), microphone=()"
	}

	root * ${BUILD_DIR}
	file_server

	handle_errors {
		rewrite * /404.html
		file_server
	}
}
${MARKER_END}
EOF
)"

TMP_CADDY="$(mktemp)"
sudo cp "${CADDY_FILE}" "${TMP_CADDY}"

SITE_DOMAIN="${SITE_DOMAIN}" MARKER="${MARKER}" MARKER_END="${MARKER_END}" SITE_BLOCK="${SITE_BLOCK}" python3 - "${TMP_CADDY}" <<'PY'
import os
import sys

path = sys.argv[1]
domain = os.environ["SITE_DOMAIN"]
marker = os.environ["MARKER"]
marker_end = os.environ["MARKER_END"]
block = os.environ["SITE_BLOCK"].rstrip() + "\n"

with open(path, "r", encoding="utf-8") as fh:
    lines = fh.readlines()

def remove_marked(src):
    out = []
    skip = False
    for line in src:
        if marker in line:
            skip = True
            continue
        if skip and marker_end in line:
            skip = False
            continue
        if not skip:
            out.append(line)
    return out

def remove_unmarked_domain(src):
    out = []
    i = 0
    while i < len(src):
        if src[i].strip() == f"{domain} {{":
            depth = 0
            while i < len(src):
                depth += src[i].count("{")
                depth -= src[i].count("}")
                i += 1
                if depth <= 0:
                    break
            continue
        out.append(src[i])
        i += 1
    return out

lines = remove_unmarked_domain(remove_marked(lines))
if lines and lines[-1].strip():
    lines.append("\n")
lines.append(block)

with open(path, "w", encoding="utf-8") as fh:
    fh.write("".join(lines))
PY

if ! sudo cmp -s "${TMP_CADDY}" "${CADDY_FILE}"; then
  BACKUP="${CADDY_FILE}.bak.casablanca.$(date +%Y%m%d%H%M%S)"
  echo "==> Installing Caddy record for ${SITE_DOMAIN} (backup: ${BACKUP})"
  sudo cp "${CADDY_FILE}" "${BACKUP}"
  sudo cp "${TMP_CADDY}" "${CADDY_FILE}"
else
  echo "==> Caddy record already current"
fi
rm -f "${TMP_CADDY}"

sudo chown root:caddy "${CADDY_FILE}" 2>/dev/null || sudo chown root:root "${CADDY_FILE}"
sudo chmod 640 "${CADDY_FILE}" 2>/dev/null || true
if command -v restorecon >/dev/null 2>&1; then
  sudo restorecon "${CADDY_FILE}" >/dev/null 2>&1 || true
fi

if ! sudo caddy validate --config "${CADDY_FILE}" >/dev/null 2>&1; then
  echo "!! Caddy config invalid; latest backup is ${BACKUP:-not-created}. Not reloading." >&2
  exit 1
fi

sudo systemctl reload caddy 2>/dev/null || sudo systemctl restart caddy

echo "==> Deploy complete: ${SITE_DOMAIN} live from ${BUILD_DIR}"
