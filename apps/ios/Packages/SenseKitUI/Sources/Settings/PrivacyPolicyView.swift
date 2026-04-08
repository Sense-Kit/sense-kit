import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        List {
            Section("Closed Beta") {
                Text("SenseKit is currently a closed beta for passive motion and place-based context on iPhone.")
                Text("This build focuses on Motion & Fitness, location changes, power state changes, and workout samples. The app now sends raw signal batches instead of pre-decided context events.")
            }

            Section("What SenseKit Sends") {
                Text("SenseKit sends raw signal batches to the OpenClaw endpoint you configure. Typical payloads include motion observations, location region changes, battery state changes, and workout sample metadata.")
                Text("SenseKit does not send calendar titles, attendee lists, bearer tokens, or HMAC secrets. Exact coordinates are only included when you enable precise place sharing.")
            }

            Section("Permissions") {
                Text("Motion & Fitness is used to observe movement changes in the background.")
                Text("Location is used to capture your saved places, improve driving context, and monitor arrivals and departures in the background.")
                Text("HealthKit is used to observe workout samples when you enable the workout feature.")
            }

            Section("Storage And Control") {
                Text("SenseKit stores its runtime configuration, local timeline, and audit history on your device.")
                Text("You can stop collection by disabling the related feature in Setup, turning off permissions in iPhone Settings, or deleting the app to remove local beta data.")
            }

            Section("Contact") {
                Text("Use the feedback email configured in TestFlight for beta feedback and privacy questions.")
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
