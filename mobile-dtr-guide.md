# Mobile DTR & Attendance Logs Integration Guide

This document outlines the business logic, process flows, and API endpoints required to build the Daily Time Record (DTR) and Attendance Logs module in your native Flutter mobile app.

---

## 1. Authentication
The mobile API uses **Laravel Sanctum** for authentication. 
- All API requests must include the Bearer token in the header.
- **Header:** `Authorization: Bearer {your_sanctum_token}`
- **Header:** `Accept: application/json`

---

## 2. API Endpoints

### A. Check DTR Status
Use this endpoint to initialize the DTR screen. It determines if the user is scheduled to work, where they should be, and what their next action is (Time In or Time Out).

- **Endpoint:** `GET /api/dtr/status`
- **Response Structure (200 OK):**
```json
{
  "lastLog": { ... }, // The most recent log for the current shift (null if not logged in yet)
  "isSegmentComplete": false, // True if the user has both timed in and out for the current shift
  "assignedStores": [ ... ], // List of stores the user is assigned to
  "totalAssignedCount": 1,
  "todaySchedule": {
    "id": 10,
    "status": "On-site", // Can be "On-site", "Off-site", or "WFH"
    "start_time": "2026-05-15T08:00:00+08:00",
    "end_time": "2026-05-15T17:00:00+08:00",
    "store": {
      "id": 5,
      "code": "STR-001",
      "name": "Main Branch",
      "latitude": 14.5995,
      "longitude": 120.9842,
      "radius_meters": 100
    }
  }
}
```

### B. Submit DTR Log (Time In / Time Out)
Use this endpoint to submit an attendance record. The backend automatically determines if it should be a "time_in" or "time_out" based on the user's `lastLog`.

- **Endpoint:** `POST /api/dtr/log`
- **Request Body:**
```json
{
    "latitude": 14.599512,
    "longitude": 120.984222,
    "location_accuracy": 15.5,
    "location_captured_at": "2026-05-15T08:00:00.000Z",
    "location_received_at": "2026-05-15T08:00:02.000Z",
    "location_client": "native",
    "location_provider": "capacitor",
    "photo": "data:image/jpeg;base64,...", 
    "device_info": "iOS 17.4 | iPhone 15 Pro",
    "public_ip": "192.168.1.1"
}
```
- **Responses:**
  - `200 OK`: Success (Includes success message and the saved `log` object).
  - `422 Unprocessable Entity`: Validation failed. Look at the `message` field (e.g., "You are outside the active schedule store vicinity", "A log was already recorded recently", etc.).
  - `429 Too Many Requests`: Triggered if the user rapidly spams the button.

### C. Fetch Attendance Logs & History
Use this endpoint to populate the "Logs" and "Work Hours" history screens.

- **Endpoint:** `GET /api/attendance/logs`
- **Query Parameters (Optional):**
  - `page`: Page number for pagination (e.g., `1`).
  - `perPage`: Items per page (default `10`).
  - `search`: Keyword search.
  - `sub_unit`: Filter by sub-unit.
  - `store_id`: Filter by store ID.
  - `date_from`: Start date (YYYY-MM-DD).
  - `date_to`: End date (YYYY-MM-DD).
- **Response Structure (200 OK):**
```json
{
  "logs": {
    "data": [ ... ], // Array of AttendanceLog objects
    "current_page": 1,
    "last_page": 5,
    "total": 50
  },
  "users": [ ... ], // Dropdown options for filtering
  "stores": [ ... ], // Dropdown options for filtering
  "workHoursSummary": [
    {
      "user_id": 1,
      "name": "John Doe",
      "scheduled_minutes": 480,
      "actual_minutes": 475,
      "scheduled_days": 5,
      "days_present": 5,
      "detail_dates": [ ... ]
    }
  ],
  "filters": { ... } // Currently applied filters
}
```

---

## 3. Mobile UI/UX Process Flow

### Step 1: Initial Screen Load & Validation
When the user opens the DTR module:
1. Fetch data from `GET /api/dtr/status`.
2. **Handle States based on response:**
   - **No Schedule:** If `todaySchedule` is `null`, display "No Active Schedule". Disable the Time In/Out button.
   - **Segment Complete:** If `isSegmentComplete` is `true`, display "You have already completed Time In and Time Out for this schedule." Disable the button.
   - **Determine Action:** If `lastLog` is `null` or `lastLog.type === 'time_out'`, the button label should be **"Time In"**. Otherwise, it should be **"Time Out"**.

### Step 2: Location Acquisition (Geofencing)
If `todaySchedule.status` is **not** "WFH":
1. The app must acquire the user's native GPS coordinates with high accuracy.
2. Ensure the accuracy is acceptable (e.g., `< 100 meters`).
3. **Optional Mobile Validation:** You can calculate the distance on the mobile side using the Haversine formula against `todaySchedule.store.latitude` and `todaySchedule.store.longitude`. If distance > `todaySchedule.store.radius_meters`, you can warn the user locally. *(Note: The backend will strictly enforce this anyway).*

### Step 3: Photo Capture
1. Open the device's front-facing camera.
2. Require the user to take a selfie.
3. Compress and encode the image to a Base64 string (`data:image/jpeg;base64,...`).

### Step 4: Submission
1. User taps "Time In" or "Time Out".
2. Show a confirmation dialog ("You are about to record Time In at Main Branch. Continue?").
3. Send the payload to `POST /api/dtr/log`.
4. **Handle Success:** Show a success toast/snackbar, clear the photo, and re-fetch `GET /api/dtr/status` to update the UI (button will flip to the next action or disable).
5. **Handle Error:** Catch the `422` response and display the exact error `message` returned by the server (e.g., Geofence violation, cooldown period active).

---

## 4. Key Business Rules (Backend Enforced)

- **Grace Periods:** Users can clock in based on the `grace_period_minutes` defined on their `ScheduleStore` (defaults to 30 mins before the shift starts).
- **Geofencing:** Unless the schedule is "WFH" (Work From Home), the backend calculates the distance between the provided GPS coordinates and the assigned Store's coordinates. If it exceeds the `radius_meters`, the log is rejected.
- **Spam Prevention:** A strict 5-minute cooldown is enforced between logs to prevent accidental double-taps or duplicate entries.
- **Privacy:** In the `logs` endpoint, standard users will only receive their own history. Managers and Admins will receive data for all users or those in their sub-units.