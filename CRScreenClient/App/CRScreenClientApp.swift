import SwiftUI

@main
struct CRScreenClientApp: App {
    @StateObject private var appEnvironment = AppEnvironment()
    
    var body: some Scene {
        WindowGroup {
            WatermarkedAppView(debugSettings: appEnvironment.debugSettings) {
                MainScreen()
                    .environmentObject(appEnvironment)
            }
        }
    }
}
