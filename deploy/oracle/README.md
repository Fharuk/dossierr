# Dossier on the free Oracle Cloud server: step by step
#
# About 25 minutes, most of it waiting for Oracle's signup check. Everything
# here is on the Always Free tier: no charge, no trial that ends.

## 1. The server

1. Sign up at https://signup.cloud.oracle.com and pick your home region — the
   one nearest you. It can't be changed later.
   - Oracle asks for a card. It's identity verification: a temporary hold
     (about $1) appears and goes away, and Always Free resources aren't
     billed. **Don't** click "Upgrade to Pay As You Go"; the free account
     never charges on its own.
   - Approval can take minutes or a few hours.
2. Compute → Instances → **Create instance**.
   - **Image:** Canonical Ubuntu 24.04.
   - **Shape:** Ampere → `VM.Standard.A1.Flex`, **2 OCPUs / 12 GB** (the
     Always Free allowance since June 2026; older tenancies may show 4 / 24).
     If the shape isn't offered, the region is out of ARM capacity: try
     another availability domain, or retry; it comes back.
   - **Networking:** Create a new VCN, with a **public IPv4 address**.
   - **SSH keys:** upload your public key (or let it make a pair and download
     the private key — you can't get it again).
3. When it's running, note the public IP address.

## 2. Open the two ports

Oracle blocks everything but SSH by default; Docker's own rules don't help
because the VCN filters first. Instance → its subnet → Security list →
**Add ingress rules**:

| Source     | Protocol | Destination port |
| ---------- | -------- | ---------------- |
| `0.0.0.0/0`| TCP      | `80`             |
| `0.0.0.0/0`| TCP      | `443`            |

Ubuntu's own firewall on the image lets these through already (`iptables` in
`/etc/iptables/rules.v4` has the rules); if you enabled `ufw`, run
`sudo ufw allow 80,443/tcp`.

## 3. A free URL that points at it

DuckDNS: https://www.duckdns.org → sign in (GitHub or Google) → add a
subdomain, e.g. `fharuk-dossier`, and put the public IP in its **current ip**
field. Your address is then `fharuk-dossier.duckdns.org`.

That's all Caddy needs. Let's Encrypt issues the certificate the first time it
starts, and renews it from then on.

## 4. Install Docker

```bash
ssh -i /path/to/your-key ubuntu@<public-ip>
sudo apt update && sudo apt install -y docker.io docker-compose-v2 git
sudo usermod -aG docker $USER && exit   # log back in for the group to apply
```

## 5. Put Dossier's files on the server

On your machine, from this repository:

```bash
scp -i /path/to/your-key deploy/oracle/compose.yml deploy/oracle/Caddyfile \
    ubuntu@<public-ip>:~/
```

(Or `git clone` this repository there and copy the two files out of
`deploy/oracle/`.)

## 6. Fill in `.env`

On the server:

```bash
cd ~ && cp .env.example .env && nano .env
```

Every value, with where it comes from, is in `.env.example`. The two that
matter most:

- `DOSSIER_PASSWORD`: a hash, not the password. Make it with the image:

  ```bash
  docker run --rm -it ghcr.io/aientech/dossier hash-password
  ```

- `DATABASE_URL`: your Neon connection string, with `?sslmode=require`.

## 7. Start it

```bash
docker compose up -d
docker compose logs -f app     # migrations and the seed, then "Ready"
```

Open `https://<your-duckdns-name>` and sign in with your password.

## 8. After that

- **Upgrades:** `docker compose pull && docker compose up -d`. The migrations
  run on start; your data is in Neon, so nothing is lost.
- **Backups:** on every start Dossier also takes its own nightly one to
  `/data` inside the `data` volume, and Settings → Your data exports
  everything as one file. To copy the volume's files out:
  `docker compose cp app:/data ./dossier-data`.
- **Your time zone:** `TZ` in `.env` decides when 03:00 is.
- **Keep it free:** 2 OCPUs and 12 GB are the Always Free allowance, and
  200 GB of block storage is included (the boot volume counts). Don't add a
  second shape or a paid load balancer.
- **Idle reclaim:** Oracle can reclaim *idle* resources (under 20% CPU for 7
  days) on Always Free. Dossier's scheduler ticks and a nightly backup keep
  it from looking entirely dead; if it ever does get reclaimed, reinstalling
  is the same steps, and your data is still in Neon.
