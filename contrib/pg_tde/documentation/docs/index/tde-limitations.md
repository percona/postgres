# Limitations of pg_tde

* Keys in the local keyfile are stored unencrypted. For better security we recommend using the Key management storage.
* System tables are currently not encrypted. This means that statistics data and database metadata are currently not encrypted.

* `pg_rewind` doesn't work with encrypted WAL for now.
* No upgrade path from RC to GA, There is no safe upgrade path from the previous versions, such as Release Candidate 2, to the General Availability (GA) version of `pg_tde`. We recommend starting with a **clean installation** for GA deployments. **Avoid** using RC environments in production.

[Versions and Supported PostgreSQL Deployments](supported-versions.md){.md-button}
