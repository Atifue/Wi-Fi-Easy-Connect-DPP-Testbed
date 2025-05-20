import socketio
import subprocess
import os

FILE_PATH = '/etc/dpp/STA.txt'

os.makedirs(os.path.dirname(FILE_PATH),exist_ok=True)

sio = socketio.Client()

@sio.event
def connect():
	print('Connected to server')

@sio.event
def disconnect():
	print('disconneceted')
	
# Wait for Data
@sio.on('scan')
def on_scan(data):
    print(data)

    try:
        with open(FILE_PATH, 'w') as f:
            f.write(data)

        # Add Device if Data recieved
        result = subprocess.run(['/home/irt/Desktop/scenario2/ConfiguratorAddDevice.sh'], check=True)
        print("Script executed successfully.")
    except Exception as e:
        print(f"Error: {e}")

def main():
	sio.connect('https://dpp.janakj.net')
	sio.wait()

if __name__ == "__main__":
	main()
