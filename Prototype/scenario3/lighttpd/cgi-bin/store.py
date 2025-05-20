#!/usr/bin/python3
import cgi
import os
import html

print("Content-Type: text/html; charset=utf-8\n")

# === Target directory for key files ===
storage_dir = "/var/www/html/keys"
os.makedirs(storage_dir, exist_ok=True)

# === Known device keys (Device A) ===
known_keys = {
    "DPP:C:81/6;M:00c0cab79282;V:2;K:MDkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDIgADFrjvJFbcqjOplwbvzQ2ICHGwKc27DsWoaqg0Gk9coIg=;;",
    "DPP:C:81/6;M:00c0cab79283;V:2;K:KEY2==;;",
    "DPP:C:81/6;M:00c0cab79284;V:2;K:KEY3==;;",
    "DPP:C:81/6;M:00c0cab79285;V:2;K:KEY4==;;",
    "DPP:C:81/6;M:00c0cab79286;V:2;K:KEY5==;;"
}

# === Read incoming keys ===
form = cgi.FieldStorage()
keys = form.getlist("key")

if not keys:
    print("<html><body><h3>No keys provided.</h3></body></html>")
    exit()

# === HTML output with overlay ===
print("""
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Bulk Wi-Fi enrollment framework</title>
  <style>
    html, body {
      margin: 0; padding: 0;
      font-family: Arial, sans-serif;
      background: #f4f4f4;
      height: 100%;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: flex-start;
    }
    .page-header {
      text-align: center;
      margin: 24px 0;
    }
    .page-header h1 {
      font-size: 2rem;
      margin: 0;
    }
    /* Overlay backdrop */
    .overlay {
      position: fixed;
      top: 0; left: 0; right: 0; bottom: 0;
      background: rgba(0,0,0,0.6);
      display: none;
      align-items: center;
      justify-content: center;
      z-index: 1000;
    }
    /* Modal container */
    .modal {
      background: #fff;
      border-radius: 8px;
      width: 90%;
      max-width: 800px;
      padding: 20px;
      box-shadow: 0 4px 12px rgba(0,0,0,0.2);
      position: relative;
      text-align: center;
    }
    .modal h2 {
      margin-top: 0;
      font-size: 1.25rem;
      line-height: 1.4;
    }
    /* Close button */
    .close-btn {
      position: absolute;
      top: 12px; right: 12px;
      background: transparent;
      border: none;
      font-size: 1.4rem;
      cursor: pointer;
    }
    /* Device cards grid */
    .cards {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(180px, 1fr));
      gap: 16px;
      margin: 24px 0;
    }
    .card {
      background: #fafafa;
      border: 1px solid #ddd;
      border-radius: 6px;
      padding: 12px;
      transition: transform 0.2s, border-color 0.2s;
      cursor: pointer;
    }
    .card:hover {
      transform: translateY(-4px);
      border-color: #888;
    }
    .card img {
      max-width: 100%;
      height: auto;
      margin-bottom: 8px;
    }
    .card p {
      margin: 4px 0;
      font-size: 0.95rem;
    }
    /* Action buttons */
    #openOverlay, #viewEnrolled {
      margin: 8px;
      background: #28a745;
      color: #fff;
      border: none;
      border-radius: 4px;
      padding: 12px 16px;
      font-size: 1rem;
      cursor: pointer;
      box-shadow: 0 4px 12px rgba(0,0,0,0.3);
    }
    #openOverlay:hover, #viewEnrolled:hover {
      background: #1e7e34;
    }
    .action-btn {
      background: #007bff;
      color: #fff;
      border: none;
      border-radius: 4px;
      padding: 12px 24px;
      font-size: 1rem;
      cursor: pointer;
    }
    .action-btn:hover {
      background: #0056b3;
    }
  </style>
</head>
<body>

  <div class="page-header">
    <h1>Bulk Wi-Fi enrollment framework</h1>
  </div>

  <!-- Enroll Devices toggle -->
  <button id="openOverlay">Select Devices</button>
  <!-- View enrolled devices button -->
  <button id="viewEnrolled" onclick="location.href='/cgi-bin/confirm_store.py'">
    View enrolled devices
  </button>

  <div class="overlay" id="deviceOverlay">
    <div class="modal">
      <button class="close-btn" id="closeOverlay">&times;</button>
      <h2>Please select all devices you want to enroll into the Wi-Fi.<br>
          Only select devices that are known to you.</h2>
      <form method="POST" action="/cgi-bin/confirm_store.py">
        <div class="cards">
""")

# Generate device cards
for key in keys:
    escaped_key = html.escape(key)
    device_type = "A" if key in known_keys else "B"
    image_url = "/cgi-bin/device_pictures/DeviceA.jpg" if device_type == "A" else "/cgi-bin/device_pictures/DeviceB.png"
    print(f"""
          <label class="card">
            <img src="{image_url}" alt="Device {device_type}">
            <p><strong>Device {device_type}</strong></p>
            <input type="checkbox" name="key" value="{escaped_key}" checked>
          </label>
    """)

print("""
        </div>
        <button type="submit" class="action-btn">Store selected devices</button>
      </form>
    </div>
  </div>

  <script>
    const overlay = document.getElementById('deviceOverlay');
    const openBtn = document.getElementById('openOverlay');
    const closeBtn = document.getElementById('closeOverlay');

    function showOverlay() {
      overlay.style.display = 'flex';
    }
    function hideOverlay() {
      overlay.style.display = 'none';
    }

    // Show overlay on load
    showOverlay();

    openBtn.addEventListener('click', showOverlay);
    closeBtn.addEventListener('click', hideOverlay);

    overlay.addEventListener('click', e => {
      if (e.target === overlay) hideOverlay();
    });
  </script>

</body>
</html>
""")
