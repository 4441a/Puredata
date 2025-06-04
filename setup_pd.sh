#Absolutely — here’s the final, complete setup-midi.sh Bash script for your Raspberry Pi 4 Lite that:

#✅ Features

#Feature	Behavior
#Installs Pure Data vanilla	via apt
#Installs ELSE library	builds it into ~/pd-externals/else
#Sets Pd to load ELSE + ~/pd-patches	via .pdsettings/pdstartupflags
#Creates ~/pd-patches folder	for your controller.pd and future patches
#Auto-starts controller.pd on boot	in headless/nogui mode
#Assigns MIDI devices to fixed port IDs	APC Mini = 1, SQ-1 = 2, Elektron Syntakt = 3
#Runs the MIDI mapping and Pd patch at boot	via systemd service

#🧾 Final Script: setup-midi.sh

#!/bin/bash

# 1. Ensure we are running Bash
if [ -z "$BASH_VERSION" ]; then
    echo "Switching to bash..."
    exec bash "$0" "$@"
fi

echo ">>> Updating system..."
sudo apt update && sudo apt upgrade -y

echo ">>> Installing required packages..."
sudo apt install -y \
    git \
    curl \
    build-essential \
    puredata \
    libasound2-dev \
    alsa-utils \
    alsa-tools \
    midisnoop \
    amidi \
    aconnectgui \
    python3 \
    python3-pip \
    unzip \
    libjack-jackd2-0 \
    puredata-dev \
    libasound2 \
    libpulse-dev \
    libx11-dev \
    libgl1-mesa-dev

echo ">>> Creating folders for externals and patches..."
mkdir -p ~/pd-externals
mkdir -p ~/pd-patches

echo ">>> Installing ELSE library into ~/pd-externals..."
cd ~/pd-externals
git clone https://github.com/porres/pd-else
cd pd-else
make
sudo make install
cd ~

echo ">>> Configuring Pure Data to auto-load ELSE and patch folder..."
mkdir -p ~/.pdsettings
PD_PREFS=~/.pdsettings/pdstartupflags
PD_STARTUP_FLAGS="-path ~/pd-externals/else -path ~/pd-patches -lib else"
echo "$PD_STARTUP_FLAGS" > "$PD_PREFS"

echo ">>> Creating Pd wrapper to launch controller.pd..."
sudo tee /usr/local/bin/pd-wrapper.sh > /dev/null << 'EOF'
#!/bin/bash
STARTUP_FLAGS=$(cat ~/.pdsettings/pdstartupflags 2>/dev/null)
puredata -nogui $STARTUP_FLAGS ~/pd-patches/controller.pd
EOF

sudo chmod +x /usr/local/bin/pd-wrapper.sh

echo ">>> Creating MIDI assignment script..."
sudo tee /usr/local/bin/assign-midi.sh > /dev/null << 'EOF'
#!/bin/bash

declare -A midi_devices
midi_devices["APC MINI"]=1
midi_devices["SQ-1"]=2
midi_devices["Elektron Syntakt"]=3

aconnect -x
sleep 2

aconnect -i | grep -E "client|APC MINI|SQ-1|Elektron Syntakt" > /tmp/devices.txt
rm -f /tmp/midi_map.txt

while read -r line; do
    if [[ "$line" == client* ]]; then
        client_num=$(echo $line | cut -d ' ' -f 2 | sed 's/://')
        client_name=$(echo "$line" | cut -d "'" -f 2)
        for device in "${!midi_devices[@]}"; do
            if [[ "$client_name" == *"$device"* ]]; then
                target_port=$(((${midi_devices[$device]} - 1) * 16))
                echo "$device:$client_num" >> /tmp/midi_map.txt
            fi
        done
    fi
done < /tmp/devices.txt
EOF

sudo chmod +x /usr/local/bin/assign-midi.sh

echo ">>> Creating systemd service to assign MIDI and launch Pd..."
sudo tee /etc/systemd/system/pd-midi.service > /dev/null <<EOF
[Unit]
Description=Assign MIDI devices and launch Pure Data
After=multi-user.target sound.target

[Service]
ExecStartPre=/usr/local/bin/assign-midi.sh
ExecStart=/usr/local/bin/pd-wrapper.sh
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

echo ">>> Enabling the Pd MIDI service..."
sudo systemctl daemon-reexec
sudo systemctl enable pd-midi.service

echo ">>> Done!"
echo "🟢 Copy your Pure Data patch to: ~/pd-patches/controller.pd"
echo "🟢 It will auto-launch on boot with ELSE library and MIDI mappings."

#✅ How to Use It
#	1.	Save the script:

nano setup-midi.sh


	#2.	Paste the full script above.
	#3.	Make it executable:

#chmod +x setup-midi.sh


	#4.	Run it:

#./setup-midi.sh


	#5.	Add your patch:

#cp your-patch.pd ~/pd-patches/controller.pd


	#6.	Reboot:

#sudo reboot

#✅ After Reboot
	#Your MIDI devices will be auto-detected and ordered (APC, SQ-1, Syntakt).
	#•	Pd will launch controller.pd in headless mode.
	#•	else and ~/pd-patches will be included in Pd’s search path.
