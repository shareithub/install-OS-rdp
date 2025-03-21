#!/bin/bash

# Backup file sources.list dan semua file di sources.list.d
echo "Backing up /etc/apt/sources.list to /etc/apt/sources.list.bak..."
sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak

echo "Backing up files in /etc/apt/sources.list.d..."
sudo find /etc/apt/sources.list.d -type f -exec cp {} {}.bak \;

# Hapus entri repository yang tidak valid dari /etc/apt/sources.list
echo "Removing invalid repository entries from /etc/apt/sources.list..."
sudo sed -i '/deb http:\/\/archive\.ubuntu\.com\/ubuntu main Release/d' /etc/apt/sources.list

# Hapus entri repository yang tidak valid dari file di /etc/apt/sources.list.d/
echo "Removing invalid repository entries from /etc/apt/sources.list.d..."
sudo find /etc/apt/sources.list.d -type f -exec sudo sed -i '/deb http:\/\/archive\.ubuntu\.com\/ubuntu main Release/d' {} \;

# Update repositori paket dan upgrade paket yang sudah ada
sudo apt-get update && sudo apt-get upgrade -y

# Install QEMU dan utilitasnya
sudo apt-get install qemu -y
sudo apt-get install qemu-utils -y
sudo apt-get install qemu-system-x86-xen -y
sudo apt-get install qemu-system-x86 -y
sudo apt-get install qemu-kvm -y

echo "QEMU installation completed successfully."

# Fungsi untuk menampilkan menu dan mengambil pilihan pengguna
display_menu() {
    echo "Please select the Windows Server or Windows version:"
    echo "1. Windows Server 2016"
    echo "2. Windows Server 2019"
    echo "3. Windows Server 2022"
    echo "4. Windows 11"
    read -p "Enter your choice: " choice
}

# Tampilkan menu pilihan OS
display_menu

# Set variabel sesuai pilihan
case $choice in
    1)
        # Windows Server 2016
        img_file="windows2016.img"
        iso_link="https://go.microsoft.com/fwlink/p/?LinkID=2195174&clcid=0x409&culture=en-us&country=US"
        iso_file="windows2016.iso"
        ;;
    2)
        # Windows Server 2019
        img_file="windows2019.img"
        iso_link="https://go.microsoft.com/fwlink/p/?LinkID=2195167&clcid=0x409&culture=en-us&country=US"
        iso_file="windows2019.iso"
        ;;
    3)
        # Windows Server 2022
        img_file="windows2022.img"
        iso_link="https://go.microsoft.com/fwlink/p/?LinkID=2195280&clcid=0x409&culture=en-us&country=US"
        iso_file="windows2022.iso"
        ;;
    4)
        # Windows 11
        img_file="windows11.img"
        iso_link="https://software.download.prss.microsoft.com/dbazure/Win11_24H2_English_Arm64.iso?t=a37e460a-ebed-4626-afdd-c77436d8c71a&P1=1742174270&P2=601&P3=2&P4=zpQX1t%2btldTrAlxEXBhFZA%2fWR4rb7jaPjmMrlc1X0AZwTGPs%2bepcTQmxJQ%2bobolZCV%2bYOYSX%2fuvfzccqXL%2fAKGgwKEmVTjJ%2bWCR9OIhaOpvyUSe01kIrW5D%2bYR0o%2ftTeRZTQBnXIvN11PsHREa6eiDlvzI%2b%2bgSc0LXEL2Pdbzb6AWEsJC3YSGlu%2bs6qWx%2bEvXSck5K1ZMtwwiYluJp9lseDdstYMqXSTlaJHf7m%2f06ZNxIDQ5yiLDbPszkWzXOTmnO6e%2fMOpKfC1Q3tEkcRgbKQjwrIyWpr%2bstnNmEB9JsJEgef8X7WHn2yYFIuTroKb5XNz0qemWqpebWpM3wOMRw%3d%3d"
        iso_file="windows11.iso"
        ;;
    *)
        echo "Invalid choice. Exiting."
        exit 1
        ;;
esac

echo "Selected version: $img_file"

# Membuat file image mentah dengan nama sesuai pilihan
sudo qemu-img create -f raw "$img_file" 40G
echo "Image file $img_file created successfully."

# Download Virtio driver ISO dengan progress realtime
sudo wget --progress=bar:force -O virtio-win.iso 'https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-virtio/virtio-win-0.1.215-1/virtio-win-0.1.215.iso'
echo "Virtio driver ISO downloaded successfully."

# Download Windows ISO dengan progress realtime
sudo wget --progress=bar:force -O "$iso_file" "$iso_link"
echo "Windows ISO downloaded successfully."

# Menentukan nama base untuk skrip QEMU sesuai pilihan
case $choice in
    1) qemu_os="windows16" ;;   # Ubah nama menjadi windows16 untuk Windows Server 2016
    2) qemu_os="windows19" ;;   # Ubah nama menjadi windows19 untuk Windows Server 2019
    3) qemu_os="windows22" ;;   # Untuk Windows Server 2022, ubah menjadi windows22
    4) qemu_os="windows11" ;;
esac

# Lakukan renaming file ISO dan image sesuai nama yang diinginkan (jika ada file image sebelumnya)
if [ "$choice" -eq 1 ]; then
    sudo mv windows2016.iso ${qemu_os}.iso
    sudo mv windows2016.img ${qemu_os}.img
elif [ "$choice" -eq 2 ]; then
    sudo mv windows2019.iso ${qemu_os}.iso
    sudo mv windows2019.img ${qemu_os}.img
elif [ "$choice" -eq 3 ]; then
    sudo mv windows2022.iso ${qemu_os}.iso
    sudo mv windows2022.img ${qemu_os}.img
fi

sudo bash -c "cat <<EOF > run_qemu.sh
#!/bin/bash
qemu-system-x86_64 \\
-m 4G \\
-cpu host \\
-enable-kvm \\
-boot order=d \\
-drive file=${qemu_os}.iso,media=cdrom \\
-drive file=${qemu_os}.img,format=raw,if=virtio \\
-drive file=virtio-win.iso,media=cdrom \\
-device usb-ehci,id=usb,bus=pci.0,addr=0x4 \\
-device usb-tablet \\
-vnc :0
EOF"

sudo chmod +x run_qemu.sh
echo "QEMU run script (run_qemu.sh) created successfully."

# Menjalankan file skrip run_qemu.sh secara otomatis
sudo ./run_qemu.sh
