# Developer's Diary: The Pitfalls & Discoveries

*This section provides the "drama" and narrative arc for the blog post. It contrasts the clean "final" architecture with the messy reality of getting there.*

## 1. The "Simple" Network Fallacy
**Expectation**: "I’ll just spin up a few Docker Compose stacks and they’ll talk to each other."
**The Pitfall**: We quickly realized that independent stacks (TheHive, MISP, etc.) created their own isolated networks. They couldn’t resolve each other by hostname.
**The Drama**: We debated monolithic `docker-compose.yml` vs. isolated stacks. Monoliths are unmanageable; isolation breaks integration.
**The Discovery**: The "Shared External Network" pattern (`cti-net`). It required a mental shift: infrastructure comes *first*. We had to build the roads (`cti-net`) before we could build the houses.

## 2. The Permission Nightmare
**The Challenge**: Docker makes running services easy. Docker makes file permissions *hell*.
**The Pitfall**: Postgres runs as UID 999. ElasticSearch runs as UID 1000. Redis runs as... something else.
**The Struggle**: We experienced the classic "CrashLoopBackOff." Logs screamed `Permission denied`. We tried `chmod 777` (the shameful quick fix), but it felt wrong.
**The Insight**: We needed automation, not manual hacks. The creation of `fix-permissions.sh` was a turning point—a "janitor script" that runs before deployment to ensure every container has exactly the keys to the castle it needs, and nothing more.

## 3. The Infinite Loop of MISP
**The Scene**: MISP was up. We could see the login page. We typed credentials. Enter.
**The Horror**: The browser spun. And spun. "Too many redirects."
**The Investigation**: We spent hours debugging nginx configs. MISP thought it was on port 443. Traefik knew it was on port 8443. They couldn't agree on reality.
**The Discovery**: The `CORE_HTTPS_PORT` variable. It wasn't enough to just map the ports in Docker; we had to *tell* MISP's internal nginx that "Hey, the world sees you on port 8443, deal with it."

## 4. The Data Hoarder's Dilemma (ElasticSearch)
**The Trap**: ElasticSearch is hungry. By default, it wants to eat all RAM and map all memory.
**The Crash**: Services wouldn't start. The host slowed to a crawl. `OOM Killed`.
**The Discovery**: `vm.max_map_count`. The realization that running a CTI stack isn't just "running containers"—it's system administration. We had to tune the host kernel itself to support the massive indexing requirements of TheHive and Wazuh.

## 5. The Wazuh Fortress
**The Challenge**: "Let's add Wazuh for SIEM."
**The Pitfall**: Wazuh is paranoid (rightfully so). It refuses to talk to anyone without strict TLS authentication.
**The Drama**: The official cert tool failed. The default certs were for `localhost`. Our stack uses `wazuh.indexer` hostnames. Java threw `CertificateException` tantrums.
**The Triumph**: Use the source. We abandoned the automated tools and wrote our own `openssl` script (`generate-certs.sh`), hand-crafting the Subject Alternative Names (SANs). Controlling the cryptography ourselves turned a "black box" failure into a reliable security feature.
