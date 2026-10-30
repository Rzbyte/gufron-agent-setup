# Gufron agent setup — single wallet

A cleaned copy of the Hermes Agent setup used daily: the config, the persona, and the
**one** wallet integration. Every secret is stripped. Bring your own keys.

This version is deliberately small: **one Binance Agentic Wallet**. If you later want a second
account, just run `baw auth signin` again with a different state directory — nothing here has to
change.

## Contents

| Path | What it is |
|---|---|
| `config/config.yaml` | Hermes config. Anything that was a secret reads `<SET_ME>` |
| `SOUL.md` | agent persona / system prompt |
| `.env.example` | env var names only, values blank |
| `skills/binance-agentic-wallet/` | the official BAW skill: sign-in, previews, sends, approvals |

## Install

```bash
bash <(curl -fsSL https://hermes-agent.nousresearch.com/install.sh)
git clone https://github.com/Rzbyte/gufron-agent-setup ~/gufron-setup
cp ~/gufron-setup/config/config.yaml ~/.hermes/config.yaml
cp ~/gufron-setup/SOUL.md ~/.hermes/SOUL.md
cp -r ~/gufron-setup/skills/binance-agentic-wallet ~/.agents/skills/
cp ~/gufron-setup/.env.example ~/.hermes/.env    # then fill the values
```

Fill at minimemum your model provider key, the Telegram bot token and your chat id.
Anything still reading `<SET_ME>` has to be set before the agent starts.

## Connect one wallet

```bash
baw auth signin      # open the link, approve in the Binance App
baw auth verify
baw wallet address --json
```

In the Binance App: claim a `.ai` Agent ID and turn on **Developer Mode** (the agent needs it to
call contracts). `baw wallet settings --json` should show `devMode.enabled: true`.

Every write goes through `baw contract-call preview` first, then `execute`; the preview shows the
simulated balance/allowance changes and any risk flags. Approve only what you have read.

## Notes

- Nothing in this repo can sign or spend anything on its own — there are no keys here.
- The persona (`SOUL.md`) writes in informal Indonesian; swap it for your own voice.
