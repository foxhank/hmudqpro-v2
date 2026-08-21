import SwiftUI

/// 版本自适应毛玻璃效果。
///
/// iOS 26+ 使用 Liquid Glass（需 Xcode 26 / iOS 26 SDK 编译，届时在此处补 glassEffect 分支），
/// 旧系统降级为系统原生 `.ultraThinMaterial`，保证 iPhone X（iOS 16）等老设备观感一致。
/// 全 app 的按钮/选项卡统一使用本 modifier，禁止散落 `if #available`。
extension View {
    @ViewBuilder
    func adaptiveGlass(in shape: some Shape = .capsule) -> some View {
        if #available(iOS 26.0, *) {
            // TODO: Xcode 26 SDK 下改为 glassEffect(in:)
            self.background(.ultraThinMaterial, in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
        }
    }
}
