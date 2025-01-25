#!/bin/bash

# 简单签名，移除复杂的证书创建过程
codesign --force --deep --sign - \
    --entitlements entitlements.plist \
    --timestamp \
    .build/NoSleep.app

# 验证签名
codesign --verify --verbose .build/NoSleep.app 