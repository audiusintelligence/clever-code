---
description: Neue Clever Solution scaffolden (deterministisch)
agent: clever-solution
---

Neue Solution erstellen.

Argumente:
- $1 = Slug (z.B. invoice-tracker)
- $2 = Beschreibung (optional)

Workflow:
1. `clever check $1`
2. wenn frei: `clever new $1 "$2"`
3. `clever up $1`
4. URLs an User
