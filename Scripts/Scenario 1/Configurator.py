import cv2
from pyzbar.pyzbar import decode
import os

output_path = "/etc/dpp/STA.txt"

def write_to_file(data):
    try:
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        with open(output_path, "w") as f:
            f.write(data)
        print(f"[OK] QR-Code-Daten gespeichert in: {output_path}")
    except PermissionError:
        print(f"[FEHLER] Keine Berechtigung. Starte das Skript mit sudo!")

def main():
    print("QR-Code Scanner wird gestartet...")

    cap = cv2.VideoCapture(0)
    if not cap.isOpened():
        print("[FEHLER] Kamera konnte nicht geöffnet werden.")
        return

    window_name = "QR-Code Scanner"
    cv2.namedWindow(window_name, cv2.WINDOW_NORMAL)  # Einmal definieren

    qr_found = False

    while True:
        ret, frame = cap.read()
        if not ret:
            print("[FEHLER] Kein Kamerabild erhalten.")
            break

        decoded_objs = decode(frame)
        if decoded_objs:
            qr_data = decoded_objs[0].data.decode("utf-8")
            print("[TREFFER] QR-Code erkannt:", qr_data)
            write_to_file(qr_data)
            qr_found = True

        cv2.imshow(window_name, frame)

        key = cv2.waitKey(1) & 0xFF
        if qr_found or key == ord('q'):
            break

    cap.release()
    cv2.destroyWindow(window_name)
    print("Scanner wurde beendet.")

if __name__ == "__main__":
    main()

