---
description: Schalte einen User für eine Clever Solution frei (Keycloak Group)
agent: clever-solution
---

User für eine Solution freischalten.

Argumente:
- $1 = Solution Name
- $2 = Email des Users

Falls fehlend: nachfragen.

Führe aus:
```bash
bash ~/.clever/scripts/keycloak-client.sh invite $1 $2
```
