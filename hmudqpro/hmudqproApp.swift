import SwiftUI

@main
struct hmudqproApp: App {
    @StateObject private var auth = AuthViewModel.shared

    init() {
        SDKBootstrap.setupAll()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .task { await auth.restoreOnLaunch() }
        }
    }
}
