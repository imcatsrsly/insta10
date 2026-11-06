TARGET := iphone:clang:10.3:10.0
ARCHS := armv7 arm64
INSTALL_TARGET_PROCESSES := Insta10

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME := Insta10
Insta10_FILES := main.m AppDelegate.m IGApplication.m
Insta10_FRAMEWORKS := UIKit Foundation QuartzCore
Insta10_CFLAGS := -fobjc-arc -fmodules-cache-path=$(THEOS_OBJ_DIR)/module-cache -Wno-error=deprecated-module-dot-map
Insta10_CODESIGN_FLAGS := -S

include $(THEOS_MAKE_PATH)/application.mk
