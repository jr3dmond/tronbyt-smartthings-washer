"""
SmartThings Washer Status
Displays the current state of a Samsung washing machine via the SmartThings API.
"""

load("http.star", "http")
load("render.star", "render")
load("schema.star", "schema")
load("time.star", "time")

SMARTTHINGS_API = "https://api.smartthings.com/v1"
CACHE_TTL = 60  # seconds

# Status colors
COLOR_RUNNING = "#4CAF50"  # green  — machine is active
COLOR_DONE = "#2196F3"  # blue   — cycle finished
COLOR_PAUSED = "#FF9800"  # orange — paused
COLOR_IDLE = "#757575"  # gray   — stopped / idle
COLOR_ERROR = "#F44336"  # red    — API / parse error
COLOR_WHITE = "#FFFFFF"
COLOR_DIM = "#9E9E9E"

JOB_STATE_LABELS = {
    "wash": "Washing",
    "rinse": "Rinsing",
    "spin": "Spinning",
    "drying": "Drying",
    "finish": "Done!",
    "delayWash": "Delayed",
    "preWash": "Pre-Wash",
    "wrinklePrevent": "Anti-Wrinkle",
    "weightSensing": "Sensing",
    "cooling": "Cooling",
    "none": "",
}

def fetch_status(token, device_id):
    """Fetch washer status from SmartThings API with built-in HTTP caching."""
    url = "{}/devices/{}/status".format(SMARTTHINGS_API, device_id)
    headers = {
        "Authorization": "Bearer " + token,
        "Accept": "application/json",
    }

    resp = http.get(url, headers = headers, ttl_seconds = CACHE_TTL)
    if resp.status_code != 200:
        return None

    data = resp.json()

    # Navigate: components → main → washerOperatingState
    main = data.get("components", {}).get("main", {})
    washer = main.get("washerOperatingState", {})

    machine_state = washer.get("machineState", {}).get("value", "unknown")
    job_state = washer.get("washerJobState", {}).get("value", "none")
    completion_time = washer.get("completionTime", {}).get("value", None)

    return {
        "machine_state": machine_state,
        "job_state": job_state,
        "completion_time": completion_time,
    }

def minutes_remaining(completion_time_str):
    """Parse an ISO8601 completion time and return minutes remaining, or None.

    SmartThings may return timestamps with or without milliseconds, e.g.:
      "2024-01-15T14:30:00Z" or "2024-01-15T14:30:00.000Z"
    Strip sub-seconds before parsing to stay within RFC3339.
    """
    if not completion_time_str:
        return None

    # Strip sub-second precision so RFC3339 parsing succeeds
    ts = completion_time_str
    dot = ts.find(".")
    if dot != -1:
        # Remove everything between '.' and the timezone indicator
        tz_z = ts.find("Z", dot)
        tz_plus = ts.find("+", dot)
        tz_minus = ts.find("-", dot)

        if tz_z != -1:
            ts = ts[:dot] + "Z"
        elif tz_plus != -1:
            ts = ts[:dot] + ts[tz_plus:]
        elif tz_minus != -1:
            ts = ts[:dot] + ts[tz_minus:]

    end = time.parse_time(ts, format = "2006-01-02T15:04:05Z07:00", location = "UTC")
    delta = end - time.now()

    # delta.minutes is total minutes as a float
    mins = int(delta.minutes)
    if mins <= 0:
        return None
    return mins

def state_color(machine_state, job_state):
    if machine_state == "run":
        return COLOR_RUNNING
    if machine_state == "pause":
        return COLOR_PAUSED
    if machine_state == "stop" and job_state == "finish":
        return COLOR_DONE
    if machine_state == "stop":
        return COLOR_IDLE
    return COLOR_ERROR

def status_label(machine_state, job_state):
    if machine_state == "run":
        return JOB_STATE_LABELS.get(job_state, job_state.title()) or "Running"
    if machine_state == "pause":
        return "Paused"
    if machine_state == "stop" and job_state == "finish":
        return "Done!"
    if machine_state == "stop":
        return "Idle"
    return "Unknown"

def render_status(label, color, sub = None):
    """Render the main 64×32 display."""
    children = [
        render.Text("Washer", font = "tb-8", color = COLOR_DIM),
        render.Box(width = 64, height = 3),
        render.Text(label, font = "tb-8", color = color),
    ]
    if sub:
        children.append(render.Box(width = 64, height = 2))
        children.append(render.Text(sub, font = "tom-thumb", color = COLOR_DIM))

    return render.Root(
        child = render.Column(
            main_align = "center",
            cross_align = "center",
            expanded = True,
            children = children,
        ),
    )

def main(config):
    token = config.str("api_token", "")
    device_id = config.str("device_id", "")

    if not token or not device_id:
        return render_status("Setup", COLOR_PAUSED, "Add token + ID")

    status = fetch_status(token, device_id)

    if status == None:
        return render_status("API Error", COLOR_ERROR)

    machine_state = status["machine_state"]
    job_state = status["job_state"]
    completion_time = status["completion_time"]

    label = status_label(machine_state, job_state)
    color = state_color(machine_state, job_state)

    # Show "X min" remaining when the washer is actively running
    sub = None
    if machine_state == "run" and completion_time:
        mins = minutes_remaining(completion_time)
        if mins != None:
            sub = "{} min".format(mins)

    return render_status(label, color, sub)

def get_schema():
    return schema.Schema(
        version = "1",
        fields = [
            schema.Text(
                id = "api_token",
                name = "SmartThings API Token",
                desc = "Personal Access Token from account.smartthings.com → API Tokens",
                icon = "key",
            ),
            schema.Text(
                id = "device_id",
                name = "Device ID",
                desc = "SmartThings device ID of your washing machine (find it via the SmartThings API or IDE)",
                icon = "server",
            ),
        ],
    )
