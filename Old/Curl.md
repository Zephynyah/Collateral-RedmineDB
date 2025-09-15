
```bash
curl -s http://localhost:3000/api/projects/25/db.json -X POST -H "Content-Type: application/json" -H "X-Redmine-API-Key: a0ecf2f6fe6fa3822d17c7cbb547aceb727b3507" -d '{"db_entry": {"name": "Test-Entry-001", "description": "Test database entry for project 25"}}' | jq .

---
{
  "db_entry": {
    "id": 19253,
    "name": "Test-Entry-001",
    "description": "Test database entry for project 25",
    "is_private": false,
    "project": {
      "id": 25,
      "name": "Mock Project"
    },
    "status": {
      "id": 1,
      "name": "valid"
    },
    "type": {
      "id": 1,
      "name": "Workstation"
    },
    "author": {
      "id": 1,
      "name": "API User"
    },
    "custom_fields": [],
    "created_on": "2025-09-14T21:02:00.718Z",
    "updated_on": "2025-09-14T21:02:00.718Z"
  }
}
```