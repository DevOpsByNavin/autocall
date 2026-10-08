#!/system/bin/sh

TARGET_NUMBER="9712345678"
MAX_RETRIES=3

LOG_DIR="/sdcard/Documents"
LOG_FILE="$LOG_DIR/autocall.log"

# ACTIVE TIME WINDOW (24-Hour Format 0-23)
ACTIVE_START_HOUR=23
ACTIVE_END_HOUR=5

# RINGING TIMERS (in seconds)
RING_MIN_SEC=8
RING_MAX_SEC=15

# TIMEOUTS
ANSWER_WAIT_SEC=2
CALL_TIMEOUT_SEC=35

# JITTER CONFIGURATIONS (in seconds)
HOURLY_JITTER_MIN=60
HOURLY_JITTER_MAX=480

RETRY_MIN_SEC=60
RETRY_MAX_SEC=180

# INITIALIZATION & LOGGING SETUP
mkdir -p "$LOG_DIR"
exec >> $LOG_FILE 2>&1

log_msg() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') | $1"
}

get_random() {
    echo $(( (RANDOM % ($2 - $1 + 1)) + $1 ))
}

get_future_time() {
    local add_seconds=$1
    local h=$((10#$(date +%H)))
    local m=$((10#$(date +%M)))
    local s=$((10#$(date +%S)))

    s=$((s + add_seconds))
    m=$((m + (s / 60)))
    s=$((s % 60))
    h=$((h + (m / 60)))
    m=$((m % 60))
    h=$((h % 24))

    printf "%02d:%02d:%02d\n" "$h" "$m" "$s"
}

# ==============================================================================
# ADVANCE TIME SCHEDULING LOGIC
# ==============================================================================
# Helper to check if a specific hour falls into the "Resting/Inactive" period
is_resting_hour() {
    local h=$1
    if [ $ACTIVE_START_HOUR -gt $ACTIVE_END_HOUR ]; then
        # Window crosses midnight (e.g., Active 23 to 5. Resting is 6 to 22)
        if [ $h -gt $ACTIVE_END_HOUR ] && [ $h -lt $ACTIVE_START_HOUR ]; then return 0; else return 1; fi
    else
        # Window is same day (e.g., Active 9 to 17. Resting is < 9 or > 17)
        if [ $h -lt $ACTIVE_START_HOUR ] || [ $h -gt $ACTIVE_END_HOUR ]; then return 0; else return 1; fi
    fi
}

# Calculate exact sleep time for the NEXT hour's cycle
calc_next_cycle_wait() {
    local c_hour=$((10#$(date +%H)))
    local c_min=$((10#$(date +%M)))
    local c_sec=$((10#$(date +%S)))

    local secs_to_next_hour=$(( 3600 - (c_min * 60) - c_sec ))
    local next_hour=$(( (c_hour + 1) % 24 ))

    local extra_hours=0
    local temp_hour=$next_hour

    # Fast-forward through resting hours if necessary
    while is_resting_hour $temp_hour; do
        extra_hours=$((extra_hours + 1))
        temp_hour=$(( (temp_hour + 1) % 24 ))
    done

    local jitter=$(get_random $HOURLY_JITTER_MIN $HOURLY_JITTER_MAX)
    echo $(( secs_to_next_hour + (extra_hours * 3600) + jitter ))
}

# Calculate initial sleep time if script is started in the middle of a cycle
calc_initial_wait() {
    local c_hour=$((10#$(date +%H)))
    local c_min=$((10#$(date +%M)))
    local c_sec=$((10#$(date +%S)))

    local extra_hours=0
    local temp_hour=$c_hour
    local secs_to_add=0

    if is_resting_hour $temp_hour; then
        secs_to_add=$(( 3600 - (c_min * 60) - c_sec ))
        temp_hour=$(( (temp_hour + 1) % 24 ))

        while is_resting_hour $temp_hour; do
            extra_hours=$((extra_hours + 1))
            temp_hour=$(( (temp_hour + 1) % 24 ))
        done
    fi

    local jitter=$(get_random $HOURLY_JITTER_MIN $HOURLY_JITTER_MAX)
    echo $(( secs_to_add + (extra_hours * 3600) + jitter ))
}

# ==============================================================================
# MAIN SCRIPT
# ==============================================================================
echo "autocall_lock" > /sys/power/wake_lock

log_msg "=========================================================="
log_msg "Starting Auto-Call Script V4. Target: $TARGET_NUMBER"

# Calculate the very first wait time (handles starting outside active hours)
initial_wait=$(calc_initial_wait)
log_msg "Started. First call scheduled for $(get_future_time $initial_wait)."
log_msg "=========================================================="
sleep $initial_wait

while true; do
    attempts=0
    success=0

    while [ $attempts -lt $MAX_RETRIES ]; do
        logcat -c -b radio
        input keyevent 224 # Wake screen
        am start -a android.intent.action.CALL -d tel:$TARGET_NUMBER > /dev/null 2>&1

        start_time=$(date +%s)
        alerting_start=0
        target_ring_time=$(get_random $RING_MIN_SEC $RING_MAX_SEC)

        # Polling Loop
        while true; do
            current_time=$(date +%s)
            elapsed=$((current_time - start_time))

            if [ $elapsed -ge $CALL_TIMEOUT_SEC ]; then
                log_msg "Call timed out. Disconnected."
                input keyevent 6
                success=0
                break
            fi

            recent_logs=$(logcat -d -b radio)

            # Answered
            if echo "$recent_logs" | grep -q "\[id=1,ACTIVE"; then
                log_msg "Call answered. Disconnected."
                sleep $ANSWER_WAIT_SEC
                input keyevent 6
                success=1
                break
            fi

            # Dropped / Connection Issue
            if echo "$recent_logs" | grep -q "EVENT_VOICE_CALL_ENDED" || echo "$recent_logs" | grep -q "onDisconnect:"; then
                log_msg "Busy/Connection issue. Call dropped."
                success=0
                break
            fi

            # Record when it starts alerting
            if [ $alerting_start -eq 0 ] && echo "$recent_logs" | grep -q "\[id=1,ALERTING"; then
                alerting_start=$(date +%s)
            fi

            # Check if missed call target time was met
            if [ $alerting_start -gt 0 ]; then
                if [ $((current_time - alerting_start)) -ge $target_ring_time ]; then
                    log_msg "Missed call left successfully."
                    input keyevent 6
                    success=1
                    break
                fi
            fi

            sleep 1
        done

        if [ $success -eq 1 ]; then
            break
        fi

        attempts=$((attempts + 1))
        if [ $attempts -lt $MAX_RETRIES ]; then
            retry_wait=$(get_random $RETRY_MIN_SEC $RETRY_MAX_SEC)
            log_msg "Failed. Trying again in $retry_wait seconds (at $(get_future_time $retry_wait))."
            sleep $retry_wait
        else
            log_msg "Failed after $MAX_RETRIES attempts."
        fi
    done

    # Calculate the precise start time for the next hour's cycle
    next_wait=$(calc_next_cycle_wait)
    log_msg "Next call scheduled for $(get_future_time $next_wait)."
    sleep $next_wait

done
