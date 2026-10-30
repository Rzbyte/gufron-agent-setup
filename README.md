# Setup Gufron agent — satu wallet

Salinan bersih dari setup Hermes Agent yang dipakai sehari-hari: config, persona, dan **satu**
integrasi wallet. Semua rahasia sudah dibuang. Isi key sendiri.

Versi ini sengaja kecil: **satu Binance Agentic Wallet**. Kalau nanti mau akun kedua, tinggal
`baw auth signin` lagi pakai direktori state berbeda — nggak ada yang perlu diubah di sini.

## Isi repo

| Path | Keterangan |
|---|---|
| `config/config.yaml` | config Hermes. Yang tadinya rahasia jadi `<SET_ME>` |
| `SOUL.md` | persona / system prompt agent |
| `.env.example` | nama variabel env saja, nilainya kosong |
| `skills/binance-agentic-wallet/` | skill resmi BAW: sign-in, preview, send, approval |

## Cara install

```bash
# 1. Hermes (Linux/macOS, nggak perlu root)
bash <(curl -fsSL https://hermes-agent.nousresearch.com/install.sh)

# 2. repo ini
git clone https://github.com/Rzbyte/gufron-agent-setup ~/gufron-setup

# 3. config + persona + skill wallet
cp ~/gufron-setup/config/config.yaml ~/.hermes/config.yaml
cp ~/gufron-setup/SOUL.md            ~/.hermes/SOUL.md
mkdir -p ~/.agents/skills
cp -r ~/gufron-setup/skills/binance-agentic-wallet ~/.agents/skills/

# 4. env
cp ~/gufron-setup/.env.example ~/.hermes/.env
```

Terus buka `~/.hermes/.env` dan isi minimal empat ini:

| Variabel | Dari mana |
|---|---|
| `DEEPSEEK_API_KEY` | platform.deepseek.com — atau ganti `model.default`/`model.provider` di `config.yaml` ke provider yang sudah lu punya |
| `TELEGRAM_BOT_TOKEN` | @BotFather di Telegram → `/newbot` |
| `TELEGRAM_ALLOWED_USERS` | user id Telegram lu (angka, tanya @userinfobot) |
| `TELEGRAM_HOME_CHANNEL` | chat id tempat bot ngirim, biasanya angka yang sama |

Opsional: `SERPER_API_KEY` kalau mau web search, `BROWSERBASE_*` kalau pakai browserbase.

Sisa `<SET_ME>` di `config.yaml` itu setting biasa, bukan rahasia — isi atau hapus key-nya.

## Nyalain

```bash
hermes doctor          # cek instalasi
hermes gateway run     # atau: systemctl --user start hermes-gateway setelah `hermes setup`
```

Kirim pesan ke bot di Telegram; balasan pertama berarti sudah nyambung.

## Sambungin satu wallet

```bash
baw auth signin      # buka link yang muncul, approve di Binance App
baw auth verify
baw wallet address --json
```

Di Binance App: klaim Agent ID `.ai` dan nyalakan **Developer Mode** (agent butuh itu buat manggil
kontrak). `baw wallet settings --json` harus nunjukin `devMode.enabled: true`, dan sisain sedikit
BNB di wallet buat gas.

Semua transaksi lewat `baw contract-call preview` dulu, baru `execute`; preview-nya nunjukin
perubahan saldo/allowance dan flag risiko. Approve cuma yang sudah lu baca.

## Catatan

- Repo ini nggak bisa sign atau belanjain apa pun sendiri — nggak ada key di sini.
- Persona (`SOUL.md`) pakai bahasa Indonesia informal; ganti sesuai gaya lu.
- Skill itu markdown: bebas edit atau hapus file di `~/.agents/skills/`.
