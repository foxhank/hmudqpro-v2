import SwiftUI
import WidgetKit

@main
struct hmudqproApp: App {
    @StateObject private var auth = AuthViewModel.shared


    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                // 开屏检查（更新/彩蛋/会话恢复）由 RootView 里的 SplashCoordinator 驱动
                // 每次启动重算小组件时间线：代码逻辑修复（如钳制 bug）也要能生效，
                // 不能只依赖「数据变化才 reload」——旧错误时间线可能已在系统里排了 14 天
                .task { WidgetCenter.shared.reloadAllTimelines() }
        }
    }
}
