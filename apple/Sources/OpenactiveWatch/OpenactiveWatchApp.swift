#if os(watchOS)
import SwiftUI

@main
struct OpenactiveWatchApp: App {
    var body: some Scene {
        WindowGroup {
            BacktrackView()
        }
    }
}
#else

@main
struct OpenactiveWatchHostStub {
    static func main() {
        print("openactive-watch: watchOS target; build with scripts/apple-simulate.sh")
    }
}
#endif
