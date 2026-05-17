#!/bin/bash

# 环境路径配置
export JAVA_HOME="/opt/temurin17"
export ANDROID_HOME="/opt/android-sdk"
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"

# --- 函数：安装 Java 17 ---
prepare_java() {
    if [ ! -d "$JAVA_HOME" ]; then
        echo "Missing Java 17. Downloading Temurin 17..."
        # 适用于 Linux x64
        local JAVA_URL="https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.10%2B7/OpenJDK17U-jdk_x64_linux_hotspot_17.0.10_7.tar.gz"
        sudo mkdir -p "$JAVA_HOME"
        curl -L "$JAVA_URL" | sudo tar -xzC "$JAVA_HOME" --strip-components=1
        echo "✅ Java 17 安装完成"
    else
        echo "✅ Java 17 已存在"
    fi
}

# --- 函数：安装 Android SDK ---
prepare_android() {
    if [ ! -d "$ANDROID_HOME" ]; then
        echo "Missing Android SDK. Installing to $ANDROID_HOME..."
        local SDK_URL="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"
        local TEMP_ZIP="/tmp/sdk.zip"
        
        sudo mkdir -p "$ANDROID_HOME/cmdline-tools"
        curl -L -o "$TEMP_ZIP" "$SDK_URL"
        sudo unzip -q "$TEMP_ZIP" -d "$ANDROID_HOME/cmdline-tools"
        sudo mv "$ANDROID_HOME/cmdline-tools/cmdline-tools" "$ANDROID_HOME/cmdline-tools/latest"
        rm -f "$TEMP_ZIP"

        # 自动接受协议并安装基础组件
        echo "yes" | sudo "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" --sdk_root="$ANDROID_HOME" "platform-tools" "platforms;android-33" "build-tools;33.0.2"
        echo "✅ Android SDK 安装完成"
    else
        echo "✅ Android SDK 已存在"
    fi
}

build_apk() {
    echo "🏗️ 开始 Gradle 编译..."
    chmod +x ./gradlew

    # keytool -genkeypair \
    #   -alias key \
    #   -keyalg RSA \
    #   -keysize 2048 \
    #   -validity 3650 \
    #   -keystore signingkey.jks \
    #   -storetype JKS \
    #   -storepass 123456 \
    #   -keypass 123456
    # 如果更新了signingkey.jks需要通过/opt/temurin17/bin/keytool -list -v -keystore ehentai.jks 这个命令查看SHA256并更新repo.json的signingKeyFingerprint

    KEY_STORE_PASSWORD=ehentai \
    ALIAS=mykey \
    KEY_PASSWORD=ehentai \
    ANDROID_HOME="$ANDROID_HOME" \
    JAVA_HOME="$JAVA_HOME" \
    ./gradlew :src:all:ehentai:assembleRelease
}

# ==========================================
#               主程序流程
# ==========================================

# 1. 环境准备
echo "🔍 检查环境..."
prepare_java
prepare_android
# 3. 执行编译
build_apk || exit 1

if [ $? -eq 0 ]; then
    echo "🎉 流程全部完成！"
else
    echo "❌ 编译过程中出错。"
    exit 1
fi