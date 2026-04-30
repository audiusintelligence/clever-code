---
description: CRUD-Resource zur aktuellen Solution hinzufügen
agent: clever-solution
---

Resource hinzufügen mit `clever add-resource`.

Argumente: $1 = ResourceName (PascalCase), $2..$N = field:type Paare

Workflow:
1. Slug aus CWD ermitteln (`pwd` enthält `.clever/solutions/<slug>`)
2. wenn unklar: User fragen welche Solution
3. `clever add-resource <slug> $1 $2 $3 ...`
4. `clever rebuild <slug>`
5. `clever logs <slug> backend` - keine Errors?
6. URL der List-Page zeigen

Field types: str | text | int | float | bool | datetime | uuid

Beispiele:
- `/add Project name:str description:text`
- `/add Invoice number:str amount:float paid:bool`
