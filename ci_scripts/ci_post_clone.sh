#!/bin/sh
# Xcode Cloud 默认把 CFBundleVersion 覆盖成它自己的 CI 构建号（很大）；
# 这里用仓库根目录 build_number.txt 里自己维护的构建号（发版时手动 +1），
# 写回工程的 CURRENT_PROJECT_VERSION（本工程为生成式 Info.plist，构建号只存在 pbxproj）。
cd "$CI_PRIMARY_REPOSITORY_PATH" || exit 1
BUILD_NUMBER=$(trim() { echo "$1" | tr -d '[:space:]'; } ; tr -d '[:space:]' < build_number.txt)
if [ -z "$BUILD_NUMBER" ]; then
  echo "ci_post_clone: build_number.txt 为空，跳过（沿用 Xcode Cloud 默认行为）"
  exit 0
fi
echo "ci_post_clone: 使用自定义构建号 $BUILD_NUMBER"
sed -i '' "s/CURRENT_PROJECT_VERSION = [0-9][0-9]*/CURRENT_PROJECT_VERSION = $BUILD_NUMBER/" \
  hmudqpro.xcodeproj/project.pbxproj
/usr/bin/grep -c "CURRENT_PROJECT_VERSION = $BUILD_NUMBER" hmudqpro.xcodeproj/project.pbxproj
