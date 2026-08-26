#!/bin/sh
# Xcode Cloud 默认会把 CFBundleVersion 覆盖成它自己的 CI 构建号（很大）。
# 这里以 Xcode 工程 Identity 里设置的 Build（pbxproj 的 CURRENT_PROJECT_VERSION，
# 本工程为生成式 Info.plist，构建号只存于此）为准：读出来后显式回写固化，
# 云构建产物的构建号 = 你在 Xcode 里设的值。发版时直接在 Xcode 里改 Build 即可。
cd "$CI_PRIMARY_REPOSITORY_PATH" || exit 1
PBXPROJ="hmudqpro.xcodeproj/project.pbxproj"
BUILD_NUMBER=$(/usr/bin/grep -m1 -o 'CURRENT_PROJECT_VERSION = [0-9][0-9]*' "$PBXPROJ" | /usr/bin/grep -o '[0-9][0-9]*')
if [ -z "$BUILD_NUMBER" ]; then
  echo "ci_post_clone: 未在工程中找到 CURRENT_PROJECT_VERSION，跳过"
  exit 0
fi
echo "ci_post_clone: 固化 Identity 构建号 $BUILD_NUMBER"
sed -i '' "s/CURRENT_PROJECT_VERSION = [0-9][0-9]*/CURRENT_PROJECT_VERSION = $BUILD_NUMBER/" "$PBXPROJ"

# Pods 目录不入库（.gitignore），云端克隆后需要安装依赖。
# Xcode Cloud 的 macOS 镜像自带 CocoaPods；Podfile.lock 已入库，版本可复现。
cd "$CI_PRIMARY_REPOSITORY_PATH" || exit 1
echo "ci_post_clone: pod install"
pod install || exit 1
