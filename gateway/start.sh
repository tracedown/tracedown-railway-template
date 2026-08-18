#!/bin/sh
# Migrate → ensure the CA → serve. The migrator is the dedicated Flyway runner
# from the release (single flyway_schema_history); running it here, before the
# gateway binds, gives the ordering Docker Compose expresses with
# service_completed_successfully and Railway cannot.
set -e

/tracedown/schema-migrator/bin/schema-migrator

# The probe-scheduler needs the internal CA at startup to mint its client
# certificate, and the gateway only creates the CA lazily. Forcing a bootstrap
# token creation materializes it (the same trick the dev stack's ca-init
# service uses). Token creation supersedes any outstanding token for the slug,
# so this leaves at most one short-lived unused row behind.
java -jar /tracedown/app.jar --agent-bootstrap railway-ca-init > /dev/null

exec java -jar /tracedown/app.jar
