#!/usr/bin/python3
import cgi
import os
import html

print("Content-Type: text/html; charset=utf-8\n")

# === Target directory for key files ===
storage_dir = "/var/www/html/keys"
os.makedirs(storage_dir, exist_ok=True)

# === Read form fields ===
form = cgi.FieldStorage()
keys_to_store = form.getlist("key")
to_delete = form.getlist("delete_file")

# === Handle deletions ===
for filename in to_delete:
    safe_name = os.path.basename(filename)
    path = os.path.join(storage_dir, safe_name)
    if os.path.isfile(path):
        os.remove(path)

# === Store new keys ===
if keys_to_store:
    existing = sorted(f for f in os.listdir(storage_dir)
                      if f.startswith("key_") and f.endswith(".txt"))
    next_index = len(existing) + 1
    for key in keys_to_store:
        filename = f"key_{next_index:03d}.txt"
        with open(os.path.join(storage_dir, filename), "w") as f:
            f.write(key)
        next_index += 1

# === Gather current stored devices ===
stored = []
for fname in sorted(f for f in os.listdir(storage_dir)
                    if f.startswith("key_") and f.endswith(".txt")):
    path = os.path.join(storage_dir, fname)
    with open(path) as f:
        key = f.read().strip()
    # Determine device type by key prefix
    prefix = key.split(";", 1)[0]
    parts = prefix.split(":")
    dev = parts[1] if len(parts) > 1 else ""
    if dev in ("A", "B", "C"):
        img = "/cgi-bin/device_pictures/DeviceA.jpg"
        name = "Device A"
    else:
        img = "/cgi-bin/device_pictures/DeviceB.png"
        name = "Device B"
    stored.append((fname, img, name))

# === HTML output with overlay UI ===
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
    .overlay {
      position: fixed;
      top: 0; left: 0; right: 0; bottom: 0;
      background: rgba(0,0,0,0.6);
      display: none;
      align-items: center;
      justify-content: center;
      z-index: 1000;
    }
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
    .close-btn {
      position: absolute;
      top: 12px; right: 12px;
      background: transparent;
      border: none;
      font-size: 1.4rem;
      cursor: pointer;
    }
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
    .card form {
      margin-top: 8px;
    }
    .card button {
      background: #dc3545;
      color: #fff;
      border: none;
      border-radius: 4px;
      padding: 6px 12px;
      font-size: 0.9rem;
      cursor: pointer;
    }
    .card button:hover {
      background: #c82333;
    }
    #openOverlay, #returnStore {
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
    #openOverlay:hover, #returnStore:hover {
      background: #1e7e34;
    }
  </style>
</head>
<body>

  <div class="page-header">
    <h1>Bulk Wi-Fi enrollment framework</h1>
  </div>

  <button id="openOverlay">View enrolled devices</button>
  <button id="returnStore" onclick="location.href='/cgi-bin/store.py?key=DPP:C:81/6;M:00c0cab79282;V:2;K:MDkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDIgADFrjvJFbcqjOplwbvzQ2ICHGwKc27DsWoaqg0Gk9coIg=;;&key=A'">
    Return to enrollment
  </button>

  <div class="overlay" id="deviceOverlay">
    <div class="modal">
      <button class="close-btn" id="closeOverlay">&times;</button>
      <h2>Enrolled devices:</h2>
      <div class="cards">
""")

# Render each enrolled device card without file reference, with delete button
for fname, img, name in stored:
    esc_fname = html.escape(fname)
    print(f"""
        <div class="card">
          <img src="{img}" alt="{name}">
          <p><strong>{name}</strong></p>
          <form method="POST" action="/cgi-bin/confirm_store.py">
            <input type="hidden" name="delete_file" value="{esc_fname}">
            <button type="submit">Delete</button>
          </form>
        </div>
    """)

print("""
      </div>
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
