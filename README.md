# Call Pinging Automator

**Objective:** 
Automate the process of placing an hourly "missed call" from a specific Android device to a target number, ensuring accurate detection of the call state to trigger appropriate retry logic.

## Environment & Constraints
*   **OS:** Android 7.1.2 (Nougat) / Custom ROM: LineageOS 14.1.
*   **Privileges:** Root-level
*   **Shell:** `adb shell`
*   **Execution Frequency:** Hourly (configurable with randomization/jitter).

## Core Functional Requirements
1.  **Call Initiation:** The system automatically dials a target phone number on a scheduled hourly basis.
2.  **Connection Verification:** Verifies that the call successfully reaches the target network (alerting/ringing state).
3.  **State Detection & Handling:**
    *   **Ringing:** If the call rings successfully for a predefined number of seconds, it hangs up to register as a missed call.
    *   **Answered:** If the call is unexpectedly answered, it terminates the call immediately.
    *   **Busy / Unreachable:** If the line is busy, unreachable, or fails to connect, it initiates a retry protocol.
4.  **Active/Resting Hours:** Operates only during specified hours to save battery and avoid calling at the wrong times.

---

## Background Study & Radio Logs
Detecting the exact state of a phone call using purely shell scripts on Android requires analyzing the device's radio buffer. By utilizing `logcat -b radio -v time`, the script intercepts low-level cellular events. 

The `logs/` directory contains sample dumps of these radio events used to design the state machine:
*   `successful_ring_unanswered.log`: Demonstrates a call placed successfully and received on the recipient phone, but left unanswered. This log was crucial for identifying the `[id=1,ALERTING]` state flag.
*   `ringed_then_rejected.log`: Shows the sequence when a call is rejected from the recipient side after a few seconds of ringing.
*   `ringed_then_answered.log`: Shows the call being answered. The script watches for the transition to the `[id=1,ACTIVE]` state flag to immediately hang up.
*   `unreachable_or_invalid_num.log`: A test where the recipient phone was placed in airplane mode to simulate an unreachable status.
*   `busy.log`: A test where the recipient was already on another call, simulating a busy line. The script looks for `EVENT_VOICE_CALL_ENDED` or `onDisconnect:` in these failure scenarios.

By clearing the logcat buffer (`logcat -c -b radio`) immediately before dialing and constantly polling it, the automation script dynamically responds to the network state without needing a dedicated Android app.

---

**Next Steps:**
Please see [USAGE.md](USAGE.md) for detailed instructions on configuring the script variables and deploying it to your Android device via `adb`.