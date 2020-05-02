include makefiles/pkg/base/base.mk

# toggle this as needed - true | false
DOCKER_ENV = false
BUILDER_IMAGE=debian:buster
BUILDER_CONTAINER_NAME=rootfs_builder
BUILDER_CONTAINER_MOUNT_POINT=/tmp/

ARCH=aarch64
# include this in case distro has a code name
# you can  leave it blank
CODENAME=buster
BUILD_DIR=$(PWD)$(PSEP)build
HOST_NAME=pixel-c
TIME_ZONE=America/Toronto
WIFI_SSID="Pixel-C"
WIFI_PASSWORD="connectme!"