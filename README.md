# Setup Gufron agent — 1 wallet

Ini contekan setup agent Hermes yang biasa gua pakai, sudah dibersihin dari semua rahasia.
Isinya: config, watak agent (SOUL), dan satu integrasi wallet Binance.

Targetnya simpel: **dalam 15 menit lu punya agent yang nyambung ke Telegram dan bisa
manggil transaksi dari 1 wallet** — asal lu isi key sendiri.

---

## Yang lu butuhin dulu

- Komputer atau VPS Linux (atau macOS). Nggak perlu root.
- Akun DeepSeek (atau provider lain) buat API key model.
- Bot Telegram dari @BotFather.
- App Binance di HP, sudah punya wallet Agentic + Agent ID `.ai`.

Belum punya wallet? Skip dulu, agent tetap jalan tanpa bagian wallet.

---

## Langkah 1 — pasang Hermes

```bash
bash <(curl -fsSL https://hermes-agent.nousresearch.com/install.sh)
```

Tunggu sampai selesai. Kalau perintah `hermes` sudah kebaca di terminal, lanjut.

## Langkah 2 — ambil repo ini

```bash
git clone https://github.com/Rzbyte/gufron-agent-setup ~/gufron-setup
```

## Langkah 3 — pasang config, watak, dan skill wallet

```bash
cp ~/gufron-setup/config/config.yaml ~/.hermes/config.yaml
cp ~/gufron-setup/SOUL.md            ~/.hermes/SOUL.md
mkdir -p ~/.agents/skills
cp -r ~/gufron-setup/skills/binance-agentic-wallet ~/.agents/skills/
```

## Langkah 4 — isi key

```bash
cp ~/gufron-setup/.env.example ~/.hermes/.env
nano ~/.hermes/.env
```

Cuma 4 baris yang wajib diisi:

| Baris | Isi apa |
|---|---|
| `DEEPSEEK_API_KEY=` | API key dari platform.deepseek.com |
| `TELEGRAM_BOT_TOKEN=` | token bot dari @BotFather |
| `TELEGRAM_ALLOWED_USERS=` | angka user id Telegram lu (@userinfobot) |
| `TELEGRAM_HOME_CHANNEL=` | angka chat id tempat bot posting, biasanya sama |

Sisanya boleh kosong. Simpan pakai Ctrl+O, Enter, lalu Ctrl+X.

> Pakai provider lain? Ganti `model.default` dan `model.provider` di `~/.hermes/config.yaml`,
> lalu isi key provider itu di `.env`.

## Langkah 5 — nyalain

```bash
hermes doctor
hermes gateway run
```

Buka Telegram, kirim pesan ke bot lu. Kalau dibalas, berarti sudah nyambung.

## Langkah 6 — sambungin wallet (opsional)

```bash
baw auth signin     # muncul link, buka, approve di app Binance
baw auth verify
baw wallet address --json
```

Di app Binance, pastikan:

- sudah punya Agent ID `.ai`
- **Developer Mode** nyala
- ada sedikit BNB buat gas

Cek dengan `baw wallet settings --json`, harus muncul `devMode.enabled: true`.

---

## Kalau ada masalah

| Gejala | Biasanya karena |
|---|---|
| Bot nggak bales | `TELEGRAM_BOT_TOKEN` atau `TELEGRAM_ALLOWED_USERS` salah |
| Error developer mode | Developer Mode belum nyala di app |
| Ditolak `351801` | Agent ID `.ai` belum diklaim |
| Transaksi gagal terus | BNB buat gas habis, sisain ±0.0005 BNB |

---

## Aturan aman

- Repo ini nggak punya key apa pun. Nggak bisa sign atau kirim duit sendiri.
- Semua transaksi lewat `preview` dulu. Baca perubahan saldo dan flag risikonya, baru `execute`.
- Jangan taruh isi `.env` di repo, chat, atau screenshot.
- `SOUL.md` itu watak agent — bebas diganti sesuai gaya lu.
