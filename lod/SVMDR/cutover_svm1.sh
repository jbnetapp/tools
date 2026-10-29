#!/usr/bin/env bash
# SVM DR failover: svm1 (cluster1) -> svm1_dr (cluster2)
set -uo pipefail

CLUSTER1="cluster1"
CLUSTER2="cluster2"
SRC_SVM="svm1"                  # source SVM on cluster1
DST_PATH="svm1_dr:"             # SVM DR destination path (note the trailing colon)
START_SVM="svm1"                # SVM to start on cluster2 at the end (see notes)
POLL_INTERVAL=10                # seconds between status checks
TIMEOUT=3600                    # max seconds to wait for each status
SETTLE_DELAY=10                 # seconds to wait after a snapmirror command before polling

RED=$'\033[1;31m'; YEL=$'\033[1;33m'; RST=$'\033[0m'

# ---------- Warning and confirmation (before any connection) ----------
cat <<EOF

${RED}=====================================================================
 WARNING: PRODUCTION FAILOVER - THIS WILL CAUSE A SERVICE OUTAGE
=====================================================================${RST}

This script will fail over SVM ${SRC_SVM} from ${CLUSTER1} to its DR copy
(${DST_PATH}) on ${CLUSTER2}. The following operations will run in order:

  ${YEL}On ${CLUSTER2}${RST}
   1. Run:  snapmirror update -destination-path ${DST_PATH}
   2. Wait until the relationship is "Snapmirrored Idle"

  ${YEL}On ${CLUSTER1}${RST}
   3. Run:  vserver stop -vserver ${SRC_SVM}
        --> ${RED}All CIFS/NFS/iSCSI access to ${SRC_SVM} stops here.${RST}
   4. Wait until ${SRC_SVM} is "stopped"

  ${YEL}On ${CLUSTER2}${RST}
   5. Run:  snapmirror update -destination-path ${DST_PATH}   (final sync)
   6. Wait until the relationship is "Snapmirrored Idle"
   7. Run:  snapmirror quiesce -destination-path ${DST_PATH}
   8. Wait until the relationship is "Snapmirrored Quiesced"
   9. Run:  snapmirror break -destination-path ${DST_PATH}
        --> ${RED}The mirror is broken; the destination becomes read-write.${RST}
  10. Wait until the relationship is "Broken-off Idle"
  11. Run:  vserver start -vserver ${START_SVM}
        --> The DR SVM starts serving data.

Consequences:
  - ${SRC_SVM} on ${CLUSTER1} stays stopped. Clients must be redirected
    (DNS, LIFs, mount points) to the DR SVM on ${CLUSTER2}.
  - Failing back requires a resync (snapmirror resync) in the reverse direction.
  - The script stops at the first error. A partial run can leave ${SRC_SVM}
    stopped or the relationship quiesced, which then needs manual recovery.
  - Make sure applications are quiesced and users have been notified.

EOF

read -r -p "Type YES (in capital letters) to continue, anything else cancels: " ans
if [[ "$ans" != "YES" ]]; then
    echo "Cancelled. No connection was made and nothing was changed."
    exit 0
fi

# ---------- Password prompt (hidden input) ----------
read -r -s -p "ONTAP admin password (cluster1 and cluster2): " PASSWD
echo
[[ -n "$PASSWD" ]] || { echo "Empty password, aborting."; exit 1; }
trap 'unset PASSWD' EXIT

log()  { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }
fail() { log "ERROR: $*"; exit 1; }

# ---------- Run an ONTAP CLI command over SSH ----------
# usage: ontap <cluster> <command...>
ontap() {
    local cluster="$1"; shift
    sshpass -p "$PASSWD" ssh \
        -o StrictHostKeyChecking=accept-new \
        -o ConnectTimeout=15 \
        -l admin "$cluster" "$*"
}

# Run a command, print its output, stop on failure
# usage: run <cluster> <command...>
run() {
    local cluster="$1"; shift
    local out rc
    log "[$cluster] $*"
    out=$(ontap "$cluster" "$@" 2>&1); rc=$?
    [[ -n "$out" ]] && printf '%s\n' "$out"
    if [[ $rc -ne 0 ]] || grep -qE '^\s*Error:' <<<"$out"; then
        fail "Command failed on $cluster: $*"
    fi
}

# Poll until the last N columns of the last output line match the expected text
# usage: wait_for <cluster> "<show command>" "<expected text, lowercase>" "<description>"
wait_for() {
    local cluster="$1" cmd="$2" expected="$3" desc="$4"
    local n out last started=$SECONDS
    n=$(wc -w <<<"$expected")
    log "[$cluster] Waiting for: $desc (expected: $expected)"
    while true; do
        out=$(ontap "$cluster" "$cmd" 2>&1) || fail "Cannot run '$cmd' on $cluster"
        last=$(printf '%s\n' "$out" \
            | grep -vE 'entr(y|ies) (was|were) displayed' \
            | awk 'NF' | tail -n1 \
            | awk -v n="$n" '{s=""; for(i=NF-n+1;i<=NF;i++){s=s (i>NF-n+1?" ":"") tolower($i)}; print s}')
        if [[ "$last" == "$expected" ]]; then
            log "[$cluster] Reached: $expected"
            return 0
        fi
        (( SECONDS - started > TIMEOUT )) && fail "Timeout after ${TIMEOUT}s waiting for '$expected' (last seen: '$last')"
        log "[$cluster]   current: '${last:-no data}' ... retry in ${POLL_INTERVAL}s"
        sleep "$POLL_INTERVAL"
    done
}

SM_SHOW="snapmirror show -destination-path $DST_PATH -fields state,status"
SV_SHOW="vserver show -vserver $SRC_SVM -fields operational-state"

# 1. cluster2: update
run "$CLUSTER2" snapmirror update -destination-path "$DST_PATH"
sleep "$SETTLE_DELAY"
# 2. cluster2: wait for Snapmirrored Idle
wait_for "$CLUSTER2" "$SM_SHOW" "snapmirrored idle" "SnapMirror Snapmirrored/Idle after first update"

# 3. cluster1: stop the source SVM
run "$CLUSTER1" vserver stop -vserver "$SRC_SVM"
# 4. cluster1: wait for stopped
wait_for "$CLUSTER1" "$SV_SHOW" "stopped" "SVM $SRC_SVM stopped"

# 5. cluster2: final update
run "$CLUSTER2" snapmirror update -destination-path "$DST_PATH"
sleep "$SETTLE_DELAY"
# 6. cluster2: wait for Snapmirrored Idle
wait_for "$CLUSTER2" "$SM_SHOW" "snapmirrored idle" "SnapMirror Snapmirrored/Idle after final update"

# 7. cluster2: quiesce
run "$CLUSTER2" snapmirror quiesce -destination-path "$DST_PATH"
# 8. cluster2: wait for Snapmirrored Quiesced
wait_for "$CLUSTER2" "$SM_SHOW" "snapmirrored quiesced" "SnapMirror Snapmirrored/Quiesced"

# 9. cluster2: break
run "$CLUSTER2" snapmirror break -destination-path "$DST_PATH"
# 10. cluster2: wait for Broken-off Idle
wait_for "$CLUSTER2" "$SM_SHOW" "broken-off idle" "SnapMirror Broken-off/Idle"

# 11. cluster2: start the SVM
run "$CLUSTER2" vserver start -vserver "$START_SVM"

log "Done."
