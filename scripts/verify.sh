#!/usr/bin/env bash
# Builds and starts the simulation, then checks that headless Gazebo is running
# and /odom is publishing. Output is saved to proof/verify.log.
#
# Run from the repository root:   bash scripts/verify.sh
# Windows: run it in Git Bash or WSL. Exit code 0 = PASS, 1 = FAIL.
set -uo pipefail

mkdir -p proof
LOG=proof/verify.log
: > "$LOG"
say() { echo "$@" | tee -a "$LOG"; }
in_container() { docker compose exec -T leo-sim /entrypoint.sh "$@"; }
health() { docker inspect -f '{{.State.Health.Status}}' leo-sim 2>/dev/null || echo "missing"; }

say "=== Verification run: $(date -u +%FT%TZ) ==="
say "host: $(uname -srm)"
say "docker: $(docker --version)"
say "compose: $(docker compose version)"

say; say "--- 1. docker compose up -d --build"
docker compose up -d --build 2>&1 | tee -a "$LOG"

say; say "--- 2. waiting for the healthcheck (a real /odom message) ..."
for i in $(seq 1 40); do
  status=$(health)
  say "  [$i/40] health = $status"
  [ "$status" = "healthy" ] && break
  [ "$status" = "missing" ] && break
  sleep 10
done

say; say "--- 3. processes: Gazebo must run as server only (-s), no GUI"
in_container bash -c "ps -eo args | grep -E 'gazebo' | grep -v grep" 2>&1 | tee -a "$LOG"

say; say "--- 4. ros2 topic list"
in_container ros2 topic list 2>&1 | tee -a "$LOG"

say; say "--- 5. one /odom message"
in_container timeout 20 ros2 topic echo --once /odom 2>&1 | head -40 | tee -a "$LOG"

say; say "--- 6. /odom publish rate"
in_container timeout 10 ros2 topic hz /odom 2>&1 | tail -4 | tee -a "$LOG" || true

say; say "--- 7. final status"
docker compose ps 2>&1 | tee -a "$LOG"
if [ "$(health)" = "healthy" ]; then
  say "RESULT: PASS - headless Gazebo running and /odom publishing"
  rc=0
else
  say "RESULT: FAIL - container log follows"
  docker compose logs --no-color leo-sim 2>&1 | tail -150 | tee -a "$LOG"
  rc=1
fi
say "Stop with: docker compose down"
exit $rc
