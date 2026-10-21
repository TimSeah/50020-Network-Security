# Task 5: AI-assisted web attack detection

`web_attack_detector.py` follows the Campus Service Apache access log and prints
alerts for common SQL injection and XSS request indicators, requests to the
harmless XSS execution marker, and calls to the lab's state-changing
`request_action.php` endpoint using GET.

This is a small, explainable detection aid for this lab. It reports indicators,
not proof that an attack succeeded. Apache access logs normally record the URL,
method, status, referrer, and user-agent, but not POST bodies. As a result, this
monitor cannot inspect the stored-XSS profile form submission itself. The
`/__xss_probe__` beacon is a safe local request used to show when the stored
payload executes in the lab browser; it does not send data outside the lab.

## Run it in Kali

1. Copy `web_attack_detector.py` from this folder into Kali. A VirtualBox shared
   folder or drag-and-drop is fine. Save it somewhere easy to reach, such as
   `~/Desktop/`.
2. Start the Campus Service lab in Kali and make sure the portal is working.
3. Open a Kali terminal and check the script and log are present:

   ```bash
   ls -l ~/Desktop/web_attack_detector.py
   sudo ls -l /var/log/apache2/campus-portal-access.log
   ```

4. Start the detector. It begins at the end of the current log and watches new
   requests, so start it before repeating the lab activities:

   ```bash
   cd ~/Desktop
   sudo python3 web_attack_detector.py --log /var/log/apache2/campus-portal-access.log
   ```

   Leave this terminal open. Use `Ctrl+C` to stop monitoring.

5. If the second command says the log does not exist, find the lab's Apache
   access log:

   ```bash
   sudo find /var/log/apache2 -maxdepth 1 -type f -iname '*access*.log' -print
   ```

   Use the path returned by that command after `--log`. The script also waits
   for a log file to appear if Apache has not created it yet.

## Demonstrate and capture evidence

Keep the detector running in one terminal. Use the lab portal in Firefox on the
same Kali VM and repeat each benign, lab-only demonstration. Capture a screenshot
of the relevant browser result together with the detector alert in the terminal.

1. **SQL injection indicator:** sign in as Alice (`alice` / `alice`) and paste
   this URL into Firefox:

   ```text
   http://portal.campus.test/tickets.php?q=%27%20OR%201%3D1%20--%20
   ```

   The terminal should label the GET request `SQLi indicator`. The login form
   submits by POST, so its SQL payload would not appear in the access log.
2. **Reflected XSS indicator:** while still signed in as Alice, paste this URL:

   ```text
   http://portal.campus.test/knowledge.php?q=%3Cscript%3Ealert%28%27XSS%27%29%3C%2Fscript%3E
   ```

   The browser should show an alert and the terminal should report
   `XSS indicator`.
3. **Stored XSS execution marker:** while signed in as Alice, set the profile's
   About me text to this harmless lab marker and save it:

   ```html
   <script>fetch('/__xss_probe__?type=stored')</script>
   ```

   Saving redirects to Alice's profile page, where the payload executes. For a
   clearer demonstration, sign out, sign in as Bob (`bob` / `bob`), and open
   `http://portal.campus.test/profile.php?u=alice`. The browser makes a
   same-site request to the marker path, and the terminal should report
   `XSS execution beacon`. The marker endpoint may return 404; the logged
   request is the evidence that the script ran. Later, sign in as Alice and
   restore her original profile text.
4. **CSRF risk:** sign out, then sign in as admin. The Task 1 screenshots show
   that the admin password was changed to `abc`; after a database reset, the
   seed password is `admin`. Confirm an access request is still Pending.
   Open `http://docs.campus.test:8082/` in another tab in the *same Firefox
   profile*, and publish a document containing this HTML. AR-302 was Pending
   in the earlier lab screenshots; change its ID if it is no longer Pending.

   ```html
   <!doctype html>
   <html><body>
   <h1>Service handover note</h1>
   <p>Please review this document.</p>
   <img src="http://portal.campus.test/request_action.php?id=302&amp;decision=approve"
        alt="" width="1" height="1" style="opacity:0">
   </body></html>
   ```

   Open the published document. Its image request should trigger a `CSRF risk`
   alert for the GET to `request_action.php`; the document host may also be
   identified from its referrer. Confirm the request changed to Approved in the
   portal. Use the portal hostname for login, not the Kali VM's IP address, so
   the browser sends the correct login cookie to the portal.

## What to explain in the report

The detector uses readable pattern rules over decoded URL paths and query
strings, plus a rule for a GET to the lab's approval/decision endpoint. It is
lightweight and produces real-time, human-readable alerts, but signatures can
miss obfuscated or novel attacks and can also flag benign requests. Access-log
inspection cannot see a payload submitted only in a POST body. The stored-XSS
beacon is a targeted demonstration aid, not general stored-XSS detection. A
CSRF alert means a risky endpoint was called; it does not by itself prove the
request was forged or that the state change succeeded.
