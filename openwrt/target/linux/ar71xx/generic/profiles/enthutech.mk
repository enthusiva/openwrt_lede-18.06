#
# Copyright (C) 2011 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

define Profile/ENTHUTECH2
	NAME:=ENTHUTECH2
	PACKAGES:=kmod-ath9k kmod-usb-core kmod-usb-ohci kmod-usb2 kmod-ledtrig-usbdev
endef

define Profile/ENTHUTECH2/Description
	Package set optimized for the ENTHUTECH v2.
endef

$(eval $(call Profile,ENTHUTECH2))
