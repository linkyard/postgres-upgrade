#!/bin/bash
set -euo pipefail 

target_version="${PSQL_VERSION:?ERROR: Target PostgreSQL version not set. Set the PSQL_VERSION environment variable.}"
data_dir="/data/postgresql"
binaries_dir="/usr/lib/postgresql"
backup_dir="/data/backup"

# Get supported PostgreSQL versions from the environment variable
supported_versions="$SUPPORTED_POSTGRES_VERSIONS"
IFS=" " read -ra supported_versions_array <<< "$supported_versions"

# Check if the backup is older than a week and delete if so
if [ -d "$backup_dir/postgresql" ]; then
  find "$backup_dir" -type d -mtime +7 -name 'postgresql' -exec echo "Deleting old backup: {}" \; -exec rm -rf {} +
fi 

# Verify that the target version is set
if [ -z "$target_version" ]; then
  echo "ERROR: Target PostgreSQL version is not set. Please set the PSQL_VERSION environment variable."
  exit 1
fi

# Check if PG_VERSION file exists otherwise exit.
if [ -f "$data_dir/PG_VERSION" ]; then
  current_version=$(cat "$data_dir/PG_VERSION" | cut -d '.' -f 1)
  echo "current major postgres version is: $current_version."
else
  echo "The 'PG_VERSION' file was not found in '$data_dir'. Skipping to database initialization."
  exit 0
fi

if [ "$current_version" == "$target_version" ]; then
  echo "Already at target version, exiting"
  exit 0
elif [ "$current_version" -lt "$target_version" ]; then
  if [ "$current_version" -lt 10 ]; then
    current_version=9.6
  fi
  if [ "$target_version" -lt 10 ]; then
    target_version=9.6
  fi  
else
  echo "ERROR: Downgrading is not supported at the moment."
  exit 1
fi   

# Check if the target version is in the list of allowed versions
if [[ ! " ${supported_versions_array[@]} " =~ " ${target_version} " ]]; then
  echo "ERROR: Target PostgreSQL version '$target_version' is not supported at the moment.\nSupported versions are: ${supported_versions[*]}."
  exit 1
fi

if [ ! -d "$backup_dir" ]; then
  mkdir -p "$backup_dir"
fi  

# Backup the data dir
echo "Creating a backup of the data directory."
rsync -a --delete "$data_dir/" "$backup_dir/postgresql-$current_version/" 

exit_status=$?
if [ $exit_status -ne 0 ]; then
  echo "ERROR: rsync failed with exit code $exit_status. Make sure destination directory has sufficient space."
  exit 1
fi


# prepare for upgrade
echo "Preparing upgrade from current PostgreSQL version $current_version to the desired version $target_version."

# set necessary permissions on data dir for user postgres
chmod 0700 $data_dir

# Start the old PostgreSQL server
echo "Starting the old PostgreSQL server."
$binaries_dir/$current_version/bin/pg_ctl start -w -D "$data_dir"

# Gather locale and encoding settings
psql=$binaries_dir/$current_version/bin/psql
lc_collate=$($psql -c "SHOW LC_COLLATE;" | awk 'NR==3' | xargs)
lc_ctype=$($psql -c "SHOW LC_CTYPE;" | awk 'NR==3' | xargs)
encoding=$($psql -c "SHOW server_encoding;" | awk 'NR==3' | xargs)
echo "Locale and encoding settings: $lc_collate, $lc_ctype, $encoding."

# Stop the old PostgreSQL server
echo "Stopping the old PostgreSQL server."
$binaries_dir/$current_version/bin/pg_ctl stop -w -D "$data_dir"

### This is only reached if the async command works and we have a backup ###
rm -rf $data_dir 

echo "Starting PostgreSQL Upgrade Process ..."

# Initialize a new database cluster
echo "Initializing a new database cluster."
$binaries_dir/$target_version/bin/initdb --encoding=UTF8 --lc-collate=en_US.utf8 --lc-ctype=en_US.utf8 -D "$data_dir"

# Start the new PostgreSQL server
echo "Starting the new PostgreSQL server."
$binaries_dir/$target_version/bin/pg_ctl start -w -D "$data_dir"

# Replace the postgres database
echo "Creating a new postgres database with Locale and encoding settings identical to old cluster db."
$binaries_dir/$target_version/bin/psql -h localhost -U postgres -d template1 -c "DROP DATABASE IF EXISTS postgres;"

$binaries_dir/$target_version/bin/psql -h localhost -U postgres -d template1 -c "CREATE DATABASE postgres WITH ENCODING '$encoding' \
                                                                                LC_COLLATE='$lc_collate' LC_CTYPE='$lc_ctype' TEMPLATE template0 OWNER postgres;"
$binaries_dir/$target_version/bin/psql -h localhost -U postgres -d postgres -c "GRANT TEMPORARY, CONNECT ON DATABASE postgres TO PUBLIC;"

$binaries_dir/$target_version/bin/psql -h localhost -U postgres -d postgres -c "GRANT CREATE, TEMPORARY, CONNECT ON DATABASE postgres TO postgres;"

# Stop the new PostgreSQL server
echo "Stopping the new PostgreSQL server."
$binaries_dir/$target_version/bin/pg_ctl stop -D "$data_dir"

# set necessary permissions on backup dir, otherwise pg_upgrade throws an error.
chmod 0700 $backup_dir/postgresql-$current_version

# Run pg_upgrade
$binaries_dir/$target_version/bin/pg_upgrade \
    -b "$binaries_dir/$current_version/bin" \
    -B "$binaries_dir/$target_version/bin" \
    -d "$backup_dir/postgresql-$current_version" \
    -D "$data_dir"


# Check if the upgrade succeeded
if [ $? -ne 0 ]; then
  echo "Upgrade failed. Check logs for details."
  exit 1
fi

# perform post upgrade steps
cp $backup_dir/postgresql-$current_version/postgresql.conf $data_dir
echo "upgrade completed successfully."
exit 0
