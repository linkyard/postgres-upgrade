# postgres-upgrade

Automate the process of upgrading a PostgreSQL database to a specified target **major** version using [pg_upgrade](https://www.postgresql.org/docs/current/pgupgrade.html) utility. The script ensures that the database is backed up, the new version is initialized with the correct settings, and the data is migrated seamlessly.

## Features
- Automatically backup the current PostgreSQL data directory.
- Verify compatibility between current and target PostgreSQL versions.
- Initialize a new PostgreSQL database cluster with appropriate locale and encoding settings.
- Upgrade the PostgreSQL database using `pg_upgrade`.
- Clean up old backups older than a week.

## Prerequisites
- Bash shell
- Rsync
- PostgreSQL binaries for current and target versions

## Environment Variables
- `PSQL_VERSION`: Target PostgreSQL version (required)
- `SUPPORTED_POSTGRES_VERSIONS`: Space-separated list of supported PostgreSQL versions (required)
- `DATA_DIR`: Original Directory containing PostgreSQL data (default: `/data/postgresql`)
- `BINARIES_DIR`: Directory containing PostgreSQL binaries (default: `/usr/lib/postgresql`)
- `BACKUP_DIR`: Directory containing backup of the data
