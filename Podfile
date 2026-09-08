platform :ios, '16.0'

target 'hmudqpro' do
  use_frameworks!

  pod 'Bugly'
  pod 'BaiduMobStatCodeless'   # 百度统计 MTJ
  pod 'Ads-CN-Beta'            # 穿山甲 GroMore 融合 SDK（激励视频）
  pod 'Ads-CN-Beta/CSJMediation'  # GroMore 聚合基础库（官方：与 useMediation=YES 缺一不可）

  target 'hmudqproTests' do
    inherit! :search_paths
  end

  target 'hmudqproUITests' do
    inherit! :search_paths
  end
end

# Bugly / 百度统计（含 UserFeedBack）只有真机二进制，没有 arm64 模拟器切片。
# 历史上靠 EXCLUDED_ARCHS=arm64 回避，但这会让 Xcode 认为没有任何模拟器能跑
# 本 App（Xcode 26 已移除 Rosetta 模拟器），设备下拉栏直接空白。
# 现在：去掉 EXCLUDED_ARCHS，模拟器构建改为不链接这两个 SDK（真机构建不受影响，
# 仍完整链接）。SDKBootstrap / 桥接头里有对应的 targetEnvironment(simulator) 分支。
post_install do |installer|
  installer.pods_project.build_configurations.each do |config|
    config.build_settings.delete('EXCLUDED_ARCHS[sdk=iphonesimulator*]')
  end
  installer.pods_project.targets.each do |t|
    t.build_configurations.each do |config|
      config.build_settings.delete('EXCLUDED_ARCHS[sdk=iphonesimulator*]')
    end
  end

  # 直接改写生成的 xcconfig 文件（比 Xcodeproj::Config API 可靠）：
  # 1) 全部去掉 EXCLUDED_ARCHS（含百度 podspec 自带的 pod_target_xcconfig）
  # 2) 聚合配置：基础 OTHER_LDFLAGS 移除仅真机二进制；真机专用项放
  #    OTHER_LDFLAGS[sdk=iphoneos*]（注意条件设置是"追加"不是"覆盖"，
  #    所以反过来写在模拟器条件里是没用的）
  xcconfigs = Dir.glob(File.join(installer.sandbox.root, 'Target Support Files', '**', '*.xcconfig'))
  xcconfigs.each do |path|
    content = File.read(path)
    content = content.lines.reject do |l|
      l.start_with?('EXCLUDED_ARCHS[sdk=iphonesimulator*]',
                    'OTHER_LDFLAGS[sdk=iphonesimulator*]',
                    'OTHER_LDFLAGS[sdk=iphoneos*]')
    end.join
    if File.basename(path).start_with?('Pods-hmudqpro.') && (full = content[/^OTHER_LDFLAGS = (.+)$/, 1])
      cleaned = full.gsub(/ ?-framework "?Bugly"?/, '')
                    .gsub(/ ?-framework "?UserFeedBack"?/, '')
                    .gsub(/ ?-l"?BaiduMobStat"?/, '')
                    .squeeze(' ').strip
      content.sub!(/^OTHER_LDFLAGS = .+$/) { "OTHER_LDFLAGS = #{cleaned}" }
      content += "OTHER_LDFLAGS[sdk=iphoneos*] = -framework \"Bugly\" -framework \"UserFeedBack\" -l\"BaiduMobStat\"\n"
    end
    File.write(path, content)
  end
end
