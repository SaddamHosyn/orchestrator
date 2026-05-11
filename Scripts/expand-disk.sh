#!/bin/bash
# Expand VirtualBox disk and LVM partition for Vagrant VMs

set -e

echo "=== Starting Disk Expansion ==="

# Wait for VirtualBox tools to settle
sleep 5

# Get the disk device
DISK=$(lsblk -nd -o NAME,TYPE | grep disk | awk '{print "/dev/"$1}' | head -1)

if [ -z "$DISK" ]; then
    echo "ERROR: Could not find disk device"
    exit 1
fi

echo "Found disk: $DISK"

# Rescan the SCSI bus to detect size changes
echo "Rescanning SCSI bus..."
echo 1 > /sys/class/scsi_host/host0/scan 2>/dev/null || true
sleep 2

# Rescan disk for size changes
echo "Rescanning disk: $DISK"
echo 1 > /sys/block/$(basename $DISK)/device/rescan 2>/dev/null || true
sleep 2

# Get partition device (usually /dev/sda3 for Ubuntu)
PARTITION=$(lsblk -nd -o NAME,TYPE $DISK | grep part | awk '{print "/dev/"$1}' | tail -1)

if [ -z "$PARTITION" ]; then
    echo "ERROR: Could not find partition device"
    exit 1
fi

echo "Found partition: $PARTITION"

# Resize partition to use full disk
echo "Expanding partition $PARTITION to full disk size..."
parted ---pretend-input-tty $DISK resizepart $(lsblk -nd -o NAME $PARTITION | sed 's/[a-z]*//g') 100% 2>/dev/null || true

sleep 2

# Get LVM info
PV=$(pvs -o pv_name --no-headings 2>/dev/null | tr -d ' ' | head -1)
VG=$(vgs -o vg_name --no-headings 2>/dev/null | tr -d ' ' | head -1)
LV=$(lvs -o lv_name --no-headings 2>/dev/null | tr -d ' ' | grep ubuntu-lv | head -1)

if [ -z "$PV" ] || [ -z "$VG" ] || [ -z "$LV" ]; then
    echo "ERROR: Could not find LVM components (PV: $PV, VG: $VG, LV: $LV)"
    exit 1
fi

echo "Found LVM: PV=$PV, VG=$VG, LV=$LV"

# Resize physical volume
echo "Resizing physical volume $PV..."
pvresize $PV 2>/dev/null || true

sleep 2

# Extend logical volume
echo "Extending logical volume /dev/$VG/$LV..."
lvextend -l +100%FREE /dev/$VG/$LV 2>/dev/null || true

sleep 2

# Resize filesystem
echo "Resizing filesystem..."
resize2fs /dev/$VG/$LV 2>/dev/null || true

sleep 2

# Verify
echo ""
echo "=== Disk Expansion Complete ==="
echo "Current disk usage:"
df -h / | tail -1

echo "✓ Disk expansion finished successfully"
