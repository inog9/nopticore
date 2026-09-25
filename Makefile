export THEOS_DEVICE_IP = # isi IP device kamu kalau mau install lewat SSH, contoh: 192.168.1.50
ARCHS = arm64
TARGET := iphone:clang:latest:11.0

include $(THEOS)/makefiles/common.mk

TOOL_NAME = nopticored

nopticored_FILES = Sources/main.m Sources/PostureCollector.m Sources/HTTPReporter.m Sources/Config.m
nopticored_CFLAGS = -fobjc-arc -Wall
nopticored_FRAMEWORKS = Foundation IOKit
nopticored_INSTALL_PATH = /usr/libexec

include $(THEOS_MAKE_PATH)/tool.mk

# Companion app (UI) -- target terpisah dari daemon. App jalan sebagai user
# "mobile" tanpa privilege khusus: cuma baca/tulis config plist di
# /var/mobile dan baca log daemon. Sengaja TIDAK bisa start/stop daemon,
# supaya tidak butuh entitlement tambahan.
APPLICATION_NAME = NopticoreApp

NopticoreApp_FILES = App/Sources/main.m App/Sources/AppDelegate.m App/Sources/StatusViewController.m App/Sources/SettingsViewController.m App/Sources/AboutViewController.m App/Sources/AppConfigStore.m App/Sources/DaemonStatus.m App/Sources/NopticoreTheme.m App/Sources/LogoView.m App/Sources/SplashViewController.m App/Sources/EmptyStateView.m App/Sources/Localization.m
# UI app ini sengaja minimum iOS 13 (SF Symbols, UIListContentConfiguration,
# system colors) -- beda dari daemon (tetap 11.0 biar kompatibel device lama).
# -miphoneos-version-min override TARGET global (11.0) cuma untuk target ini.
NopticoreApp_CFLAGS = -fobjc-arc -Wall -Wno-overriding-t-option -target arm64-apple-ios14.0
NopticoreApp_LDFLAGS = -Wno-overriding-t-option -target arm64-apple-ios14.0
NopticoreApp_FRAMEWORKS = UIKit Foundation
NopticoreApp_RESOURCE_DIRS = App/Resources

include $(THEOS_MAKE_PATH)/application.mk

after-install::
	install.exec "launchctl unload /var/jb/Library/LaunchDaemons/com.ptxyz.nopticored.plist; launchctl load /var/jb/Library/LaunchDaemons/com.ptxyz.nopticored.plist"

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/LaunchDaemons$(ECHO_END)
	$(ECHO_NOTHING)cp $(THEOS_PROJECT_DIR)/Resources/com.ptxyz.nopticored.plist $(THEOS_STAGING_DIR)/Library/LaunchDaemons/$(ECHO_END)
