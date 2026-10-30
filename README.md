# Setup Gufron agent — 1 wallet

Ini contekan setup agent Hermes yang biasa gua pakai, sudah dibersihin dari semua rahasia.
Isinya: config, watak agent (SOUL), dan satu integrasi wallet Binance.

Targetnya simpel: **dalam 15 menit lu punya agent yang nyambung ke Telegram dan bisa
manggil transaksi dari 1 wallet** — asal lu isi key sendiri.

---

## Cara cepat (otomatis)

Satu perintah, sisanya script yang urus:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Rzbyte/gufron-agent-setup/main/install.sh)
```

Yang dikerjakan script:

1. pasang semua kebutuhan di awal: `git`, `curl`, `tar`, **Node + npm** (apt, Node bawaan Hermes, atau unduh resmi)
2. install Hermes kalau belum ada (tanpa login Portal, tanpa pertanyaan)
3. ambil repo ini, pasang config + SOUL + skill wallet
4. tanya **2 hal saja**: API key model, lalu token bot Telegram
5. chat id lu diambil otomatis — cukup kirim `/start` ke bot, script nungguin
6. pasang CLI `baw`
7. nyalakan gateway supaya bot langsung hidup

Kalau mau lewat langkah manual, lanjut baca dari bawah.

---

## Yang lu butuhin dulu

Cuma 2:

- **API key model** — daftar di https://platform.deepseek.com/api_keys (gratis, ada kredit awal)
- **Token bot Telegram** — chat @BotFather, kirim `/newbot`, ikuti 2 pertanyaan, dapat token

Opsional (buat bagian wallet):

- App Binance di HP + wallet Agentic + Agent ID `.ai`

Belum punya wallet? Lewati saja, agent tetap jalan penuh tanpa bagian wallet.

---

## Login sebagai root atau user biasa?

Dua-duanya bisa. Bedanya cuma di mana file mendarat, karena semua perintah di bawah pakai `~`:

| Login sebagai | Config | Skills | Binary |
|---|---|---|---|
| `root` | `/root/.hermes/` | `/root/.agents/skills/` | `/root/.local/bin/hermes` |
| user `hermes` | `/home/hermes/.hermes/` | `/home/hermes/.agents/skills/` | `/home/hermes/.local/bin/hermes` |

Kalau VPS-nya khusus buat agent, bikin user sendiri lebih rapi (systemd `--user` + linger jalan
tanpa root):

```bash
adduser hermes
usermod -aG sudo hermes
su - hermes        # lanjut semua langkah di bawah dari sini
```

Kalau tetap di root, jalankan perintah yang sama apa adanya — cukup ingat semua path ada di `/root`.

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

Sisanya boleh kosong (nggak perlu diisi). Simpan pakai Ctrl+O, Enter, lalu Ctrl+X.

> Pakai provider lain? Ganti `model.default` dan `model.provider` di `~/.hermes/config.yaml`,
> lalu isi key provider itu di `.env`.

## Langkah 5 — nyalain

```bash
hermes doctor
hermes gateway run
```

Buka Telegram, kirim pesan ke bot lu. Kalau dibalas, berarti sudah nyambung.

## Langkah 6 — sambungin wallet (opsional)

Pertama pasang CLI-nya (butuh Node 18+, `npm` harus ada):

```bash
npm install -g @binance/agentic-wallet
baw --version
```

Kalau `npm: command not found`, Hermes biasanya sudah bawa Node sendiri di
`~/.hermes/tools/node-*/bin` — tambahkan folder itu ke PATH, atau install Node dari nodejs.org.

Setelah `baw` kebaca:

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
