#!/usr/bin/env python3
import tkinter as tk
import subprocess
import traceback

def run_script():
    # Button deaktivieren, um Mehrfachklicks zu verhindern.
    add_device_button.config(state='disabled')
    message_label.config(text="Skript wird ausgeführt...")
    root.update()  # GUI-Aktualisierung erzwingen

    try:
        # Expliziter Aufruf von bash, um das Skript auszuführen.
        process = subprocess.Popen(["bash", "./StartDppConfiguratorV2.sh"],
                                   stdout=subprocess.PIPE,
                                   stderr=subprocess.PIPE,
                                   text=True)
        # Warten, bis der Prozess beendet ist und Ausgabe erfassen.
        stdout, stderr = process.communicate()
        
        # Sammeln Sie Debug-Informationen: Rückgabecode, stdout und stderr.
        debug_info = f"Exit-Code: {process.returncode}\n\nSTDOUT:\n{stdout}\n\nSTDERR:\n{stderr}"
        
        if process.returncode == 0:
            message_label.config(text="Device added succesfully\n" + debug_info)
        else:
            message_label.config(text="Skriptfehler\n" + debug_info)
    except Exception as e:
        # Bei Fehlern den Fehler und Traceback anzeigen.
        tb = traceback.format_exc()
        message_label.config(text=f"Ein Fehler ist aufgetreten: {e}\n{tb}")
    finally:
        # Button wieder aktivieren.
        add_device_button.config(state='normal')

# Tkinter-GUI einrichten.
root = tk.Tk()
root.title("Wi-Fi Device Adder")
root.geometry("600x400")  # Größeres Fenster für mehr Debug-Text

# Button, der das Skript ausführt.
add_device_button = tk.Button(root, text="Add Device to Wi-Fi", command=run_script, height=2, width=25)
add_device_button.pack(pady=20)

# Nachrichtenfeld zur Anzeige von Ergebnissen und Debug-Informationen.
message_label = tk.Label(root, text="", wraplength=550, justify="left")
message_label.pack(pady=20)

# Starten der Haupt-Ereignisschleife.
root.mainloop()
