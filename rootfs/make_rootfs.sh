#!/usr/bin/env bash

set -euo pipefail

# =========================================================
# Configuration
# =========================================================

BUSYBOX_VERSION="1.36.1"
BUSYBOX_ARCHIVE="busybox-${BUSYBOX_VERSION}.tar.bz2"
BUSYBOX_URL="https://busybox.net/downloads/${BUSYBOX_ARCHIVE}"

ROOTFS_DIR="$(pwd)/rootfs"
BUILD_DIR="$(pwd)/build"
BUSYBOX_DIR="${BUILD_DIR}/busybox-${BUSYBOX_VERSION}"

JOBS=$(nproc)

# ARM cross compiler prefix
CROSS_COMPILE="arm-linux-gnueabihf-"

# =========================================================
# Helper Functions
# =========================================================

info() {
    echo "[INFO] $*"
}

error() {
    echo "[ERROR] $*" >&2
    exit 1
}

# =========================================================
# Dependency Check
# =========================================================

check_dependencies() {

    local tools=(
        wget
        tar
        gzip
        cpio
        make
        sed
        find
        "${CROSS_COMPILE}gcc"
    )

    for tool in "${tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            error "Missing required tool: $tool"
        fi
    done
}

# =========================================================
# Cleanup
# =========================================================

cleanup() {

    info "Cleaning previous build..."

    rm -rf "${ROOTFS_DIR}"
    rm -rf "${BUILD_DIR}"

    mkdir -p "${ROOTFS_DIR}"
    mkdir -p "${BUILD_DIR}"
}

# =========================================================
# Download BusyBox
# =========================================================

download_busybox() {

    cd "${BUILD_DIR}"

    if [ ! -f "${BUSYBOX_ARCHIVE}" ]; then
        info "Downloading BusyBox ${BUSYBOX_VERSION}..."
        wget "${BUSYBOX_URL}"
    fi

    info "Extracting BusyBox..."
    tar -xjf "${BUSYBOX_ARCHIVE}"
}

# =========================================================
# Configure BusyBox
# =========================================================

configure_busybox() {

    cd "${BUSYBOX_DIR}"

    info "Generating BusyBox default config..."

    make ARCH=arm \
         CROSS_COMPILE="${CROSS_COMPILE}" \
         defconfig

    info "Enabling static BusyBox build..."

    sed -i \
        's/^# CONFIG_STATIC is not set/CONFIG_STATIC=y/' \
        .config

    if ! grep -q "^CONFIG_STATIC=y" .config; then
        echo "CONFIG_STATIC=y" >> .config
    fi
}

# =========================================================
# Build BusyBox
# =========================================================

build_busybox() {

    cd "${BUSYBOX_DIR}"

    info "Building BusyBox..."

    make -j"${JOBS}" \
         ARCH=arm \
         CROSS_COMPILE="${CROSS_COMPILE}"

    info "Installing BusyBox into RootFS..."

    make ARCH=arm \
         CROSS_COMPILE="${CROSS_COMPILE}" \
         CONFIG_PREFIX="${ROOTFS_DIR}" \
         install
}

# =========================================================
# Create RootFS Layout
# =========================================================

create_rootfs_layout() {

    info "Creating RootFS directory structure..."

    mkdir -p "${ROOTFS_DIR}"/{dev,etc,proc,sys,tmp,root,mnt,var,home}

    mkdir -p "${ROOTFS_DIR}/usr/bin"
    mkdir -p "${ROOTFS_DIR}/usr/sbin"

    mkdir -p "${ROOTFS_DIR}/etc/init.d"
}

# =========================================================
# Create Device Nodes
# =========================================================

create_device_nodes() {

    info "Creating device nodes..."

    sudo mknod -m 600 "${ROOTFS_DIR}/dev/console" c 5 1
    sudo mknod -m 666 "${ROOTFS_DIR}/dev/null" c 1 3
}

# =========================================================
# Create /etc/inittab
# =========================================================

create_inittab() {

    info "Creating /etc/inittab..."

    cat > "${ROOTFS_DIR}/etc/inittab" << 'EOF'
::sysinit:/etc/init.d/rcS

ttyAMA0::respawn:/bin/sh

::ctrlaltdel:/bin/umount -a -r
EOF
}

# =========================================================
# Create rcS Script
# =========================================================

create_rcs() {

    info "Creating rcS startup script..."

    cat > "${ROOTFS_DIR}/etc/init.d/rcS" << 'EOF'
#!/bin/sh

echo ""
echo "=================================="
echo " Embedded Linux RootFS Booting"
echo "=================================="
echo ""

mount -t proc none /proc
mount -t sysfs none /sys

echo "Mounted /proc and /sys"

echo ""
echo "System initialization complete"
echo ""
EOF

    chmod +x "${ROOTFS_DIR}/etc/init.d/rcS"
}

# =========================================================
# Create Initramfs
# =========================================================

create_initramfs() {

    info "Creating rootfs.cpio.gz..."

    cd "${ROOTFS_DIR}"

    find . | cpio -H newc -ov --owner root:root | gzip > ../rootfs.cpio.gz

    cd ..

    info "Initramfs successfully created:"
    info "$(pwd)/rootfs.cpio.gz"
}

# =========================================================
# Main
# =========================================================

main() {

    info "Starting BusyBox RootFS build..."

    check_dependencies

    cleanup

    download_busybox

    configure_busybox

    build_busybox

    create_rootfs_layout

    create_device_nodes

    create_inittab

    create_rcs

    create_initramfs

    info "Build completed successfully!"
}

main "$@"
