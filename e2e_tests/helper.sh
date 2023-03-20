if [ -f "../.pgdbenv" ]; then
	. ../.pgdbenv
fi

check_enquo_pg_db() {
	if [ "$(psql -tAc "select count(extname) FROM pg_catalog.pg_extension WHERE extname='pg_enquo'")" != "1" ]; then
		echo "Specified PostgreSQL database does not have the pg_enquo extension." >&2
		echo "Check your PG* env vars for correctness, and install the extension if needed." >&2
		exit 1
	fi
}

clear_pg_db() {
	for tbl in $(psql -tAc "select relname from pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n on n.oid = c.relnamespace where c.relkind='r' and n.nspname = 'public'"); do
		psql -c "DROP TABLE $tbl" >/dev/null
	done
	for seq in $(psql -tAc "select relname from pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n on n.oid = c.relnamespace where c.relkind='S' and n.nspname = 'public'"); do
		psql -c "DROP SEQUENCE $seq" >/dev/null
	done
}

run_ruby() {
	ruby -r ../init "$@"
}

ar_db_migrate() {
	local target_version="$1"

	run_ruby -e "ActiveRecord::MigrationContext.new(['migrations']).up($target_version)" >/dev/null
}

load_people() {
	run_ruby -e "People.create!(JSON.parse(File.read('../people.json')))"
}
