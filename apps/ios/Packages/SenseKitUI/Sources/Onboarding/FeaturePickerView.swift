import SwiftUI
import SenseKitRuntime

public struct FeaturePickerView: View {
    @Bindable var model: SenseKitAppModel

    public init(model: SenseKitAppModel) {
        self.model = model
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("What should your AI adapt to?")
                    .font(.largeTitle.bold())

                Text("Passive-first by default. No Shortcuts required for these features.")
                    .foregroundStyle(.secondary)

                ForEach(featureCards) { card in
                    Button {
                        Task {
                            await model.toggleFeature(card.feature)
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(card.title)
                                        .font(.headline)
                                    Text(card.description)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: model.selectedFeatures.contains(card.feature) ? "checkmark.circle.fill" : "circle")
                                    .imageScale(.large)
                            }
                            Text(card.permissions)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Text(card.example)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }

    private var featureCards: [FeatureCard] {
        [
            .init(feature: .wakeBrief, title: "Wake Brief", description: "Morning brief when you actually wake up.", permissions: "Requires Motion", example: "Example: 06:47 wake_confirmed -> morning brief"),
            .init(feature: .drivingMode, title: "Driving Mode", description: "Voice-safe output while you are moving in a vehicle.", permissions: "Requires Motion. Location is an optional accuracy boost.", example: "Example: driving_started -> voice-safe replies"),
            .init(feature: .homeWork, title: "Home / Work", description: "Detect arrival and departure automatically.", permissions: "Requires Always Location", example: "Example: arrived_home -> context shift"),
            .init(feature: .workoutFollowUp, title: "Workout Follow-up", description: "Respond after a workout ends.", permissions: "Requires HealthKit workout read", example: "Example: workout_ended -> recovery follow-up")
        ]
    }
}

private struct FeatureCard: Identifiable {
    let feature: FeatureFlag
    let title: String
    let description: String
    let permissions: String
    let example: String

    var id: String { feature.rawValue }
}
