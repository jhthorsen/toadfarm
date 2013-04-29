#!/bin/sh
echo "HYPNOTOAD_PID=$HYPNOTOAD_PID" > t/bin/restarter.log
echo "HYPNOTOAD_REV=$HYPNOTOAD_REV" >> t/bin/restarter.log
echo $@ >> t/bin/restarter.log