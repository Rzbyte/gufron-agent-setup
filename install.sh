#!/usr/bin/env bash
# Pemasang otomatis setup "Gufron agent — 1 wallet".
# Pakai:  bash <(curl -fsSL https://raw.githubusercontent.com/Rzbyte/gufron-agent-setup/main/install.sh)
# Atau:   ./install.sh
# Non-interaktif: set DEEPSEEK_API_KEY, TELEGRAM_BOT_TOKEN (+ opsional TELEGRAM_ALLOWED_USERS,
#                 TELEGRAM_HOME_CHANNEL) di environment. SKIP_WALLET=1 untuk lewati wallet.
set -euo pipefail

# jangan pernah menyasar instalasi lain: buang override yang diwarisi dari sesi Hermes
unset HERMES_HOME HERMES_PROFILE HERMES_RUN_MODULE HERMES_SESSION_ID 2>/dev/null || true

REPO_URL="https://github.com/Rzbyte/gufron-agent-setup.git"
SRC="${GUFRON_SRC:-$HOME/gufron-setup}"
SKIP_WALLET="${SKIP_WALLET:-0}"
DRY_RUN="${DRY_RUN:-0}"

say()  { printf '\n\033[1m== %s\033[0m\n' "$*"; }
warn() { printf '\033[33m   %s\033[0m\n' "$*"; }
ok()   { printf '\033[32m   %s\033[0m\n' "$*"; }
die()  { printf '\033[31m   gagal: %s\033[0m\n' "$*" >&2; exit 1; }

SUDO=""
if [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
  SUDO="sudo"
fi

apt_install() {  # $@ = paket, diam kalau sukses
  command -v apt-get >/dev/null 2>&1 || return 1
  if [ "$(id -u)" -ne 0 ] && [ -z "$SUDO" ]; then return 1; fi
  $SUDO apt-get update -qq >/dev/null 2>&1 || true
  $SUDO apt-get install -y -qq "$@" >/dev/null 2>&1
}

ensure_node() {
  if command -v npm >/dev/null 2>&1; then
    ok "node $(node -v 2>/dev/null), npm $(npm -v 2>/dev/null) — sudah ada"; return 0
  fi
  local n
  n="$(ls -d "$HOME"/.hermes/tools/node-*/bin 2>/dev/null | head -1 || true)"
  if [ -n "$n" ] && [ -x "$n/npm" ]; then
    export PATH="$n:$PATH"; ok "pakai node bawaan Hermes: $n"; return 0
  fi
  if apt_install nodejs npm && command -v npm >/dev/null 2>&1; then
    ok "node $(node -v), npm $(npm -v) (apt)"; return 0
  fi
  local arch ver url dir
  case "$(uname -m)" in
    x86_64) arch=x64 ;;
    aarch64|arm64) arch=arm64 ;;
    *) warn "arsitektur $(uname -m) belum didukung otomatis"; return 1 ;;
  esac
  ver="v22.14.0"; dir="$HOME/.local/node"
  url="https://nodejs.org/dist/$ver/node-$ver-linux-$arch.tar.xz"
  printf '   unduh Node %s (%s)...\n' "$ver" "$arch"
  mkdir -p "$dir"
  curl -fsSL "$url" | tar -xJ --strip-components=1 -C "$dir" || { warn "gagal unduh Node"; return 1; }
  export PATH="$dir/bin:$PATH"
  grep -q '.local/node/bin' "$HOME/.profile" 2>/dev/null \
    || printf '\nexport PATH="$HOME/.local/node/bin:$PATH"\n' >> "$HOME/.profile"
  ok "node $("$dir"/bin/node -v) (unduhan resmi)"
}

# ---------- 1/7 kebutuhan dasar ----------
say "1/7 Kebutuhan dasar (git, curl, tar, node, npm)"
if [ "$(id -u)" -eq 0 ]; then
  warn "jalan sebagai root — semua file akan ada di /root"
else
  ok "jalan sebagai user biasa: $HOME"
fi

missing=""
for c in git curl tar xz; do
  command -v "$c" >/dev/null 2>&1 || missing="$missing $c"
done
if [ -n "$missing" ]; then
  pkgs="$(printf '%s' "$missing" | sed 's/ xz/ xz-utils/')"
  printf '   kurang:%s → memasang\n' "$missing"
  apt_install $pkgs || warn "apt gagal; kalau langkah berikutnya error, pasang manual:$missing"
fi
command -v git  >/dev/null || die "git tidak tersedia"
command -v curl >/dev/null || die "curl tidak tersedia"

if [ "$DRY_RUN" = "1" ]; then
  echo "   (dry-run) lewati node/npm"
else
  ensure_node || warn "node/npm belum siap — bagian wallet nanti dilewati"
fi

# ---------- 2/7 Hermes ----------
say "2/7 Hermes Agent"
if [ "$DRY_RUN" = "1" ]; then
  echo "   (dry-run) lewati install Hermes"
elif command -v hermes >/dev/null 2>&1; then
  ok "sudah terpasang: $(hermes --version 2>/dev/null | head -1)"
else
  echo "   unduh installer resmi..."
  _inst="$(mktemp)"
  curl -fsSL https://hermes-agent.nousresearch.com/install.sh -o "$_inst"
  # hanya stage yang tidak butuh input; "setup" dan "gateway" dilewati supaya tidak ada prompt login
  for _st in prerequisites repository venv python-deps config products complete; do
    printf '   stage: %s\n' "$_st"
    bash "$_inst" --stage "$_st" --non-interactive >/dev/null || die "stage $_st gagal"
  done
  rm -f "$_inst"
  export PATH="$HOME/.local/bin:$PATH"
  command -v hermes >/dev/null || die "'hermes' belum ada di PATH — buka shell baru lalu jalankan ulang script ini"
  ok "terpasang: $(hermes --version 2>/dev/null | head -1)"
fi

# ---------- 3/7 repo ----------
say "3/7 Ambil setup"
if [ -f "$(dirname "$0")/config/config.yaml" ] && [ -d "$(dirname "$0")/skills" ]; then
  SRC="$(cd "$(dirname "$0")" && pwd)"
  ok "pakai folder ini: $SRC"
elif [ -d "$SRC/.git" ]; then
  git -C "$SRC" pull --ff-only -q && ok "diperbarui: $SRC"
else
  git clone --depth 1 "$REPO_URL" "$SRC" >/dev/null
  ok "di-clone ke: $SRC"
fi

# ---------- 4/7 config + persona + skill ----------
say "4/7 Pasang config, persona, skill wallet"
mkdir -p "$HOME/.hermes" "$HOME/.agents/skills"
stamp="$(date +%Y%m%d-%H%M%S)"
for pair in "config/config.yaml:$HOME/.hermes/config.yaml" "SOUL.md:$HOME/.hermes/SOUL.md"; do
  s="${pair%%:*}"; d="${pair#*:}"
  if [ -f "$d" ] && ! cmp -s "$SRC/$s" "$d"; then
    cp -p "$d" "$d.bak-$stamp"; warn "yang lama disimpan: $d.bak-$stamp"
  fi
  cp "$SRC/$s" "$d"; ok "$d"
done
rm -rf "$HOME/.agents/skills/binance-agentic-wallet"
cp -r "$SRC/skills/binance-agentic-wallet" "$HOME/.agents/skills/"
ok "$HOME/.agents/skills/binance-agentic-wallet"

# ---------- 5/7 key ----------
say "5/7 Isi key"
ENV_FILE="$HOME/.hermes/.env"
[ -f "$ENV_FILE" ] || { cp "$SRC/.env.example" "$ENV_FILE"; chmod 600 "$ENV_FILE"; }

set_kv() {
  local key="$1" val="$2"
  if grep -q "^${key}=" "$ENV_FILE"; then
    python3 - "$ENV_FILE" "$key" "$val" <<'PY'
import sys
p, k, v = sys.argv[1], sys.argv[2], sys.argv[3]
lines = [(f"{k}={v}\n" if l.startswith(k + "=") else l) for l in open(p)]
open(p, "w").writelines(lines)
PY
  else
    printf '%s=%s\n' "$key" "$val" >> "$ENV_FILE"
  fi
}
get_kv() { grep -m1 "^$1=" "$ENV_FILE" 2>/dev/null | cut -d= -f2- || true; }

# --- API key model
if [ -n "${DEEPSEEK_API_KEY:-}" ]; then
  set_kv DEEPSEEK_API_KEY "$DEEPSEEK_API_KEY"; ok "API key model: dari environment"
elif [ -n "$(get_kv DEEPSEEK_API_KEY)" ]; then
  ok "API key model: sudah ada"
elif [ -t 0 ]; then
  cat <<'TXT'

   ── API key model (wajib) ───────────────────────────────────────
   1. buka   https://platform.deepseek.com/api_keys
   2. klik "Create new API key"  (bentuknya sk-xxxxx)
   3. copy, tempel di bawah
   Pakai provider lain? tekan ENTER saja, nanti ganti di config.yaml.
TXT
  printf '   API key: '; read -r v
  if [ -n "$v" ]; then set_kv DEEPSEEK_API_KEY "$v"; ok "tersimpan"; else warn "kosong — isi nanti di $ENV_FILE"; fi
else
  warn "DEEPSEEK_API_KEY kosong (sesi non-interaktif)"
fi

# --- token bot
BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-$(get_kv TELEGRAM_BOT_TOKEN)}"
if [ -z "$BOT_TOKEN" ] && [ -t 0 ]; then
  cat <<'TXT'

   ── Bot Telegram ────────────────────────────────────────────────
   1. buka Telegram, chat  @BotFather
   2. kirim  /newbot  → kasih nama → dapat token  (123456:ABC-DEF...)
   3. copy token, tempel di bawah
   Nggak mau pakai Telegram? tekan ENTER saja.
TXT
  printf '   Token bot: '; read -r BOT_TOKEN
fi
if [ -n "$BOT_TOKEN" ]; then
  case "$BOT_TOKEN" in
    [0-9]*:[A-Za-z0-9_-]*) ok "token bot tersimpan" ;;
    *) warn "format token tidak seperti biasanya (123456:ABC...) — disimpan apa adanya" ;;
  esac
  set_kv TELEGRAM_BOT_TOKEN "$BOT_TOKEN"
fi

# --- chat id otomatis
CHAT_ID="$(get_kv TELEGRAM_ALLOWED_USERS)"
if [ -z "$CHAT_ID" ] && [ -n "${BOT_TOKEN:-}" ] && [ -t 0 ]; then
  cat <<'TXT'

   ── Chat id (biar bot cuma nurut ke lu) ─────────────────────────
   Buka Telegram sekarang, kirim  /start  ke bot lu.
   Gua tungguin 2 menit — nggak perlu ketik apa pun.
TXT
  for i in $(seq 1 60); do
    resp="$(curl -fsS --max-time 10 "https://api.telegram.org/bot${BOT_TOKEN}/getUpdates?limit=10" 2>/dev/null || true)"
    CHAT_ID="$(printf '%s' "$resp" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
for u in reversed(d.get("result", [])):
    m = u.get("message") or u.get("edited_message") or {}
    c = (m.get("chat") or {}).get("id")
    if c:
        print(c); break
' 2>/dev/null)"
    [ -n "$CHAT_ID" ] && break
    printf '\r   menunggu /start... %ss' "$((i*2))"; sleep 2
  done
  echo
  if [ -n "$CHAT_ID" ]; then
    set_kv TELEGRAM_ALLOWED_USERS "$CHAT_ID"
    set_kv TELEGRAM_HOME_CHANNEL "$CHAT_ID"
    ok "chat id terdeteksi otomatis: $CHAT_ID"
  else
    warn "belum ada pesan masuk — isi chat id manual nanti"
  fi
fi
if [ -z "$(get_kv TELEGRAM_ALLOWED_USERS)" ] && [ -t 0 ]; then
  printf '   chat id manual (angka dari @userinfobot, ENTER untuk lewati): '; read -r CHAT_ID
  if [ -n "$CHAT_ID" ]; then
    set_kv TELEGRAM_ALLOWED_USERS "$CHAT_ID"; set_kv TELEGRAM_HOME_CHANNEL "$CHAT_ID"
  fi
fi

# ---------- 6/7 wallet CLI ----------
say "6/7 CLI wallet (baw)"
if [ "$SKIP_WALLET" = "1" ]; then
  warn "dilewati (SKIP_WALLET=1)"
elif command -v baw >/dev/null 2>&1; then
  ok "sudah ada: $(baw --version 2>/dev/null | head -1)"
elif ensure_node; then
  printf '   npm install -g @binance/agentic-wallet...\n'
  if npm install -g @binance/agentic-wallet >/dev/null 2>&1; then
    hash -r
    if command -v baw >/dev/null 2>&1; then
      ok "baw terpasang: $(baw --version 2>/dev/null | head -1)"
    else
      warn "baw terpasang tapi belum di PATH — cari di $(npm prefix -g)/bin"
    fi
  else
    warn "gagal pasang baw (manual: npm install -g @binance/agentic-wallet)"
  fi
else
  warn "node tidak tersedia — wallet dilewati"
fi

# ---------- 7/7 gateway ----------
say "7/7 Nyalakan gateway"
if [ "$DRY_RUN" = "1" ]; then
  echo "   (dry-run) lewati gateway"
elif [ -z "$(get_kv TELEGRAM_BOT_TOKEN)" ]; then
  warn "token bot belum ada — gateway dilewati (isi .env lalu jalankan: hermes gateway install --start-now)"
else
  if hermes gateway status >/dev/null 2>&1; then
    ok "gateway sudah jalan"
  else
    hermes gateway install --if-missing --start-now --start-on-login >/dev/null 2>&1 \
      || hermes gateway install --start-now --start-on-login >/dev/null 2>&1 \
      || warn "gagal pasang service; manual: hermes gateway run"
    ok "service gateway dipasang"
  fi
fi

say "Selesai"
cat <<EOF
   Langkah berikutnya:
     1. kirim pesan ke bot Telegram lu — kalau dibalas, sudah nyambung
     2. wallet:  baw auth signin  →  baw auth verify
     3. cek kapan saja:  hermes doctor

   Config : $HOME/.hermes/config.yaml
   Env    : $ENV_FILE
   Skills : $HOME/.agents/skills/
EOF
