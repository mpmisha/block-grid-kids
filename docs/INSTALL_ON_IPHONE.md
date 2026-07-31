# Installing Block Grid on your own iPhone (no App Store)

This guide walks you through putting the game on **your** iPhone using Xcode and a
free Apple ID. Nothing is uploaded anywhere — no App Store, no TestFlight, no
developer account purchase required.

Total time: about 15 minutes the first time, ~30 seconds every time after that.

---

## 0. What you need

| Item | Notes |
| --- | --- |
| A Mac | macOS with **Xcode 16 or newer** installed (free from the Mac App Store). |
| An Apple ID | Any regular Apple ID works. No paid membership needed. |
| Your iPhone | iOS 17 or newer. |
| A USB cable | Needed for the *first* install. After that you can go wireless. |

---

## 1. Open the project

```bash
cd /path/to/block-grid-kids
open BlockGridKids.xcodeproj
```

Xcode opens with a single scheme called **BlockGridKids**.

---

## 2. Add your Apple ID to Xcode (one time)

1. Xcode menu → **Settings…** (or `⌘,`)
2. Go to the **Accounts** tab.
3. Click **+** → **Apple ID** → sign in with your Apple ID.
4. Your account appears in the list with a team named **"<Your Name> (Personal Team)"**.

That Personal Team is what lets you sign apps for free.

---

## 3. Pick your team and a unique bundle identifier

1. In the Project navigator (left sidebar), click the blue **BlockGridKids** project icon at the top.
2. Select the **BlockGridKids** target → **Signing & Capabilities** tab.
3. Tick **Automatically manage signing**.
4. **Team:** choose your `(Personal Team)`.
5. **Bundle Identifier:** change `com.blockgrid.kids` to something unique to you, e.g.

   ```
   com.misha.blockgrid
   ```

   > Bundle IDs are globally unique across all of Apple. If someone else already
   > registered `com.blockgrid.kids`, signing fails with
   > *"failed to register bundle identifier"*. Just change it to anything
   > containing your own name/domain and it will work.

6. Wait a moment — Xcode creates a provisioning profile automatically and the
   red warnings disappear.

> You can ignore the `BlockGridKidsTests` target. It is only used by `⌘U` on the
> simulator and is not installed on the phone.

---

## 4. Enable Developer Mode on the iPhone (one time)

1. Connect the iPhone to the Mac with the USB cable.
2. On the iPhone, tap **Trust This Computer** and enter your passcode.
3. On the iPhone: **Settings → Privacy & Security → Developer Mode → On**.
   - If **Developer Mode** is not in the list yet, it appears after Xcode has
     tried to install to the device once. Do step 5 first, then come back here.
4. The phone restarts. Unlock it and confirm **Turn On**.

---

## 5. Build and run onto the phone

1. In the Xcode toolbar, click the device selector (next to the scheme name) and
   choose your iPhone under **iOS Device**.
2. Press the **▶ Run** button (or `⌘R`).
3. Xcode builds, installs, and launches the app on the phone.

The first launch will most likely stop with:

> **Could not launch "Block Grid" — the application could not be verified.**

That is expected. Continue with step 6.

---

## 6. Trust the developer certificate on the iPhone (one time)

On the iPhone:

**Settings → General → VPN & Device Management → Developer App →
"Apple Development: your@email.com" → Trust → Trust**

Then tap the **Block Grid** icon on the Home Screen. It opens and plays.

---

## 7. Optional: install wirelessly from now on

In Xcode: **Window → Devices and Simulators** → select your iPhone → tick
**Connect via network**. From then on you can run `⌘R` with the phone just on the
same Wi-Fi, no cable needed.

---

## Important: the 7-day expiry with a free Apple ID

| | Free Apple ID | Paid Apple Developer Program ($99/yr) |
| --- | --- | --- |
| App keeps working for | **7 days** | 1 year |
| Apps installed at once | 3 | unlimited |
| Cost | Free | $99/year |

With a free Apple ID the signature expires after **7 days**. When it does, the
app refuses to open ("app is no longer available"). To fix it:

- Connect the phone (or use wireless), open the project, press **⌘R** again.
- It takes about 20 seconds and **your best score is preserved** — reinstalling
  over the top does not wipe the app's saved data.

If re-signing weekly gets annoying, joining the paid Apple Developer Program
raises the expiry to 1 year. That is the only difference that matters for this
use case — you still never need to publish anything.

---

## Troubleshooting

**"Failed to register bundle identifier"**
Another developer already owns that bundle ID. Change it (step 3.5) to something
unique like `com.<yourname>.blockgrid`.

**"Unable to install — device is locked"**
Unlock the iPhone and keep it unlocked while Xcode installs.

**"Untrusted Developer" every time**
You need to redo step 6 once after each *new* certificate. Xcode issues a new
certificate roughly once a year, or if you sign in with a different Apple ID.

**"The maximum number of apps for free development profiles has been reached"**
A free Apple ID allows only 3 side-loaded apps at a time. Delete an old one from
the phone.

**Xcode says the device's iOS version is unsupported**
Update Xcode to a version that supports your iPhone's iOS release.

**The app builds for the simulator but not the device**
Check that **Team** is set (step 3.4). Simulator builds do not need signing,
device builds do.

---

## Removing the app

Long-press the icon on the Home Screen → **Remove App → Delete App**. That also
deletes the saved best score. Nothing is left on the phone.

---

## Verifying it is really offline / ad-free

The app has:

- no networking code of any kind (no `URLSession`, no sockets, no web views),
- no third-party SDKs, no analytics, no ad frameworks,
- no `NSUserTrackingUsageDescription` or any privacy-sensitive permission,
- all data stored locally in `UserDefaults` (best score and two toggles).

You can confirm it yourself:

```bash
grep -rE "URLSession|WKWebView|NSURL|http://|https://" BlockGridKids/   # no results
```

Turning the iPhone to Airplane Mode has zero effect on the game.
