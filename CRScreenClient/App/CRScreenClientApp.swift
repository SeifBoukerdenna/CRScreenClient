import SwiftUI

@main
struct CRScreenClientApp: App {
    @StateObject private var appEnvironment = AppEnvironment()
    
    var body: some Scene {
        WindowGroup {
            MainScreen()
                .environmentObject(appEnvironment)
        }
    }
}
