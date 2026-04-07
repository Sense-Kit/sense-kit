import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        List {
            Section("Closed Beta") {
                Text("SenseKit is currently a closed beta for passive motion and place-based context on iPhone.")
                Text("This build focuses on Motion & Fitness and location-based arrivals, departures, and driving support. Workout handling is still preview-only in the UI and is not fully active in the runtime yet.")
            }

            Section("What SenseKit Sends") {
                Text("SenseKit sends structured context events to the OpenClaw endpoint you configure. Typical payloads include an event type, event time, confidence, short reasons, coarse place labels like home or work, and simple device state like battery bucket and charging.")
                Text("SenseKit does not send raw GPS traces, raw motion history, calendar titles, attendee lists, raw Health values, bearer tokens, or HMAC secrets.")
            }

            Section("Permissions") {
                Text("Motion & Fitness is used to detect wake and driving state on-device.")
                Text("Location is used to capture your saved places, improve driving detection, and monitor arrivals and departures in the background.")
                Text("Calendar and HealthKit strings are present because those integrations are being prepared, but this beta build is centered on motion and location validation.")
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
