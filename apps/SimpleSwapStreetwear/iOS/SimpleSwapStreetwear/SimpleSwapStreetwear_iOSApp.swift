import SwiftUI

@main
struct SimpleSwapStreetwear_iOSApp: App {
    @StateObject private var appViewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appViewModel)
                .preferredColorScheme(appViewModel.isDarkMode ? .dark : .light)
        }
    }
}

