# Install Healthify on your iPhone from Windows

Build with [xtool](https://github.com/xtool-org/xtool), install with xtool or
[iloader](https://iloader.app/). No Mac, no paid Apple Developer Program needed —
a free Apple ID works.

## What you need

- Windows 10/11 with WSL2
- iPhone running iOS 17+ (the package targets iOS 17) + USB cable
- A free Apple ID (use a throwaway for password login — see step 3)
- iTunes for Windows (only needed for the iloader path)

## 1. WSL + Swift (mostly done)

```powershell
wsl --install
```

Inside WSL (Ubuntu), Swift 6.4+ is required. This machine already has Swift 6.4.2
via `swiftly` — verify with `wsl swift --version`. Then install the device tools
(you'll type your WSL password):

```bash
sudo apt-get install usbmuxd libimobiledevice-utils
```

## 2. Connect the iPhone to WSL

On Windows, install [usbipd](https://learn.microsoft.com/en-us/windows/wsl/connect-usb),
then bind and attach the phone:

```powershell
usbipd list
usbipd bind --busid <your-phone-busid>
usbipd attach --wsl --busid <your-phone-busid>
```

Verify inside WSL:

```bash
ideviceinfo   # prints your iPhone's name, serial, UDID
```

If you hit `AFCClient.Error.muxError`, use the relay-via-iTunes workaround in
[this xtool issue comment](https://github.com/xtool-org/xtool/issues/19#issuecomment-2898986718).

## 3. Install xtool and log in

```bash
curl -fL "https://github.com/xtool-org/xtool/releases/latest/download/xtool-$(uname -m).AppImage" -o xtool
chmod +x xtool
sudo mv xtool /usr/local/bin/
xtool setup
```

Login choices: **API Key** (paid Developer Program only) or **Password**
(any free Apple ID, uses private Apple APIs — xtool sends credentials only to
Apple; a throwaway Apple ID is fine).

Then download **Xcode 27.1** (`Xcode.xip`) from
<https://developer.apple.com/download/all/?q=Xcode> in your browser (Apple ID
login required) and give `xtool setup` the file path. xtool extracts it into an
iOS Swift SDK. Confirm with:

```bash
swift sdk list   # darwin
```

## 4. Path A — direct install with xtool (recommended)

```bash
cd "/mnt/d/Iphone App dev/Healthify"
xtool dev
```

What happens: first build takes minutes (iOS SDK modules compile once, then
cache). xtool waits for the phone — plug it in, tap **Trust** + enter passcode
on iOS, and re-run `xtool dev` if it errors right after trusting. xtool then
registers your device, generates a Certificate + App ID + Provisioning Profile,
signs, and installs.

On the iPhone, two one-time approvals:

1. **Developer Mode**: Settings → Privacy & Security → Developer Mode → on
   (restarts the phone).
2. **Trust the cert**: Settings → General → VPN & Device Management → trust
   your Apple ID certificate.

Notes: with a free Apple ID, xtool prefixes the bundle ID
(`XTL-1234.com.healthify.app`) so it can't collide with anyone else's — normal.
HealthKit read-only works fine on free provisioning. Re-running `xtool dev`
later rebuilds and reinstalls in seconds.

## 5. Path B — build with xtool, install with iloader

Use this if USB passthrough to WSL misbehaves. Build only:

```bash
xtool dev build
```

The signed bundle lands at `./xtool/Healthify.app`. Zip it into an IPA
(`Payload/Healthify.app` at the zip root, rename to `.ipa`). Then on Windows:

1. Install [iTunes](https://apple.co/ms) (required driver source).
2. Install iloader **only** from [iloader.app](https://iloader.app/) or its
   [GitHub releases](https://github.com/nab138/iloader/releases/latest).
3. Let iloader set up SideStore (or LiveContainer + SideStore), then install
   your IPA with your free Apple ID — USB or wireless.

Free Apple ID signatures expire after 7 days (Apple's rule, not iloader's);
SideStore refreshes them — see the
[SideStore guide](https://docs.sidestore.io/docs/installation/prerequisites).
Rebuild the IPA with `xtool dev build` whenever the app changes.

## 6. First launch checklist

1. Open Healthify → finish onboarding (goals are computed on-device).
2. Settings → Apple Health → Connect Apple Health → allow Weight, Body Fat,
   Nutrition, Workouts → Sync now.
3. Scale: in HealthU+, enable its Apple Health sync (Weight, Body Fat %,
   Lean Mass, BMI), step on the scale, then Sync now in Healthify.
4. Settings → Export backup file, and keep the file somewhere safe — with
   free provisioning the app can need reinstalling, and only an exported
   backup restores your data.
