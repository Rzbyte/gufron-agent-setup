#!/usr/bin/env bash
# Pemasang otomatis untuk setup "Gufron agent — 1 wallet".
# Pakai:  bash <(curl -fsSL https://raw.githubusercontent.com/Rzbyte/gufron-agent-setup/main/install.sh)
# Atau:   ./install.sh            (dari dalam repo)
# Non-interaktif: set DEEPSEEK_API_KEY, TELEGRAM_BOT_TOKEN, TELEGRAM_ALLOWED_USERS,
#                 TELEGRAM_HOME_CHANNEL di environment sebelum menjalankan.
set -euo pipefail

REPO_URL="https://github.com/Rzbyte/gufron-agent-setup.git"
SRC="${GUFRON_SRC:-$HOME/gufron-setup}"
SKIP_WALLET="${SKIP_WALLET:-0}"
DRY_RUN="${DRY_RUN:-0}"

say()  { printf '\n\033[1m== %s\033[0m\n' "$*"; }
warn() { printf '\033[33m   %s\033[0m\n' "$*"; }
die()  { printf '\033[31m   gagal: %s\033[0m\n' "$*" >&2; exit 1; }

# ---------- 0. cek lingkungan ----------
say "Cek lingkungan"
[ "$(id -u)" -ne 0 ] && warn "jalan sebagai user biasa — bagus" || warn "jalan sebagai root, semua file akan ada di /root"
command -v git  >/dev/null || die "git belum ada (apt install git / yum install git)"
command -v curl >/dev/null || die "curl belum ada (apt install curl)"
echo "   home: $HOME"

# ---------- 1. Hermes ----------
say "1/6 Hermes Agent"
if [ "$DRY_RUN" = "1" ]; then
  echo "   (dry-run) lewati install Hermes"
elif command -v hermes >/dev/null 2>&1; then
  echo "   sudah terpasang: $(hermes --version 2>/dev/null | head -1)"
else
  echo "   mengunduh installer resmi..."
  bash <(curl -fsSL https://hermes-agent.nousresearch.com/install.sh) --non-interactive
  export PATH="$HOME/.local/bin:$PATH"
  command -v hermes >/dev/null || die "installer selesai tapi 'hermes' belum ada di PATH (buka shell baru lalu jalankan ulang script ini)"
fi

# ---------- 2. repo ----------
say "2/6 Ambil setup"
if [ -f "$(dirname "$0")/config/config.yaml" ] && [ -d "$(dirname "$0")/skills" ]; then
  SRC="$(cd "$(dirname "$0")" && pwd)"
  echo "   pakai folder ini: $SRC"
elif [ -d "$SRC/.git" ]; then
  git -C "$SRC" pull --ff-only -q && echo "   diperbarui: $SRC"
else
  git clone --depth 1 "$REPO_URL" "$SRC"
  echo "   di-clone ke: $SRC"
fi

# ---------- 3. config + persona + skill ----------
say "3/6 Pasang config, persona, skill wallet"
mkdir -p "$HOME/.hermes" "$HOME/.agents/skills"
stamp="$(date +%Y%m%d-%H%M%S)"
for pair in "config/config.yaml:$HOME/.hermes/config.yaml" "SOUL.md:$HOME/.hermes/SOUL.md"; do
  s="${pair%%:*}"; d="${pair#*:}"
  if [ -f "$d" ] && ! cmp -s "$SRC/$s" "$d"; then
    cp -p "$d" "$d.bak-$stamp"; warn "yang lama disimpan: $d.bak-$stamp"
  fi
  cp "$SRC/$s" "$d"; echo "   $d"
done
rm -rf "$HOME/.agents/skills/binance-agentic-wallet"
cp -r "$SRC/skills/binance-agentic-wallet" "$HOME/.agents/skills/"
echo "   $HOME/.agents/skills/binance-agentic-wallet"

# ---------- 4. env ----------
say "4/6 Isi key"
ENV_FILE="$HOME/.hermes/.env"
if [ ! -f "$ENV_FILE" ]; then
  cp "$SRC/.env.example" "$ENV_FILE"; chmod 600 "$ENV_FILE"
fi
ask_fill() {  # $1=KEY $2=label
  local key="$1" label="$2" cur val
  cur="$(grep -m1 "^${key}=" "$ENV_FILE" 2>/dev/null | cut -d= -f2- || true)"
  if [ -n "${!key:-}" ]; then
    val="${!key}"
  elif [ -n "$cur" ]; then
    echo "   $key sudah terisi"; return 0
  elif [ -t 0 ]; then
    printf '   %s (%s): ' "$key" "$label"; read -r val
  else
    warn "$key kosong dan sesi non-interaktif — isi manual di $ENV_FILE"; return 0
  fi
  [ -z "$val" ] && { warn "$key dilewati"; return 0; }
  if grep -q "^${key}=" "$ENV_FILE"; then
    python3 - "$ENV_FILE" "$key" "$val" <<'PY'
import sys
p,k,v=sys.argv[1],sys.argv[2],sys.argv[3]
lines=[(f"{k}={v}\n" if l.startswith(k+"=") else l) for l in open(p)]
open(p,"w").writelines(lines)
PY
  else
    printf '%s=%s\n' "$key" "$val" >> "$ENV_FILE"
  fi
  echo "   $key disimpan"
}
ask_fill DEEPSEEK_API_KEY      "API key model"
ask_fill TELEGRAM_BOT_TOKEN    "token bot dari BotFather"
ask_fill TELEGRAM_ALLOWED_USERS "user id Telegram lu"
ask_fill TELEGRAM_HOME_CHANNEL "chat id tujuan bot"

# ---------- 5. wallet CLI ----------
say "5/6 CLI wallet (baw)"
if [ "$SKIP_WALLET" = "1" ]; then
  warn "dilewati (SKIP_WALLET=1)"
elif command -v baw >/dev/null 2>&1; then
  echo "   sudah ada: $(baw --version 2>/dev/null | head -1)"
elif command -v npm >/dev/null 2>&1; then
  npm install -g @binance/agentic-wallet >/dev/null 2>&1 && echo "   terpasang: $(baw --version 2>/dev/null | head -1)" \
    || warn "gagal pasang baw, coba manual: npm install -g @binance/agentic-wallet"
else
  warn "npm belum ada — lewati wallet. Install Node dulu kalau mau pakai wallet."
fi

# ---------- 6. gateway ----------
say "6/6 Nyalakan gateway"
if [ "$DRY_RUN" = "1" ]; then
  echo "   (dry-run) lewati gateway install"
else
if hermes gateway status >/dev/null 2>&1; then
  echo "   gateway sudah jalan"
else
  hermes gateway install --if-missing --start-now --start-on-login >/dev/null 2>&1 \
    || hermes gateway install --start-now --start-on-login >/dev/null 2>&1 \
    || warn "gagal pasang service; jalankan manual: hermes gateway run"
  echo "   service dipasang"
fi
fi

say "Selesai"
cat <<EOF
   Langkah berikutnya:
     1. kirim pesan ke bot Telegram lu — kalau dibalas, sudah nyambung
     2. kalau mau pakai wallet:  baw auth signin  →  baw auth verify
     3. cek kapan saja:          hermes doctor

   Config : $HOME/.hermes/config.yaml
   Env    : $ENV_FILE
   Skills : $HOME/.agents/skills/
EOF
