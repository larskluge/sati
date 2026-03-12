import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.badge")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Sati")
                .font(.title)
            Text("Mindfulness reminders")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
