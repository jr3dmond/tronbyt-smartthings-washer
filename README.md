# SmartThings Washer — Tidbyt/Tronbyt App

Displays the current state of a Samsung washing machine on a Tidbyt or Tronbyt display using the SmartThings API.

## Display

The app shows a two-line status on the 64×32 pixel display:

| State | Label | Color |
|---|---|---|
| Pre-wash / Sensing | Pre-Wash / Sensing | green |
| Washing | Washing | green |
| Rinsing | Rinsing | green |
| Spinning | Spinning | green |
| Drying | Drying | green |
| Paused | Paused | orange |
| Cycle complete | Done! | blue |
| Off / Idle | Idle | gray |
| API error | API Error | red |

When a cycle is running and the washer reports a completion time, a third line shows the estimated minutes remaining (e.g. `12 min`).

## Prerequisites

- A [Tidbyt](https://tidbyt.com) or [Tronbyt](https://tronbyt.com) device
- [pixlet](https://github.com/tidbyt/pixlet) installed locally
- A Samsung washer connected to the SmartThings app

## Setup

### 1. Get a SmartThings Personal Access Token

1. Go to **https://account.smartthings.com/tokens**
2. Click **Generate new token**
3. Give it a name (e.g. `Tidbyt`)
4. Under scopes, enable **List all devices** and **See all devices**
5. Click **Generate token** and copy it — SmartThings only shows it once

### 2. Find your washer's device ID

Run the following, replacing `YOUR_TOKEN` with the token from step 1:

```bash
curl -s -H "Authorization: Bearer YOUR_TOKEN" \
  https://api.smartthings.com/v1/devices | jq '.items[] | {id, label}'
```

Find your washing machine in the output and note its `id` value.

If you don't have `jq` installed, you can paste the raw JSON into any JSON viewer and look for your washer by its `label`.

### 3. Preview the app locally

```bash
pixlet serve smartthings_washer.star
```

Open **http://localhost:8080** in a browser. Enter your token and device ID in the sidebar — the display will update live.

### 4. Push to your device

```bash
pixlet render smartthings_washer.star \
  api_token=YOUR_TOKEN \
  device_id=YOUR_DEVICE_ID

pixlet push --api-token YOUR_TRONBYT_TOKEN YOUR_DEVICE_ID smartthings_washer.webp
```

## Notes

- The app caches the SmartThings API response for 60 seconds to stay within rate limits.
- The "Done!" state persists until a new cycle starts — intentionally, as a reminder to move the laundry.
