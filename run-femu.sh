#!/bin/bash
# Huaicheng Li <huaicheng@cs.uchicago.edu>
# Run VM with FEMU support: FEMU as a black-box SSD (FTL managed by the device)

PWD=`pwd`
# Image directory
IMGDIR=$PWD/images
# Virtual machine disk image
OSIMGF=$IMGDIR/ZNSDedup.qcow2
PORT=18183
OSIMGF2=$IMGDIR/broken_ZNSDedup.qcow2
PORT2=18182
# PORT=10125

if [[ ! -e "$OSIMGF" ]]; then
	echo ""
	echo "VM disk image couldn't be found ..."
	echo "Please prepare a usable VM image and place it as $OSIMGF"
	echo "Once VM disk image is ready, please rerun this script again"
	echo ""
	exit
fi

share_trace_dir_path=${PWD}/../traces
share_kernel_dir_path=${PWD}/../LinuxKernel
share_output_dir_path=${PWD}/shared_dir
echo share_output_dir_path=$share_output_dir_path
mkdir -p $share_output_dir_path
sudo rm $share_output_dir_path/*.log

KB=1024
let MB=${KB}*1024
let GB=${MB}*1024

let physical_mb=16*${GB}/${MB} # 16GB
let logical_mb=12*${GB}/${MB} # 12GB
let block_size=1*${MB} # 1MB

secsz=512 # sector size in bytes
secs_per_pg=8 # number of sectors in a flash page
let pgs_per_blk=${block_size}/${secs_per_pg}/${secsz} # number of pages per block
pls_per_lun=1 # keep it at one, no multiplanes support
luns_per_ch=8 # number of chips per channel
nchs=8 # number of channels
let blks_per_pl=${physical_mb}*${MB}/${nchs}/${luns_per_ch}/${pls_per_lun}/${pgs_per_blk}/${secs_per_pg}/${secsz}

pg_rd_lat=40000 # page read latency
pg_wr_lat=140000 # page write latency
blk_er_lat=3000000 # block erase latency
gc_thres_pcent=90

log_file=${PWD}/femu.log
terminal_file=${PWD}/terminal.log

DEVICE_OPTIONS="-device femu"
DEVICE_OPTIONS=${DEVICE_OPTIONS}",devsz_mb=${logical_mb}"
DEVICE_OPTIONS=${DEVICE_OPTIONS}",femu_mode=1"
DEVICE_OPTIONS=${DEVICE_OPTIONS}",secsz=${secsz}"
DEVICE_OPTIONS=${DEVICE_OPTIONS}",secs_per_pg=${secs_per_pg}"
DEVICE_OPTIONS=${DEVICE_OPTIONS}",pgs_per_blk=${pgs_per_blk}"
DEVICE_OPTIONS=${DEVICE_OPTIONS}",blks_per_pl=${blks_per_pl}"
DEVICE_OPTIONS=${DEVICE_OPTIONS}",pls_per_lun=${pls_per_lun}"
DEVICE_OPTIONS=${DEVICE_OPTIONS}",luns_per_ch=${luns_per_ch}"
DEVICE_OPTIONS=${DEVICE_OPTIONS}",nchs=${nchs}"
DEVICE_OPTIONS=${DEVICE_OPTIONS}",pg_rd_lat=${pg_rd_lat}"
DEVICE_OPTIONS=${DEVICE_OPTIONS}",pg_wr_lat=${pg_wr_lat}"
DEVICE_OPTIONS=${DEVICE_OPTIONS}",blk_er_lat=${blk_er_lat}"
DEVICE_OPTIONS=${DEVICE_OPTIONS}",gc_thres_pcent=${gc_thres_pcent}"
DEVICE_OPTIONS=${DEVICE_OPTIONS}",log_file=${log_file}"

echo "$DEVICE_OPTIONS" | sed 's/,/\n/g' > ${terminal_file}
# kernel_version="5.19.17HonSoffDedup"
kernel_version="5.19.17Dedup+"

cd ./FEMU/build-femu
# sudo gdbserver localhost:2222 numactl --cpubind=1 --membind=1 x86_64-softmmu/qemu-system-x86_64 -S -s \
sudo numactl --cpubind=1 --membind=1 x86_64-softmmu/qemu-system-x86_64 \
    -name "FEMU-blackbox-SSD" \
    -enable-kvm \
    -cpu host \
    -smp 16 \
    -m 10G \
    -kernel $share_output_dir_path/my_kernels/vmlinuz-${kernel_version} \
    -initrd $share_output_dir_path/my_kernels/initrd.img-${kernel_version} \
    -append "root=/dev/sda2 ro console=ttyS0" \
    -fsdev local,security_model=passthrough,id=fsdev0,path=$share_output_dir_path \
    -device virtio-9p-pci,id=fs0,fsdev=fsdev0,mount_tag=hostshare \
    -fsdev local,security_model=passthrough,id=fsdev1,path=$share_kernel_dir_path \
    -device virtio-9p-pci,id=fs1,fsdev=fsdev1,mount_tag=kernelshare \
    -fsdev local,security_model=passthrough,id=fsdev2,path=$share_trace_dir_path \
    -device virtio-9p-pci,id=fs2,fsdev=fsdev2,mount_tag=traceshare \
    -device virtio-scsi-pci,id=scsi0 \
    -device scsi-hd,drive=hd0 \
    -drive file=$OSIMGF,if=none,aio=native,cache=none,format=qcow2,id=hd0 \
    ${DEVICE_OPTIONS} \
    -net user,hostfwd=tcp::${PORT}-:22 \
    -net nic,model=virtio \
    -nographic \
    -qmp unix:./qmp-sock,server,nowait 2>&1 | tee ${terminal_file}
    
    # -device scsi-hd,drive=hd1 \
    # -drive file=$OSIMGF2,if=none,aio=native,cache=none,format=qcow2,id=hd1 \

    # -kernel $share_output_dir_path/vmlinuz-5.19.17HonSoffDedup \
    # -initrd $share_output_dir_path/initrd.img-5.19.17HonSoffDedup \
    # -append "root=/dev/sda2 ro console=ttyS0" \

cd $PWD
# sudo chown -R wenyuhong:wenyuhong $share_trace_dir_path
# sudo chown -R wenyuhong:wenyuhong $share_kernel_dir_path
# sudo chown -R wenyuhong:wenyuhong $share_output_dir_path
sudo mv ${terminal_file} ${share_output_dir_path}
sudo mv ${log_file} ${share_output_dir_path}