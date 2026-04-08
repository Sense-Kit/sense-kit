import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        List {
            Section("Closed Beta") {
                Text("SenseKit is currently a closed beta for passive signal delivery on iPhone.")
                Text("This build focuses on Motion & Fitness, significant location changes and saved-place arrivals and departures, power state changes, and optional workout sample metadata.")
            }

            Section("What Leaves The Device") {
                Text("If you configure OpenClaw, SenseKit sends signed raw signal batches to that HTTPS endpoint. Typical payloads include motion observations, location region changes, battery changes, and optional workout metadata.")
                Text("The configured bearer token is sent in the Authorization header to your chosen endpoint. The HMAC secret itself stays on device, and SenseKit sends a derived signature header instead. Exact coordinates are only included when you enable precise place sharing.")
                Text("If you search for an address during setup, Apple Maps and geocoding services may receive that search query.")
            }

            Section("What Stays Local") {
                Text("SenseKit does not send calendar titles or attendee lists, and it does not upload a continuous GPS trail in the current beta.")
                Text("The app keeps its configuration, local timeline, audit history, and queued deliveries on your device.")
            }

            Section("Permissions") {
                Text("Motion & Fitness is used to observe movement changes in the background.")
                Text("Location is used to capture your saved places, improve driving context, and monitor arrivals and departures in the background.")
                Text("HealthKit is used to observe workout samples when you enable the workout feature.")
            }

            Section("Storage And Control") {
                Text("You can leave OpenClaw unconfigured if you want collected signals to stay on device.")
                Text("You can stop collection by disabling features, turning off permissions in iPhone Settings, or deleting the app to remove local app data.")
            }

            Section("Contact") {
                Text("For privacy or security questions, email julian@sensekit.ai.")
            }
        }
        .navigationTitle("Privacy Policy")
#if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }
}

#Preview {
    NavigationStack {
        PrivacyPolicyView()
    }
}
