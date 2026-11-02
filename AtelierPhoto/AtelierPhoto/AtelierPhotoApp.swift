import SwiftUI

@main
struct AtelierPhotoApp: App {
    @StateObject private var editor = EditorViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(editor)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var editor: EditorViewModel

    var body: some View {
        if editor.hasDocument {
            EditorView()
        } else {
            HomeView()
        }
    }
}
