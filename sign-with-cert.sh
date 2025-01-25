#!/bin/bash

# 创建签名配置文件
cat > signing.entitlements << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
    <key>com.apple.security.automation.apple-events</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    <key>com.apple.security.files.downloads.read-write</key>
    <true/>
</dict>
</plist>
EOF

# 获取开发者证书
DEVELOPER_ID=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | cut -d '"' -f 2)

if [ -z "$DEVELOPER_ID" ]; then
    echo "未找到开发者证书，使用临时签名"
    codesign --force --deep --sign - .build/NoSleep.app
else
    echo "使用证书签名: $DEVELOPER_ID"
    codesign --force --deep --sign "$DEVELOPER_ID" \
        --entitlements signing.entitlements \
        --options runtime \
        .build/NoSleep.app
fi

# 验证签名
codesign --verify --verbose .build/NoSleep.app 