---
id: P-0001
step: plan
symptom: plan --from fails with "skills must be an array"
cause: the card wrote skills as a string in YAML-flavoured JSON
fix: write skills as a list of objects with id, required, and reason
verify: batch.py lint <card> reports no error
severity: error
source: B96
---

# Card skills written as a string

The JSON block inside the card is plain JSON. `skills: "test-driven-development"`
is a string, and the planner rejects it before it reads anything else. Write:

```json
"skills": [{"id": "test-driven-development", "required": true, "reason": "new behaviour"}]
```
