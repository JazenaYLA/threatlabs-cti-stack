# Email Configuration Guide

> **Last updated**: 2026-03-01  
> **Scope**: PMG (<PMG_IP>), Stalwart (<STALWART_IP>), Cloudflare Email Routing, Gmail

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                        INTERNET                             │
└──────────┬──────────────────────────────┬───────────────────┘
           │ INBOUND                      │ OUTBOUND
           ▼                              ▲
┌──────────────────────┐        ┌─────────────────────────┐
│ Cloudflare Email     │        │   Gmail SMTP Relay      │
│ Routing              │        │  smtp.gmail.com:587     │
│ (<YOUR_DOMAIN>)      │        │  Auth: App Password     │
│                      │        └──────────┬──────────────┘
└──────┬───────────────┘                   │
       │                                   │
       ▼                                   │
┌──────────────────────┐                   │
│ <YOUR_GMAIL>@        │                   │
│ gmail.com            │                   │
│ (catch-all for       │                   │
│  service accounts)   │                   │
└──────┬───────────────┘                   │
       │ IMAP fetch (every 120s)           │
       ▼                                   │
┌──────────────────────────────────────────┤
│         PMG  <PMG_IP>                   │
│  • Fetchmail polls Gmail IMAP            │
│  • SpamAssassin + ClamAV filtering       │
│  • DKIM signing (outbound)               │
│  • Transport rules → Stalwart            │
│  • Yahoo smarthost relay (outbound)      │
└──────────┬───────────────────────────────┘
           │ SMTP deliver to Stalwart
           ▼
┌──────────────────────────────────────────┐
│       Stalwart  <STALWART_IP>           │
│  • Local mailboxes for service accounts  │
│  • IMAP access for CTI tools             │
│  • opencti@ misp@ thehive@ wazuh@ etc.   │
└──────────────────────────────────────────┘
           │ IMAP polling
           ▼
┌──────────────────────────────────────────┐
│        CTI Services (VLAN 101)           │
│  TheHive  → IMAP → Stalwart             │
│  OpenCTI  → IMAP → Stalwart             │
│  MISP     → SMTP → PMG → Gmail          │
│  Wazuh    → SMTP → PMG → Gmail          │
└──────────────────────────────────────────┘
```

## Cloudflare Email Routing

Cloudflare routes inbound email based on destination address.

### AI & Automation (AgentMail Integration)

We use AgentMail as an API-first backend for our OpenClaw/n8n automation workflows, bypassing PMG entirely.

| Public Domain | AgentMail Destination | Purpose |
|---------------|------------------------|---------|
| `*@<BRAND_DOMAIN>` | `threatresearcher@agentmail.to` | AI Triage for the `.com` domain |
| `*@<DOMAIN>` | `threatlabs@agentmail.to` | AI Triage for the `.net` domain |

> **Note**: Plus-addressing (e.g., `ai+phishing@`) can be used to route specific webhooks payload types inside your orchestration scripts.

### Service accounts → `<SERVICE_EMAIL>` (fetched by PMG)
| Address | Domain |
|---------|--------|
| `noreply@` | <YOUR_DOMAIN> |
| `wazuh@` | <YOUR_DOMAIN> |
| `ioc@` | <YOUR_DOMAIN> |
| `ti@` | <YOUR_DOMAIN> |
| `ai@` | <YOUR_DOMAIN> |
| `opencti@` | <YOUR_DOMAIN> |
| `misp@` | <YOUR_DOMAIN> |

### Personal/brand → `<PERSONAL_EMAIL>` (stays in Gmail)

| Address | Domain |
|---------|--------|
| `<PERSONAL_PREFIX>@` | <DOMAIN> |
| `<BRAND_PREFIX>@` | <DOMAIN> |
| `security@` | <DOMAIN> |
| `admin@` | <DOMAIN> |
| `abuse@` | <DOMAIN> |
| `or@` | <DOMAIN> |
| `postmaster@` | <DOMAIN> |

---

## PMG Configuration (<PMG_IP>)

### Trusted Networks

Allows all homelab LXCs to send mail through PMG without authentication:

```
<SERVICE_IP>/24    # Main LAN
<SERVICE_IP>/24    # Default VLAN (general services)
<SERVICE_IP>/24  # VLAN 101 (CTI services)
```

**Command used:**

```bash
pmgsh create /config/mynetworks -cidr '<SERVICE_IP>/24'
pmgsh create /config/mynetworks -cidr '<SERVICE_IP>/24'
pmgsh create /config/mynetworks -cidr '<SERVICE_IP>/24'
```

### Yahoo Smarthost Relay (Outbound)

PMG relays all outbound mail through Yahoo SMTP:

```
Relay host:  smtp.mail.yahoo.com
Port:        587
No MX:       yes
```

**Commands used:**

```bash
pmgsh set /config/mail -smarthost smtp.mail.yahoo.com -smarthostport 587
```

### SASL Authentication for Yahoo

Created at `/etc/postfix/sasl_passwd`:

```
[smtp.mail.yahoo.com]:587 <PERSONAL_EMAIL>@yahoo.com:<YAHOO_APP_PASSWORD>
```

**Commands used:**

```bash
echo '[smtp.mail.yahoo.com]:587 <PERSONAL_EMAIL>@yahoo.com:<YAHOO_APP_PASSWORD>' > /etc/postfix/sasl_passwd
postmap /etc/postfix/sasl_passwd
chmod 600 /etc/postfix/sasl_passwd /etc/postfix/sasl_passwd.db
```

### Postfix Template Override

Custom SASL/TLS config appended to `/etc/pmg/templates/main.cf.in` (copied from `/var/lib/pmg/templates/main.cf.in` first):

```
# === Yahoo SASL relay authentication ===
smtp_sasl_auth_enable = yes
smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd
smtp_sasl_security_options = noanonymous
smtp_tls_security_level = encrypt
smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt
```

> **Important**: Always copy the default template first, then append. Never overwrite.

### Relay Domains

```bash
pmgsh create /config/domains -domain <YOUR_DOMAIN> -comment 'CTI service domain'
pmgsh create /config/domains -domain <YOUR_BRAND_DOMAIN> -comment 'Brand domain'
```

### Transport Rules (Deliver to Stalwart)

```bash
pmgsh create /config/transport -domain <YOUR_DOMAIN> -host <SERVICE_IP> -port 25 -use_mx 0 -comment 'Deliver to Stalwart'
pmgsh create /config/transport -domain <YOUR_BRAND_DOMAIN> -host <SERVICE_IP> -port 25 -use_mx 0 -comment 'Deliver to Stalwart'
```

### Fetchmail (Inbound IMAP Polling)

Installed via `apt-get install fetchmail`. Configuration at `/etc/fetchmailrc`:

```
set daemon 900
set syslog
set no bouncemail

poll imap.gmail.com
  protocol IMAP
  port 993
  user '<SERVICE_EMAIL>'
  password '<PMG-fetchmail app password>'
  ssl
  sslcertck
  folder 'INBOX'
  fetchall
  nokeep
  mda '/usr/sbin/sendmail -oi -f %F -- %T'
```

**Key settings:**

- Polls every **15 minutes (900 seconds)** to avoid Gmail rate limits
- Fetches **all** messages, does **not keep** them on Gmail after fetch
- Re-injects into PMG's Postfix via `sendmail` MDA for filtering before delivery to Stalwart

**Service management:**

```bash
sed -i 's/START_DAEMON=no/START_DAEMON=yes/' /etc/default/fetchmail
echo 'OPTIONS="--daemon 900"' >> /etc/default/fetchmail
systemctl enable fetchmail
systemctl start fetchmail
```

### Apply Config Changes

After any PMG configuration change:

```bash
pmgconfig sync --restart 1
```

---

## Stalwart Configuration (<SERVICE_IP>)

### Admin Access

- **Web UI**: `http://<SERVICE_IP>:8080` (or via Caddy: `https://mail.<DOMAIN>`)
- **Credentials**: `admin` / `<STALWART_PASSWORD>`

### Domains Created

| Domain | Type | ID |
|--------|------|----|
| `<DOMAIN>` | CTI service domain | 1 |
| `<BRAND_DOMAIN>` | Brand domain | 2 |

### Service Accounts Created
All accounts use password `<SERVICE_PASSWORD>` and role `user`.

| Account | Email | Purpose |
|---------|-------|---------|
| `opencti` | `opencti@<YOUR_DOMAIN>` | OpenCTI connector |
| `misp` | `misp@<YOUR_DOMAIN>` | MISP alerts |
| `thehive` | `thehive@<YOUR_DOMAIN>` | TheHive email-to-case |
| `noreply` | `noreply@<YOUR_DOMAIN>`, `noreply@<YOUR_BRAND_DOMAIN>` | Service notifications |
| `wazuh` | `wazuh@<YOUR_DOMAIN>` | Security alerts |
| `ai` | `ai@<YOUR_DOMAIN>` | AI service account |
| `ti` | `ti@<YOUR_DOMAIN>` | Threat intelligence |
| `ioc` | `ioc@<YOUR_DOMAIN>` | IOC submissions |

### API Notes

Stalwart uses a unified `/api/principal` endpoint for ALL directory objects. The `type` field distinguishes them:

- `"type":"domain"` for domains
- `"type":"individual"` for user accounts

> **Gotcha**: JSON payloads sent via `curl` through SSH from Windows will fail due to multi-layer shell escaping. Always SCP the JSON file to the server first, then use `curl -d @/path/to/file.json`.

### Creation Commands (for reference)

```bash
# Domains were created via API using SCP'd JSON payloads
curl -s -u admin:<STALWART_PASSWORD> -X POST -H 'Content-Type: application/json' \
  -d @/tmp/stalwart_domain1.json http://127.0.0.1:8080/api/principal

# Account payloads follow same pattern — batch created via /tmp/stalwart_create_all.sh
```

---

## DKIM Configuration

### PMG DKIM Selector

- **Selector name**: `pmg2026`
- **Key size**: 2048-bit RSA
- **Private key**: `/etc/pmg/dkim/pmg2026.private`

### DKIM Signing Domains

```bash
pmgsh create /config/dkim/selector --keysize 2048 --selector pmg2026
pmgsh create /config/dkim/domains --domain <DOMAIN> --comment 'CTI domain'
pmgsh create /config/dkim/domains --domain <BRAND_DOMAIN> --comment 'Brand domain'
pmgconfig sync --restart 1
```

### DNS TXT Records for Cloudflare

Add the following TXT record to **both** `<DOMAIN>` and `<BRAND_DOMAIN>`:

| Type | Name | Content |
|------|------|---------|
| TXT | `pmg2026._domainkey` | `<DKIM_RECORD>` |

---

## DNS Configuration

### Unifi Controller (Internal A Records)

We bypass Caddy entirely and route directly to the backend servers:

| Record | Target IP | URL |
|--------|-----------|-----|
| `pmg.lab.local` | `<SERVICE_IP>` | `https://pmg.lab.local:8006` |
| `mail.lab.local` | `<SERVICE_IP>` | `http://mail.lab.local:8080` |

### Cloudflare (External)

- MX records managed by Cloudflare Email Routing
- DKIM TXT records (`pmg2026._domainkey`) added for both domains

---

## LXC Service SMTP Testing

Every LXC that needs to send email should be configured to use `<SERVICE_IP>:26` with no authentication (trusted relay).

To verify the end-to-end outbound relay is working, SSH into any trusted LXC (or PMG itself) and run:

```bash
echo "Test email" | mail -s "Outbound Relay Test" -r noreply@<DOMAIN> <SERVICE_EMAIL>
```

To verify inbound IMAP delivery, check the Stalwart `noreply` mailbox:

```python
import imaplib, ssl
ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE
# Stalwart requires STARTTLS and short usernames
m = imaplib.IMAP4('<SERVICE_IP>', 143)
m.starttls(context=ctx)
m.login('noreply', '<SERVICE_PASSWORD>')
m.select('INBOX')
typ, data = m.search(None, 'ALL')
print(f"Messages: {len(data[0].split())}")
m.logout()
```

---

## Gmail App Passwords

| Name | Purpose | Used By |
|------|---------|---------|
| `PMG-fetchmail` | IMAP polling for inbound mail | PMG fetchmail daemon |
| `PMG-smarthost` | SMTP relay for outbound mail | PMG Postfix SASL |
| `Stalwart-relay` | Direct Gmail access if needed | Stalwart |

> **Security**: App passwords are stored in config files with `chmod 600`. Generate from [Google App Passwords](https://myaccount.google.com/apppasswords). Requires 2FA enabled.

---

## Troubleshooting

### Test outbound relay

```bash
echo 'Test' | mail -s 'PMG Test' -r noreply@<DOMAIN> <SERVICE_EMAIL>
tail -30 /var/log/mail.log | grep -i 'relay\|status\|error\|sasl'
```

### Check fetchmail status

```bash
systemctl status fetchmail
grep fetchmail /var/log/syslog | tail -10
```

### Check PMG configuration

```bash
pmgsh get /config/mail
pmgsh get /config/domains
pmgsh get /config/transport
pmgsh get /config/mynetworks
postconf mynetworks
postconf smtp_sasl_auth_enable
```
