# Gufron agent setup — single wallet

A cleaned copy of the Hermes Agent setup used daily: the config, the persona, and the
**one** wallet integration. Every secret is stripped. Bring your own keys.

This version is deliberately small: **one Binance Agentic Wallet**. If you later want a second
account, run `baw auth signin` again with a different state directory — nothing here has to change.

## Contents

| Path | What it is |
|---|---|
| `config/config.yaml` | Hermes config. Anything that was a secret reads `<SET_ME>` |
| `SOUL.md` | agent persona / system prompt |
| `.env.example` | env var names only, values blank |
| `skills/binance-agentic-wallet/` | the official BAW skill: sign-in, previews, sends, approvals |

## Install

```bash
# 1. Hermes itself (Linux/macOS, no root needed)
bash <(curl -fsSL https://hermes-agent.nousresearch.com/install.sh)

# 2. this repo
git clone https://github.com/Rzbyte/gufron-agent-setup ~/gufron-setup

# 3. config + persona + wallet skill
cp ~/gufron-setup/config/config.yaml ~/.hermes/config.yaml
cp ~/gufron-setup/SOUL.md            ~/.hermes/SOUL.md
mkdir -p ~/.agents/skills
cp -r ~/gufron-setup/skills/binance-agentic-wallet ~/.agents/skills/

# 4. env
cp ~/gufron-setup/.env.example ~/.hermes/.env
```

Then edit `~/.hermes/.env` and fill at least these four:

| Variable | Where to get it |
|---|---|
| `DEEPSEEK_API_KEY` | platform.deepseek.com — or change `model.default`/`model.provider` in `config.yaml` to a provider you already have |
| `TELEGRAM_BOT_TOKEN` | @BotFather in Telegram → `/newbot` |
| `TELEGRAM_ALLOWED_USERS` | your numeric Telegram user id (ask @userinfobot) |
| `TELEGRAM_HOME_CHANNEL` | the chat id where the bot should post, normally the same number |

Optional: `SERPER_API_KEY` for web search, the `BROWSERBASE_*` vars only if you use browserbase.

Anything still reading `<SET_ME>` in `config.yaml` is a setting, not a secret — set it or delete the key.

## Start it

```bash
hermes doctor          # checks the install
hermes gateway run     # or: systemctl --user start hermes-gateway after `hermes setup`
```

Send the bot a message on Telegram; the first reply proves the wiring.

## Connect one wallet

```bash
baw auth signin      # open the printed link, approve in the Binance App
baw auth verify
baw wallet address --json
```

In the Binance App: claim a `.ai` Agent ID and turn on **Developer Mode** (the agent needs it to
call contracts). `baw wallet settings --json` should show `devMode.enabled: true`, and keep a
little BNB on the wallet for gas.

Every write goes through `baw contract-call preview` first, then `execute`; the preview shows the
simulated balance/allowance changes and any risk flags. Approve only what you have read.

## Notes

- Nothing in this repo can sign or spend anything on its own — there are no keys here.
- The persona (`SOUL.md`) writes in informal Indonesian; swap it for your own voice.
- Skills are markdown: edit or delete any file under `~/.agents/skills/` freely.
