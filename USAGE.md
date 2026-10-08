# Usage & Configuration Guide

This guide explains how to configure, deploy, and run the Call Pinging Automator (`autocall.sh`) on your Android device.

## Prerequisites & Setup

1. **Root Access:** Your device must be rooted (e.g., via Magisk or LineageOS root addons).
2. **ADB Debugging:** Enable Developer Options on your phone, then turn on **USB Debugging** (and **Rooted Debugging** if available).
3. **No Lock Screen:** Ensure your phone does **not** have a lock screen (PIN, Password, or Pattern) enabled. Go to Settings > Security > Screen lock and set it to **None** or **Swipe**. The script attempts to wake the screen (`input keyevent 224`), but a secure lock screen may block the dialer from opening properly.

---

## Configuration Variables (Fine-Tuning)

You can modify the variables at the top of `autocall.sh` to customize the script's behavior. Open the script in a text editor and adjust the following:

### Target & Retries
*   `TARGET_NUMBER` (e.g., `"9712345678"`): The phone number the script will dial.
*   `MAX_RETRIES` (e.g., `3`): The maximum number of attempts to try if a call fails, drops, or is busy before giving up for the current hour.

### Time Window
*   `ACTIVE_START_HOUR` (e.g., `23`) and `ACTIVE_END_HOUR` (e.g., `5`): The active time window in 24-hour format (0-23). The script automatically calculates sleep durations to perfectly skip the inactive/resting period, and it supports cross-midnight schedules.

### Call Duration & Timeouts
*   `RING_MIN_SEC` / `RING_MAX_SEC` (e.g., `8` to `15`): Determines how long to let the target's phone ring *after* the connection is successfully established. A random duration between min and max is chosen for each call to simulate human behavior.
*   `ANSWER_WAIT_SEC` (e.g., `2`): If the target unexpectedly picks up the phone, the script will wait this many seconds before abruptly hanging up.
*   `CALL_TIMEOUT_SEC` (e.g., `35`): Safety timeout. If the call never connects or gets stuck in the dialing phase, it aborts after this duration.

### Hourly Randomization (Jitter)
*   `HOURLY_JITTER_MIN` / `HOURLY_JITTER_MAX` (e.g., `60` to `480`): The delay (in seconds) added to the start of the next hour's cycle. This prevents the calls from happening at the exact same minute every hour.

### Retry Randomization (Jitter)
*   `RETRY_MIN_SEC` / `RETRY_MAX_SEC` (e.g., `60` to `180`): Determines the wait time before attempting a retry after a call fails. A random wait time between these bounds is chosen to avoid predictable retry intervals.

### Logging
*   `LOG_DIR` (e.g., `"/sdcard/Documents"`): The directory where logs are saved. Placing it here makes it accessible via the Android file manager without root access.
*   `LOG_FILE` (e.g., `"$LOG_DIR/autocall.log"`): The exact file path for the output log.

---

## Deployment & Execution

1. **Connect your device** to your computer via USB and verify ADB connection:
   ```bash
   adb devices
   ```

2. **Push the script** to your device's temporary folder:
   ```bash
   adb push autocall.sh /data/local/tmp/
   ```

3. **Enter the adb shell & gain root privileges:**
   ```bash
   adb shell
   su
   ```
   *(Note: You may need to grant Superuser access on your phone's screen when you type `su`.)*

4. **Make the script executable:**
   ```bash
   chmod +x /data/local/tmp/autocall.sh
   ```

5. **Run the script:**
   To run the script in the background so it survives when you disconnect the USB cable, use `nohup`:
   ```bash
   nohup sh /data/local/tmp/autocall.sh > /dev/null 2>&1 &
   ```
   
To stop the script at any time, you can find its Process ID (PID) and kill it:
```bash
adb shell
su
ps | grep autocall.sh
kill <PID>
```
