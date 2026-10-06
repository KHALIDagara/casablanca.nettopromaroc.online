# Netto Pro Maroc Casablanca

Static Astro website for `https://casablanca.nettopromaroc.online`, based on the MIT-licensed ProCleaning template.

## Stack

- Astro 6
- Tailwind CSS 4 + DaisyUI
- Markdown/MDX content collections
- Static `dist/` output served by Caddy

## Local commands

```bash
npm ci
npm run build
npm run preview
```

## Deployment

Pushes to `main` run `.github/workflows/publish.yml`, SSH to the VPS, clone/update `/opt/casablanca.nettopromaroc.online`, build with `npm ci && npm run build`, then install a marked Caddy block serving `dist/`.

Required GitHub Actions configuration:

- Secret: `DEPLOY_SSH_KEY`
- Variables: `DEPLOY_HOST`, `DEPLOY_USER`, `SITE_DOMAIN`

Template credit: <https://github.com/anastasiiaxfr/ProCleaning>.
