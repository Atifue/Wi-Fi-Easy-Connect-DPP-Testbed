#!/usr/bin/python3
import cgitb; cgitb.enable(display=1, logdir="/tmp")
import cgi, os, html

print("Content-Type: text/html; charset=utf-8\n")

# === Target directories ===
storage_dir = "/var/www/html/keys"
mac_dir     = "/var/www/html/mac"

os.makedirs(storage_dir, exist_ok=True)
os.makedirs(mac_dir, exist_ok=True)

# === Read form fields ===
form = cgi.FieldStorage()
keys_to_store = form.getlist("key")
to_delete     = form.getlist("delete_file")

# === Handle deletions ===
for filename in to_delete:
    safe_name = os.path.basename(filename)
    key_path = os.path.join(storage_dir, safe_name)
    if os.path.isfile(key_path):
        # optional: also remove the MAC-file here if you want
        with open(key_path) as f:
            key = f.read().strip()
        parts = key.split("M:", 1)
        if len(parts) > 1:
            mac = parts[1].split(";", 1)[0]
            mac_path = os.path.join(mac_dir, f"{mac}.txt")
            # if os.path.isfile(mac_path):
            #     os.remove(mac_path)
        os.remove(key_path)

# === Store new keys + create MAC-files ===
if keys_to_store:
    existing = sorted(f for f in os.listdir(storage_dir)
                      if f.startswith("key_") and f.endswith(".txt"))
    next_index = len(existing) + 1

    for key in keys_to_store:
        # write key file
        filename = f"key_{next_index:03d}.txt"
        with open(os.path.join(storage_dir, filename), "w") as f:
            f.write(key)
        # extract MAC and touch a MAC file
        # extract MAC and always (re)create the MAC file
        parts = key.split("M:", 1)
        if len(parts) > 1:
            mac = parts[1].split(";", 1)[0]
            mac_file = os.path.join(mac_dir, f"{mac}.txt")
            # remove old file if present
            try:
                os.remove(mac_file)
            except FileNotFoundError:
                pass
            # now (re)create it
            with open(mac_file, "w") as mf:
                mf.write("")
        next_index += 1

# === Gather stored devices + pending status ===
stored = []
for fname in sorted(f for f in os.listdir(storage_dir)
                    if f.startswith("key_") and f.endswith(".txt")):
    path = os.path.join(storage_dir, fname)
    with open(path) as f:
        key = f.read().strip()

    # determine device image & name
    prefix = key.split(";", 1)[0]
    parts = prefix.split(":")
    dev = key
    if dev in ("DPP:C:81/6;M:00c0cab72edc;V:2;K:MDkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDIgACBQQiyasrQAiQ4yoHuQoN5GL+RjinOp+tZGhzC6b8tZE==;;", "DPP:C:81/6;M:00c0cab79282;V:2;K:MDkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDIgADOB+hOAydt8g10wvb6lqp2Rkyh08dPQ3FvPRYowql2HE=;;"):
        img  = "/cgi-bin/device_pictures/DeviceA.png"
        name = "Smart Temperature Sensor"
    elif dev in ("AJBWUIBDLAWD:OBNA:LBWD:L"):
        img  = "/cgi-bin/device_pictures/DeviceB.png"
        name = "Smart Humidity Sensor"
    elif dev in ("DPP:C:81/6;M:00c0cab72edc;V:2;K:MDkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDIgACBQQiyasrQAiQ4yoHuQoN5GL+RjinOp+tZGhzC6b8tZA==;;"):
        img  = "/cgi-bin/device_pictures/DeviceC.png"
        name = "Network tracker"
    else:
        img  = "/cgi-bin/device_pictures/DeviceB.png"
        name = "Device unknown"

    # extract MAC and check if its file still exists
    mac = key.split("M:", 1)[1].split(";", 1)[0]
    pending = os.path.isfile(os.path.join(mac_dir, f"{mac}.txt"))

    stored.append((fname, img, name, mac, pending))

# === Render HTML with JS polling ===
print("""
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Wi-Fi Connector</title>
  <style>
    /* layout & modal */
    html, body { margin:0; padding:0; font-family:Arial,sans-serif; background:#f4f4f4; height:100%; display:flex; flex-direction:column; align-items:center; justify-content:flex-start; }
    .page-header { text-align:center; margin:24px 0; }
    .page-header h1 { font-size:2rem; margin:0; }
    .overlay { position:fixed; top:0; left:0; right:0; bottom:0; background:rgba(0,0,0,0.6); display:none; align-items:center; justify-content:center; z-index:1000; }
    .modal { background:#fff; border-radius:8px; width:90%; max-width:800px; padding:20px; box-shadow:0 4px 12px rgba(0,0,0,0.2); position:relative; text-align:center; }
    .modal h2 { margin-top:0; font-size:1.25rem; line-height:1.4; }
    .close-btn { position:absolute; top:12px; right:12px; background:transparent; border:none; font-size:1.4rem; cursor:pointer; }

    /* cards grid */
    .cards { display:grid; grid-template-columns:repeat(auto-fill, minmax(180px,1fr)); gap:16px; margin:24px 0; }
    .card { background:#fafafa; border:1px solid #ddd; border-radius:6px; padding:12px; transition:transform .2s, border-color .2s; }
    .card:hover { transform:translateY(-4px); border-color:#888; }
    .card img { max-width:100%; height:auto; margin-bottom:8px; }
    .card p { margin:4px 0; font-size:.95rem; }

    /* buttons */
    .card form { margin-top:8px; }
    .card button { background:#dc3545; color:#fff; border:none; border-radius:4px; padding:6px 12px; font-size:.9rem; cursor:pointer; }
    .card button:hover { background:#c82333; }
    #openOverlay, #returnStore { margin:8px; background:#28a745; color:#fff; border:none; border-radius:4px; padding:12px 16px; font-size:1rem; cursor:pointer; box-shadow:0 4px 12px rgba(0,0,0,0.3); }
    #openOverlay:hover, #returnStore:hover { background:#1e7e34; }

    /* loader & checkmark */
    .loader { border:4px solid #f3f3f3; border-top:4px solid #3498db; border-radius:50%; width:24px; height:24px; animation:spin 1s linear infinite; margin:8px auto; }
    @keyframes spin { 0%{transform:rotate(0deg);}100%{transform:rotate(360deg);} }
    .check { font-size:24px; color:#28a745; margin:8px auto; }
  </style>
</head>
<body>

  <div class="page-header">
    <h1>Wi-Fi Connector</h1>
  </div>

  <button id="openOverlay">View added devices</button>
  <p>To add more devices, close this window and click the link again.</p>

  <div class="overlay" id="deviceOverlay">
    <div class="modal">
      <button class="close-btn" id="closeOverlay">&times;</button>
      <h2>Connecting devices...</h2>
      <div class="cards">
""")

for fname, img, name, mac, pending in stored:
    esc = html.escape(fname)
    status_html = '<div class="loader"></div>' if pending else '<div class="check">&#10003;</div>'
    print(f"""
        <div class="card" data-mac="{mac}">
          <img src="{img}" alt="{name}">
          <p><strong>{name}</strong></p>
          <div class="status">{status_html}</div>
          <form method="POST" action="/cgi-bin/confirm_store.py">
            <input type="hidden" name="delete_file" value="{esc}">
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
    function showOverlay(){ overlay.style.display = 'flex'; }
    function hideOverlay(){ overlay.style.display = 'none'; }
    showOverlay();
    openBtn.addEventListener('click', showOverlay);
    closeBtn.addEventListener('click', hideOverlay);
    overlay.addEventListener('click', e => { if(e.target===overlay) hideOverlay(); });

    // Poll every 5s to update loader/check
    setInterval(() => {
      document.querySelectorAll('.card').forEach(card => {
        const mac = card.dataset.mac;
        fetch(`/mac/${mac}.txt`, { method: 'HEAD' })
          .then(res => {
            const st = card.querySelector('.status');
            if (res.ok) {
              st.innerHTML = '<div class="loader"></div>';
            } else {
              st.innerHTML = '<div class="check">&#10003;</div>';
            }
          });
      });
    }, 5000);
  </script>

</body>
</html>
""")
