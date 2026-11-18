import StarfoldShared
import SwiftUI

@main
struct REBOXApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var appViewModel = AppDependencies(streamPlatform: StreamPlatform())
        .makeAppViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .windowTint()
                .appPalette()
                .environment(appViewModel)
                .environment(appDelegate.orientationLock)
                .task { await appViewModel.restore() }
        }
        .onChange(of: scenePhase, initial: true) {
            appViewModel.setActive(scenePhase == .active)
        }
    }
}
