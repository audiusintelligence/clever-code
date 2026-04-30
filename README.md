# Clever Code

Public Installer + Guides für Clever Solutions auf der Clever Company Plattform.

> **Mac User?** Direkt:
> ```bash
> curl -fsSL https://code.clevercompany.ai/install | bash
> ```

## Was hier liegt

| Pfad | Zweck |
|------|-------|
| `install.sh` | One-liner installer (`code.clevercompany.ai/install`) |
| `index.html` | Landing Page (`code.clevercompany.ai`) |
| `agent/` | opencode Agent-Definitionen |
| `command/` | opencode Slash-Commands |
| `guides/` | Brand, Architektur, Conventions, Recipes |
| `scripts/` | Keycloak Helper, clever CLI |

## Was passiert beim Install

1. Lädt alle Guides nach `~/.clever/guides/`
2. Lädt opencode-Agent nach `~/.config/opencode/agent/`
3. Lädt Bash-Scripts nach `~/.clever/scripts/`
4. Verlinkt `clever` Command in `~/.local/bin/` oder `/usr/local/bin/`

**Keine** Klone, **keine** Templates - opencode generiert den Code aus den Guides.

## Hosting

Dieses Repo wird als **GitHub Pages** gehostet:
- DNS: `code.clevercompany.ai` → `audiusintelligence.github.io`
- Setup: Settings → Pages → Source: `main` branch, root

## Update-Workflow

Guides oder Scripts ändern? Einfach hier committen und pushen:
```bash
git push origin main
```

User auf der Mac-Seite holt das Update via:
```bash
clever update
```

## Lizenz

Internal - Clever Company AG
