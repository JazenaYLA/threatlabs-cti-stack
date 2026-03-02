# AI-Assisted Infrastructure Configuration – Troubleshooting Journal

> **Date**: 2026-03-01  
> **Author**: AI Agent (Antigravity) + Jamz  
> **Scope**: Configuring PMG + Stalwart mail flow via SSH from a Windows workstation

This document captures the real-world challenges encountered while an AI coding agent (running locally on a Windows machine) configured two remote Linux servers entirely via SSH. These are the kinds of issues that official docs don't mention and are worth blogging about.

---

## 1. PMG Postfix Template Overwrite Trap

**What happened**: When adding SASL authentication config for the Gmail smarthost relay, we created `/etc/pmg/templates/main.cf.in` with only the SASL lines. PMG regenerates Postfix's `main.cf` from this template — so our 6-line file **replaced the entire Postfix configuration**, breaking mail delivery.

**The fix**: The default template lives at `/var/lib/pmg/templates/main.cf.in`. The correct approach is to **copy** the default template to `/etc/pmg/templates/main.cf.in` first, then **append** your customizations:
```bash
cp /var/lib/pmg/templates/main.cf.in /etc/pmg/templates/main.cf.in
cat >> /etc/pmg/templates/main.cf.in << 'EOF'
# Custom additions
smtp_sasl_auth_enable = yes
...
EOF
pmgconfig sync --restart 1
```

**Lesson**: PMG's template override system is all-or-nothing. If you create a custom template, it completely replaces the default — it doesn't merge. This is documented nowhere obvious.

---

## 2. Fetchmail Ownership & Daemon Mode Conflict

**What happened**: After installing fetchmail and creating `/etc/fetchmailrc`, the systemd service refused to start (exit code 6). Two distinct issues:

1. **File ownership**: Debian's fetchmail service runs as user `fetchmail`, but we created the config as root. Fetchmail strictly requires the config file to be owned by the user running it.
2. **Daemon mode conflict**: We added `set daemon 120` to the config, but the systemd unit already passes `--daemon 300` on the command line. Having both causes fetchmail to reject the config.

**The fix**:
```bash
# Remove 'set daemon' from fetchmailrc (let systemd manage the interval)
chown fetchmail:root /etc/fetchmailrc
chmod 600 /etc/fetchmailrc
# Also ensure START_DAEMON=yes in /etc/default/fetchmail
sed -i 's/START_DAEMON=no/START_DAEMON=yes/' /etc/default/fetchmail
systemctl restart fetchmail
```

**Lesson**: Always check `cat /lib/systemd/system/fetchmail.service` to understand what flags the service unit passes. The `ExecCondition` check verifies `START_DAEMON=yes` and `ExecStart` already includes `--daemon`.

---

## 3. SSH + JSON = Shell Escaping Nightmare

**What happened**: When trying to create Stalwart Mail Server domains and accounts via its REST API using `curl` through an SSH session from Windows PowerShell, every JSON payload failed with `"JSON deserialization failed"`.

The chain of escaping: `PowerShell → SSH → Bash → curl` means quotes get mangled at every layer. Even heredocs and echo-to-file approaches failed because the double and single quotes were stripped or doubled.

**The fix**: Write JSON payloads as local files on the Windows machine, `scp` them to the remote server, then reference them with curl's `@file` syntax:
```bash
# On Windows: write clean JSON files locally
# Then SCP them over
scp payload.json root@server:/tmp/
# Then on remote
curl -d @/tmp/payload.json ...
```

**Lesson**: When an AI agent operates over SSH, **never try to pass complex JSON inline**. Always use the file-based approach. This is a fundamental limitation of multi-layer shell escaping that affects any automation tool, not just AI agents.

---

## 4. PMG Relay Config ≠ Postfix relayhost

**What happened**: After setting PMG's relay via `pmgsh set /config/mail -relay smtp.gmail.com`, we checked `postconf relayhost` and it returned empty. We thought the config didn't take.

**Reality**: PMG does **not** use Postfix's `relayhost` directive. PMG has its own mail proxy (`pmg-smtp-filter`) that handles relay routing internally based on the settings in `/etc/pmg/pmg.conf`. The relay, port, and nomx settings are all managed by PMG's proxy, not by Postfix directly.

**Verification**: Check the PMG config instead:
```bash
pmgsh get /config/mail   # Shows relay, relayport, relaynomx
cat /etc/pmg/pmg.conf    # Shows the raw config
```

**Lesson**: PMG wraps Postfix but doesn't use all of its native directives. Don't assume standard Postfix troubleshooting applies 1:1.

---

## 5. Stalwart API – No CLI, Version-Dependent Endpoints

**What happened**: Stalwart Mail Server (installed via Proxmox community scripts) had no `stalwart-cli` binary available. The API endpoint we initially tried (`/api/domain`) returned 404.

**Reality**: Stalwart uses a unified `/api/principal` endpoint for ALL directory objects — domains, accounts, groups, mailing lists. The `type` field in the JSON body distinguishes them. You filter by type using query parameters: `/api/principal?types=domain`.

**The correct API pattern**:
```bash
# Create domain
curl -u admin:pass -X POST -H 'Content-Type: application/json' \
  -d '{"type":"domain","name":"example.org",...}' \
  http://127.0.0.1:8080/api/principal

# Create account
curl -u admin:pass -X POST -H 'Content-Type: application/json' \
  -d '{"type":"individual","name":"user","emails":["user@example.org"],...}' \
  http://127.0.0.1:8080/api/principal
```

**Lesson**: Read the OpenAPI spec at `https://raw.githubusercontent.com/stalwartlabs/stalwart/main/api/v1/openapi.yml` — it's the single source of truth. The web docs can lag behind.

---

## 6. Postfix relayhost vs PMG default_transport

**What happened**: Even after configuring the smarthost in PMG via `pmgsh set /config/mail -smarthost smtp.gmail.com`, outbound emails were timing out. Postfix logs showed it was trying to connect directly to Gmail's deep MX servers (`alt1.gmail-smtp-in.l...:25`) instead of port 587 on the relay.

**Reality**: PMG's template populates `default_transport` for the smarthost, not `relayhost`. Furthermore, when our custom template applied the SASL password maps, it was looking for `[smtp.gmail.com]:587`. Because PMG configured `default_transport = smtp:smtp.gmail.com:587` (without brackets), the SASL lookup failed silently, causing Postfix to fall back to direct MX delivery.

**The Fix**:
Always include both bracketed and unbracketed versions in `/etc/postfix/sasl_passwd` when dealing with PMG templates:
```text
[smtp.gmail.com]:587 <SERVICE_EMAIL>:password
smtp.gmail.com:587 <SERVICE_EMAIL>:password
```

## 7. Stalwart IMAP Strictness

**What happened**: When verifying email delivery via a Python `imaplib` script, the `login()` command failed with `AUTHENTICATIONFAILED` despite resetting the password via API.

**Reality**: Two strict Stalwart behaviors were at play:
1. **STARTTLS is mandatory**: Stalwart rejects plain-text IMAP logins on port 143. You either use IMAPS (993) or you MUST issue `STARTTLS` on 143 before logging in.
2. **Short Usernames Only**: If you create a user with `"name": "noreply"`, Stalwart expects the login username to be exactly `noreply`. If you try to log in as `noreply@domain.com` (which is standard for most mail servers), Stalwart rejects it.

**Lesson**: When testing IMAP against modern secure servers like Stalwart, always enforce SSL/TLS in your test scripts and verify exactly how the login `name` attribute is mapped in the directory.

---

## Key Takeaways for AI-Assisted Server Configuration

1. **File-based payloads over inline JSON** when crossing shell boundaries (SSH, PowerShell, etc.)
2. **Always check systemd unit files** before writing daemon configs — the unit may already handle what you're trying to configure
3. **PMG's template system is an override, not a merge** — copy defaults first, then modify
4. **Read the actual config files** (`pmg.conf`, systemd units) instead of assuming standard behavior
5. **SCP + script files** is more reliable than complex SSH one-liners when the command involves loops or special characters
6. **Watch out for strict defaults** — modern servers (Stalwart) enforce STARTTLS and exact username matching out of the box.
