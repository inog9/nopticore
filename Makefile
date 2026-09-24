export THEOS_DEVICE_IP = # isi IP device kamu kalau mau install lewat SSH, contoh: 192.168.1.50
ARCHS = arm64
TARGET := iphone:clang:latest:11.0

include $(THEOS)/makefiles/common.mk

TOOL_NAME = nopticored

nopticored_FILES = Sources/main.m Sources/PostureCollector.m Sources/HTTPReporter.m Sources/Config.m
nopticored_CFLAGS = -fobjc-arc -Wall
nopticored_FRAMEWORKS = Foundation

include $(THEOS_MAKE_PATH)/tool.mk

after-install::
	install.exec "launchctl unload /Library/LaunchDaemons/com.ptxyz.nopticored.plist; launchctl load /Library/LaunchDaemons/com.ptxyz.nopticored.plist"

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/LaunchDaemons$(ECHO_END)
	$(ECHO_NOTHING)cp $(THEOS_PROJECT_DIR)/Resources/com.ptxyz.nopticored.plist $(THEOS_STAGING_DIR)/Library/LaunchDaemons/$(ECHO_END)
