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
  _inst="$(mktemp)"
  curl -fsSL https://hermes-agent.nousresearch.com/install.sh -o "$_inst"
  # jalankan semua stage yang tidak butuh input; tahap "setup"/"gateway" dilewati
  for _st in prerequisites repository venv python-deps config products complete; do
    printf '   stage: %s\n' "$_st"
    bash "$_inst" --stage "$_st" --non-interactive >/dev/null || die "stage $_st gagal"
  done
  rm -f "$_inst"
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
set_kv() {  # $1=KEY $2=value
  local key="$1" val="$2"
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
}
get_kv() { grep -m1 "^$1=" "$ENV_FILE" 2>/dev/null | cut -d= -f2- || true; }

# --- API key model
if [ -n "${DEEPSEEK_API_KEY:-}" ]; then
  set_kv DEEPSEEK_API_KEY "$DEEPSEEK_API_KEY"; echo "   API key model: dari environment"
elif [ -n "$(get_kv DEEPSEEK_API_KEY)" ]; then
  echo "   API key model: sudah ada"
elif [ -t 0 ]; then
  cat <<'TXT'

   ── API key model (wajib) ───────────────────────────────────────
   1. buka  https://platform.deepseek.com/api_keys
   2. klik "Create new API key", copy (mulai dengan sk-)
   3. tempel di bawah
   (pakai provider lain? kosongkan saja, nanti ganti di config.yaml)
TXT
  printf '   API key: '; read -r v
  if [ -n "$v" ]; then set_kv DEEPSEEK_API_KEY "$v"; echo "   tersimpan"; else warn "kosong — agent belum bisa mikir sampai .env diisi"; fi
else
  warn "DEEPSEEK_API_KEY kosong (sesi non-interaktif)"
fi

# --- token bot
BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-$(get_kv TELEGRAM_BOT_TOKEN)}"
if [ -z "$BOT_TOKEN" ] && [ -t 0 ]; then
  cat <<'TXT'

   ── Bot Telegram (wajib kalau mau lewat Telegram) ───────────────
   1. buka Telegram, chat @BotFather
   2. kirim  /newbot  → kasih nama → dapat token (bentuknya 123456:ABC-DEF...)
   3. copy token itu, tempel di bawah
TXT
  printf '   Token bot: '; read -r BOT_TOKEN
fi
if [ -n "$BOT_TOKEN" ]; then
  case "$BOT_TOKEN" in
    [0-9]*:[A-Za-z0-9_-]*) set_kv TELEGRAM_BOT_TOKEN "$BOT_TOKEN"; echo "   token bot tersimpan" ;;
    *) warn "format token aneh (harus 123456:ABC...), disimpan apa adanya" ; set_kv TELEGRAM_BOT_TOKEN "$BOT_TOKEN" ;;
  esac
fi

# --- chat id: dideteksi otomatis dari pesan /start
CHAT_ID="$(get_kv TELEGRAM_ALLOWED_USERS)"
if [ -z "$CHAT_ID" ] && [ -n "${BOT_TOKEN:-}" ] && [ -t 0 ]; then
  cat <<'TXT'

   ── Chat id (biar bot nurut cuma ke lu) ─────────────────────────
   Sekarang buka Telegram, kirim  /start  ke bot lu.
   Gua tungguin sampai 2 menit, nggak perlu ketik apa-apa lagi.
TXT
  for i in $(seq 1 60); do
    resp="$(curl -fsS --max-time 10 "https://api.telegram.org/bot${BOT_TOKEN}/getUpdates?limit=10" 2>/dev/null || true)"
    CHAT_ID="$(printf '%s' "$resp" | python3 -c '
import json,sys
try: d=json.load(sys.stdin)
except Exception: sys.exit(0)
for u in reversed(d.get("result",[])):
    m=u.get("message") or u.get("edited_message") or {}
    c=(m.get("chat") or {}).get("id")
    if c: print(c); break
' 2>/dev/null)"
    [ -n "$CHAT_ID" ] && break
    printf '\r   menunggu pesan /start... %ss' "$((i*2))"; sleep 2
  done
  echo
  if [ -n "$CHAT_ID" ]; then
    set_kv TELEGRAM_ALLOWED_USERS "$CHAT_ID"
    set_kv TELEGRAM_HOME_CHANNEL "$CHAT_ID"
    echo "   chat id terdeteksi otomatis: $CHAT_ID"
  fi
fi
if [ -z "$(get_kv TELEGRAM_ALLOWED_USERS)" ] && [ -t 0 ]; then
  printf '   chat id manual (angka, dari @userinfobot): '; read -r CHAT_ID
  [ -n "$CHAT_ID" ] && set_kv TELEGRAM_ALLOWED_USERS "$CHAT_ID" && set_kv TELEGRAM_HOME_CHANNEL "$CHAT_ID"
fi

# ---------- 5. node + wallet CLI ----------
say "5/6 Node + CLI wallet (baw)"

ensure_node() {
  command -v npm >/dev/null 2>&1 && return 0
  # 1. node bawaan Hermes
  local n
  n="$(ls -d "$HOME"/.hermes/tools/node-*/bin 2>/dev/null | head -1 || true)"
  if [ -n "$n" ] && [ -x "$n/npm" ]; then
    export PATH="$n:$PATH"; echo "   pakai node bawaan Hermes: $n"; return 0
  fi
  # 2. apt (root/debian-ish)
  if command -v apt-get >/dev/null 2>&1 && { [ "$(id -u)" -eq 0 ] || sudo -n true 2>/dev/null; }; then
    local SUDO=""; [ "$(id -u)" -ne 0 ] && SUDO="sudo"
    echo "   pasang nodejs + npm via apt..."
    $SUDO apt-get update -qq >/dev/null 2>&1 || true
    $SUDO apt-get install -y -qq nodejs npm >/dev/null 2>&1 && command -v npm >/dev/null && return 0
    warn "apt gagal, lanjut unduh Node resmi"
  fi
  # 3. tarball resmi
  local arch ver url dir
  case "$(uname -m)" in
    x86_64) arch=x64 ;; aarch64|arm64) arch=arm64 ;; *) warn "arsitektur $(uname -m) belum didukung otomatis"; return 1 ;;
  esac
  ver="v22.14.0"; dir="$HOME/.local/node"
  url="https://nodejs.org/dist/$ver/node-$ver-linux-$arch.tar.xz"
  echo "   unduh Node $ver ($arch)..."
  mkdir -p "$dir"
  curl -fsSL "$url" | tar -xJ --strip-components=1 -C "$dir" || { warn "gagal unduh Node"; return 1; }
  export PATH="$dir/bin:$PATH"
  grep -q 'HOME/.local/node/bin' "$HOME/.profile" 2>/dev/null \
    || printf '\nexport PATH="$HOME/.local/node/bin:$PATH"\n' >> "$HOME/.profile"
  echo "   node: $($dir/bin/node -v)"
}

if [ "$SKIP_WALLET" = "1" ]; then
  warn "wallet dilewati (SKIP_WALLET=1)"
elif command -v baw >/dev/null 2>&1; then
  echo "   baw sudah ada: $(baw --version 2>/dev/null | head -1)"
elif ensure_node; then
  if npm install -g @binance/agentic-wallet >/dev/null 2>&1; then
    hash -r
    if command -v baw >/dev/null 2>&1; then
      echo "   baw terpasang: $(baw --version 2>/dev/null | head -1)"
    else
      warn "baw terpasang tapi belum di PATH — cari di $(npm prefix -g)/bin"
    fi
  else
    warn "gagal pasang baw (coba manual: npm install -g @binance/agentic-wallet)"
  fi
else
  warn "node tidak bisa dipasang otomatis — wallet dilewati"
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
