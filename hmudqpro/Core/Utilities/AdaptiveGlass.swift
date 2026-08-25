import SwiftUI

/// 版本自适应毛玻璃效果。
///
/// iOS 26+ 使用 Liquid Glass（`glassEffect`，仅在 Xcode 26+/Swift 6.2 SDK 下编入，
/// 用 `#if compiler` 门控保证旧 Xcode 也走同一条代码路径正常编译）；
/// 旧系统降级为系统原生 `.ultraThinMaterial`，保证 iPhone X（iOS 16）等老设备观感一致。
/// 全 app 的按钮/选项卡统一使用本 modifier，禁止散落 `if #available`。
extension View {
    @ViewBuilder
    func adaptiveGlass(in shape: some Shape = .capsule) -> some View {
        if #available(iOS 26.0, *) {
            #if compiler(>=6.2)
            self.glassEffect(.regular, in: shape)
            #else
            self.background(.ultraThinMaterial, in: shape)
            #endif
        } else {
            self.background(.ultraThinMaterial, in: shape)
        }
    }
}
