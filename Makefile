.PHONY: all clean

NRCPUS="$(cat /proc/cpuinfo | grep "vendor_id" | wc -l)"

all:
	cd ./FEMU/build-femu && ./femu-compile.sh
clean:
	cd ./FEMU/build-femu && make clean