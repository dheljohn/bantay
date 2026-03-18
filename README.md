# 🛡️ Bantay

**Bantay** (Filipino for *"guardian"* or *"watchful"*) is a personal safety monitoring app built with Flutter. It runs silently in the background, tracks your location along your defined safe routes, and automatically alerts your trusted contacts if something seems wrong — all with offline GPS support.

---

## Features

### 🗺️ Safe Route Management
- Define your everyday routes (e.g., home → school, home → work)
- Set these as your **Safe Routes** — the basis for normal, expected movement
- Routes are cached using an **OpenStreetMap (OSM)** provider for offline use
- <img src="https://github.com/user-attachments/assets/b8816cbc-7e7a-4a6b-8960-b844ab1a80d3" width="300" />


### 📡 Background Location Tracking
- Runs continuously in the background using `geolocator`
- Tracks your real-time GPS position against your defined safe routes
- Works **offline** once map tiles are cached — no internet required for tracking

### 🚨 Monitoring States
The app operates in four escalating alert states:

| State | Description |
|---|---|
| ✅ **ON SAFE ROUTE** | You are within your expected route — all is well |
| ⚠️ **OFF SAFE ROUTE WARNING** | You have deviated from your safe route |
| 🔶 **HEIGHTENED MONITORING** | Sustained deviation — monitoring intensifies |
| 🆘 **EMERGENCY MODE** | Critical situation — all emergency actions triggered |

### 📲 Contact Alerts
- Add trusted contacts (family, friends, guardians) within the app
- Contacts are **automatically notified via SMS** when you go off route or escalate to emergency mode
- <img src="https://github.com/user-attachments/assets/f6b88e8d-b8ce-4f53-a25c-17431970969c" width="300" />


### 🆘 SOS Button
- One-press **SOS button** immediately triggers:
  - SMS alert to all added contacts
  - Loud audio alarm (device volume raised to maximum)
- Features an **alarm slider button** for the loud siren — prevents accidental activation

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | [Flutter](https://flutter.dev/) |
| Maps | OpenStreetMap (OSM) via Flutter pub.dev packages |
| Location | `geolocator` — offline GPS tracking |
| Notifications | SMS via Flutter pub.dev packages |
| Background service | Flutter background execution packages |
| Offline maps | Tile caching (requires internet on first load) |

> **Note:** This app is built entirely with Flutter and packages from [pub.dev](https://pub.dev/). No custom native SDKs required.

---

## How It Works

```
User defines safe route(s)
         ↓
App caches map tiles (requires internet, one-time per area)
         ↓
Background tracking begins (GPS via geolocator)
         ↓
Real-time position compared with safe route
         ↓
ON SAFE ROUTE → no action
         ↓
OFF SAFE ROUTE → warning triggered
         ↓
Notification sent: "Are you safe?" confirmation to user
         ├── User confirms safe BUT still off route
         │        ↓
         │   HEIGHTENED MONITORING → monitoring intensifies
         │        ↓
         │   User does not respond or confirms NOT safe
         │        ↓
         └──────► EMERGENCY MODE → continuous SMS updates with live location sent to trusted contacts

─────────────────────────────────────────
SOS Button   → triggers continuous SMS alerts to trusted contacts (same as Emergency Mode)
Slider Button → activates loud alarm at full device volume
```

---

## Getting Started

### Prerequisites
- Flutter SDK (latest stable)
- Android or iOS device/emulator
- Internet connection (for initial map tile caching)

### Installation

```bash
# Clone the repository
git clone https://github.com/dheljohn/bantay.git
cd bantay

# Install dependencies
flutter pub get

# Run the app
flutter run
```

### Permissions Required
- **Location** (background) — for continuous GPS tracking
- **SMS** — for sending emergency alerts to contacts
- **Notifications** — for in-app alert states

---

## Offline Support

Bantay is designed to work in low-connectivity situations:

1. **Connect to the internet** and navigate through your safe routes at least once to cache map tiles
2. Once cached, the app will **continue tracking offline** using device GPS
3. SMS alerts still function offline as they rely on the cellular network, not the internet

---

## Monitoring State Details

### ✅ ON SAFE ROUTE
You are traveling along your defined route within the acceptable radius. No alerts are sent.

<img src="https://github.com/user-attachments/assets/23ab8684-8f6f-4951-9cb2-8c0174f8a140" width="300" />



### ⚠️ OFF SAFE ROUTE WARNING
Your position has deviated from the safe route. The app sends a notification asking you to confirm whether you're safe. If you confirm you're safe but remain off-route, the app escalates to Heightened Monitoring.

<img src="https://github.com/user-attachments/assets/0160ff4c-1173-4563-a918-8cea760bdc7f" width="300" />

### 🔶 HEIGHTENED MONITORING
Triggered when you confirm safety but remain off-route. Monitoring frequency increases. If you do not respond or indicate you're not safe, the app escalates to Emergency Mode.

<img src="https://github.com/user-attachments/assets/672bc82a-a398-4f81-ac92-293bd77ba936" width="300" />


### 🆘 EMERGENCY MODE
Activated when you're unresponsive or confirm danger. The app sends **continuous SMS updates with your live location** to all trusted contacts until the situation is resolved.

<img src="https://github.com/user-attachments/assets/91046f22-a2e3-42ea-a546-1f4e68564987" width="300" />


### 🆘 SOS Button
Manually triggers the same behavior as Emergency Mode — continuous SMS alerts with live location are sent to all trusted contacts immediately.

### 🔊 Alarm Slider Button
Activates a loud siren at full device volume. Designed as a slider to prevent accidental triggering.

---

## Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

---

## License

[MIT](LICENSE)

---

> *"Bantay" — because someone should always be watching out for you.*
