#!/bin/sh

# Run migrations before startup
/app/bin/centraltipsbot eval "Centraltipsbot.Release.migrate"

exec $@