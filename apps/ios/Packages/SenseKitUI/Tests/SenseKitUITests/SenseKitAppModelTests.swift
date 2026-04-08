import Foundation
import Testing
@testable import SenseKitUI
import SenseKitRuntime

@MainActor
struct SenseKitAppModelTests {
    @Test
    func loadCopiesConfigurationAndEntriesFromService() async throws {
        let state = SenseKitLoadedState(
            configuration: RuntimeConfiguration(
                deviceID: "device-1",
                enabledFeatures: [.wakeBrief, .drivingMode],
                drivingLocationBoostEnabled: true,
                placeSharingMode: .preciseCoordinates,
                openClaw: OpenClawConfiguration(
                    endpointURL: URL(string: "https://example.ts.net/hooks/sensekit")!,
                    bearerToken: "token-1",
                    hmacSecret: "secret-1"
                )
            ),
            wakeCollectorStatus: .running,
            locationCollectorStatus: .running,
            timelineEntries: [
                DebugTimelineEntry(createdAt: Date(), category: .scenario, message: "Manual test scenario driving_signals")
            ],
            auditEntries: [
                AuditLogEntry(
                    createdAt: Date(),
                    eventType: "manual.driving_signals",
                    destination: "https://example.ts.net/hooks/sensekit",
                    status: .delivered,
                    payloadSummary: "HTTP 200",
                    retryCount: 0
                )
            ]
        )
        let service = FakeSenseKitAppService(initialState: state)
        let model = SenseKitAppModel(service: service)

        #expect(model.showsStartupScreen)

        await model.load()

        #expect(!model.showsStartupScreen)
        #expect(model.endpointURLText == "https://example.ts.net/hooks/sensekit")
        #expect(model.bearerToken == "token-1")
        #expect(model.hmacSecret == "secret-1")
        #expect(model.drivingLocationBoostEnabled)
        #expect(model.placeSharingMode == .preciseCoordinates)
        #expect(model.wakeCollectorStatus == .running)
        #expect(model.wakeCollectorStatusText == "Running")
        #expect(model.locationCollectorStatus == .running)
        #expect(model.locationCollectorStatusText == "Running")
        #expect(model.timelineEntries.count == 1)
        #expect(model.auditEntries.count == 1)
        #expect(model.connectionStatus == "Configured for example.ts.net")
        #expect(model.lastStatusRefreshAt != nil)
    }

    @Test
    func saveConnectionPersistsConfiguration() async throws {
        let service = FakeSenseKitAppService(
            initialState: SenseKitLoadedState(configuration: RuntimeConfiguration(deviceID: "device-1"))
        )
        let model = SenseKitAppModel(service: service)
        model.endpointURLText = "https://example.ts.net/hooks/sensekit"
        model.bearerToken = "token-2"
        model.selectedFeatures = [.wakeBrief, .drivingMode]
        model.drivingLocationBoostEnabled = true

        await model.saveConnection()

        let savedConfiguration = await service.savedConfigurations.last
        #expect(savedConfiguration?.openClaw?.endpointURL.absoluteString == "https://example.ts.net/hooks/sensekit")
        #expect(savedConfiguration?.openClaw?.bearerToken == "token-2")
        #expect(savedConfiguration?.openClaw?.hmacSecret == SenseKitAppModel.defaultHMACSecret)
        #expect(savedConfiguration?.drivingLocationBoostEnabled == true)
        #expect(savedConfiguration?.enabledFeatures == [.wakeBrief, .drivingMode])
        #expect(model.feedback?.style == .success)
        #expect(model.feedback?.message == "Configuration saved. OpenClaw is ready.")
    }

    @Test
    func toggleFeaturePersistsConfigurationImmediately() async throws {
        let service = FakeSenseKitAppService(
            initialState: SenseKitLoadedState(
                configuration: RuntimeConfiguration(deviceID: "device-1", enabledFeatures: [.wakeBrief])
            )
        )
        let model = SenseKitAppModel(service: service)
        await model.load()

        await model.toggleFeature(.homeWork)

        let savedConfiguration = await service.savedConfigurations.last
        #expect(model.selectedFeatures.contains(FeatureFlag.homeWork))
        #expect(savedConfiguration?.enabledFeatures.contains(.homeWork) == true)
        #expect(model.feedback?.message == "Feature selection saved.")
    }

    @Test
    func setDrivingLocationBoostEnabledPersistsConfigurationImmediately() async throws {
        let service = FakeSenseKitAppService(
            initialState: SenseKitLoadedState(
                configuration: RuntimeConfiguration(deviceID: "device-1", enabledFeatures: [.drivingMode])
            )
        )
        let model = SenseKitAppModel(service: service)
        await model.load()

        await model.setDrivingLocationBoostEnabled(true)

        let savedConfiguration = await service.savedConfigurations.last
        #expect(model.drivingLocationBoostEnabled)
        #expect(savedConfiguration?.drivingLocationBoostEnabled == true)
        #expect(model.feedback?.message == "Driving location boost saved.")
    }

    @Test
    func applySetupSelectionsPersistsBuilderChoices() async throws {
        let service = FakeSenseKitAppService(
            initialState: SenseKitLoadedState(
                configuration: RuntimeConfiguration(deviceID: "device-1")
            )
        )
        let model = SenseKitAppModel(service: service)
        await model.load()

        await model.applySetupSelections(
            wakeEnabled: true,
            drivingEnabled: true,
            fixedPlacesEnabled: true,
            continuousLocationEnabled: true
        )

        let savedConfiguration = await service.savedConfigurations.last
        #expect(savedConfiguration?.enabledFeatures.contains(.wakeBrief) == true)
        #expect(savedConfiguration?.enabledFeatures.contains(.drivingMode) == true)
        #expect(savedConfiguration?.enabledFeatures.contains(.homeWork) == true)
        #expect(savedConfiguration?.drivingLocationBoostEnabled == true)
        #expect(model.feedback?.message == "Setup choices saved.")
    }

    @Test
    func applySetupSelectionsCanPersistWakeWithoutDriving() async throws {
        let service = FakeSenseKitAppService(
            initialState: SenseKitLoadedState(
                configuration: RuntimeConfiguration(deviceID: "device-1")
            )
        )
        let model = SenseKitAppModel(service: service)
        await model.load()

        await model.applySetupSelections(
            wakeEnabled: true,
            drivingEnabled: false,
            fixedPlacesEnabled: false,
            continuousLocationEnabled: false
        )

        let savedConfiguration = await service.savedConfigurations.last
        #expect(savedConfiguration?.enabledFeatures.contains(.wakeBrief) == true)
        #expect(savedConfiguration?.enabledFeatures.contains(.drivingMode) == false)
    }

    @Test
    func applySetupSelectionsCanPersistContinuousLocationWithoutFixedPlaces() async throws {
        let service = FakeSenseKitAppService(
            initialState: SenseKitLoadedState(
                configuration: RuntimeConfiguration(deviceID: "device-1")
            )
        )
        let model = SenseKitAppModel(service: service)
        await model.load()

        await model.applySetupSelections(
            wakeEnabled: false,
            drivingEnabled: false,
            fixedPlacesEnabled: false,
            continuousLocationEnabled: true
        )

        let savedConfiguration = await service.savedConfigurations.last
        #expect(savedConfiguration?.enabledFeatures.contains(.homeWork) == false)
        #expect(savedConfiguration?.drivingLocationBoostEnabled == true)
    }

    @Test
    func applySetupSelectionsDoesNotClearWorkoutFeature() async throws {
        let service = FakeSenseKitAppService(
            initialState: SenseKitLoadedState(
                configuration: RuntimeConfiguration(
                    deviceID: "device-1",
                    enabledFeatures: [.workoutFollowUp]
                )
            )
        )
        let model = SenseKitAppModel(service: service)
        await model.load()

        await model.applySetupSelections(
            wakeEnabled: true,
            drivingEnabled: false,
            fixedPlacesEnabled: false,
            continuousLocationEnabled: false
        )

        let savedConfiguration = await service.savedConfigurations.last
        #expect(savedConfiguration?.enabledFeatures.contains(.wakeBrief) == true)
        #expect(savedConfiguration?.enabledFeatures.contains(.workoutFollowUp) == true)
    }

    @Test
    func setPlaceSharingModePersistsConfigurationImmediately() async throws {
        let service = FakeSenseKitAppService(
            initialState: SenseKitLoadedState(
                configuration: RuntimeConfiguration(deviceID: "device-1")
            )
        )
        let model = SenseKitAppModel(service: service)
        await model.load()

        await model.setPlaceSharingMode(.preciseCoordinates)

        let savedConfiguration = await service.savedConfigurations.last
        #expect(model.placeSharingMode == .preciseCoordinates)
        #expect(savedConfiguration?.placeSharingMode == .preciseCoordinates)
        #expect(model.feedback?.message == "Place sharing updated.")
    }

    @Test
    func saveConnectionWithoutOpenClawShowsLocalOnlyMessage() async throws {
        let service = FakeSenseKitAppService(
            initialState: SenseKitLoadedState(configuration: RuntimeConfiguration(deviceID: "device-1"))
        )
        let model = SenseKitAppModel(service: service)
        model.selectedFeatures = [.homeWork]

        await model.saveConnection()

        #expect(model.feedback?.style == .success)
        #expect(model.feedback?.message == "Configuration saved. OpenClaw delivery is off.")
    }

    @Test
    func sendTestScenarioCallsServiceAndRefreshesEntries() async throws {
        let initialState = SenseKitLoadedState(
            configuration: RuntimeConfiguration(
                deviceID: "device-1",
                openClaw: OpenClawConfiguration(
                    endpointURL: URL(string: "https://example.ts.net/hooks/sensekit")!,
                    bearerToken: "token-3",
                    hmacSecret: "secret-3"
                )
            )
        )
        let refreshedState = SenseKitLoadedState(
            configuration: RuntimeConfiguration(
                deviceID: "device-1",
                openClaw: OpenClawConfiguration(
                    endpointURL: URL(string: "https://example.ts.net/hooks/sensekit")!,
                    bearerToken: "token-3",
                    hmacSecret: "secret-3"
                )
            ),
            timelineEntries: [
                DebugTimelineEntry(createdAt: Date(), category: .scenario, message: "Manual test scenario driving_signals")
            ],
            auditEntries: [
                AuditLogEntry(
                    createdAt: Date(),
                    eventType: "manual.driving_signals",
                    destination: "https://example.ts.net/hooks/sensekit",
                    status: .delivered,
                    payloadSummary: "HTTP 200",
                    retryCount: 0
                )
            ]
        )
        let service = FakeSenseKitAppService(initialState: initialState)
        let model = SenseKitAppModel(service: service)
        await model.load()
        model.selectedTestScenario = .drivingSignals
        await service.setNextLoadedState(refreshedState)

        await model.sendTestScenario()

        let sentScenarios = await service.sentTestScenarios
        #expect(sentScenarios == [.drivingSignals])
        #expect(model.timelineEntries.count == 1)
        #expect(model.auditEntries.count == 1)
        #expect(model.feedback?.style == .success)
        #expect(model.feedback?.message == "Test signal batch sent. Check Timeline and Audit for the result.")
    }

    @Test
    func saveConnectionShowsMeaningfulValidationError() async throws {
        let service = FakeSenseKitAppService(
            initialState: SenseKitLoadedState(configuration: RuntimeConfiguration(deviceID: "device-1"))
        )
        let model = SenseKitAppModel(service: service)
        model.endpointURLText = "not-a-url"
        model.bearerToken = "token-2"

        await model.saveConnection()

        #expect(model.connectionStatus == "Invalid endpoint URL")
        #expect(model.feedback?.style == .error)
        #expect(model.feedback?.message == "Enter a full http or https URL.")
    }

    @Test
    func sendTestScenarioWithoutConfigurationShowsMeaningfulError() async throws {
        let service = FakeSenseKitAppService(
            initialState: SenseKitLoadedState(configuration: RuntimeConfiguration(deviceID: "device-1"))
        )
        let model = SenseKitAppModel(service: service)

        await model.sendTestScenario()

        let sentScenarios = await service.sentTestScenarios
        #expect(sentScenarios.isEmpty)
        #expect(model.connectionStatus == "Configure OpenClaw first")
        #expect(model.feedback?.style == .error)
        #expect(model.feedback?.message == "Save the OpenClaw connection before sending a test scenario.")
    }

    @Test
    func openClawSetupGuideAppearsWhenConnectionIsMissing() async throws {
        let service = FakeSenseKitAppService(
            initialState: SenseKitLoadedState(configuration: RuntimeConfiguration(deviceID: "device-1"))
        )
        let model = SenseKitAppModel(service: service)

        await model.load()

        #expect(model.showsOpenClawSetupGuide)
        #expect(model.openClawSetupSteps.count == 3)
        #expect(model.openClawSetupSteps[0].contains("OpenClaw JSON"))
        #expect(model.openClawSetupSteps[1].contains("Tailscale"))
    }

    @Test
    func refreshStateReloadsTimelineAndAuditEntriesAfterInitialLoad() async throws {
        let initialState = SenseKitLoadedState(
            configuration: RuntimeConfiguration(deviceID: "device-1"),
            timelineEntries: [
                DebugTimelineEntry(createdAt: Date(), category: .evaluation, message: "Runtime bootstrap completed")
            ],
            auditEntries: []
        )
        let refreshedState = SenseKitLoadedState(
            configuration: RuntimeConfiguration(deviceID: "device-1"),
            timelineEntries: [
                DebugTimelineEntry(createdAt: Date(), category: .signal, message: "Received raw motion activity walking")
            ],
            auditEntries: [
                AuditLogEntry(
                    createdAt: Date(),
                    eventType: "motion_activity_observed",
                    destination: "https://example.ts.net/hooks/sensekit",
                    status: .delivered,
                    payloadSummary: "HTTP 200",
                    retryCount: 0
                )
            ]
        )
        let service = FakeSenseKitAppService(initialState: initialState)
        let model = SenseKitAppModel(service: service)

        await model.load()
        await service.setNextLoadedState(refreshedState)

        await model.refreshState()

        #expect(model.timelineEntries.count == 1)
        #expect(model.timelineEntries.first?.message == "Received raw motion activity walking")
        #expect(model.auditEntries.count == 1)
        #expect(model.auditEntries.first?.eventType == "motion_activity_observed")
    }

    @Test
    func refreshStateDoesNotOverwriteUnsavedFeatureSelections() async throws {
        let initialState = SenseKitLoadedState(
            configuration: RuntimeConfiguration(
                deviceID: "device-1",
                enabledFeatures: [.wakeBrief]
            )
        )
        let refreshedState = SenseKitLoadedState(
            configuration: RuntimeConfiguration(
                deviceID: "device-1",
                enabledFeatures: [.wakeBrief]
            ),
            timelineEntries: [
                DebugTimelineEntry(createdAt: Date(), category: .evaluation, message: "Background refresh")
            ]
        )
        let service = FakeSenseKitAppService(initialState: initialState)
        let model = SenseKitAppModel(service: service)

        await model.load()
        model.selectedFeatures.insert(.homeWork)
        await service.setNextLoadedState(refreshedState)

        await model.refreshState()

        #expect(model.selectedFeatures.contains(.wakeBrief))
        #expect(model.selectedFeatures.contains(.homeWork))
        #expect(model.timelineEntries.count == 1)
        #expect(model.timelineEntries.first?.message == "Background refresh")
    }

    @Test
    func refreshStateDoesNotOverwriteUnsavedConnectionDrafts() async throws {
        let initialState = SenseKitLoadedState(
            configuration: RuntimeConfiguration(
                deviceID: "device-1",
                enabledFeatures: [.wakeBrief, .drivingMode],
                openClaw: OpenClawConfiguration(
                    endpointURL: URL(string: "https://saved.ts.net/hooks/sensekit")!,
                    bearerToken: "saved-token",
                    hmacSecret: "saved-secret"
                )
            )
        )
        let refreshedState = SenseKitLoadedState(
            configuration: RuntimeConfiguration(
                deviceID: "device-1",
                enabledFeatures: [.wakeBrief, .drivingMode],
                openClaw: OpenClawConfiguration(
                    endpointURL: URL(string: "https://saved.ts.net/hooks/sensekit")!,
                    bearerToken: "saved-token",
                    hmacSecret: "saved-secret"
                )
            ),
            timelineEntries: [
                DebugTimelineEntry(createdAt: Date(), category: .evaluation, message: "Background refresh")
            ]
        )
        let service = FakeSenseKitAppService(initialState: initialState)
        let model = SenseKitAppModel(service: service)

        await model.load()
        model.endpointURLText = "https://draft.ts.net/hooks/sensekit"
        model.bearerToken = "draft-token"
        await service.setNextLoadedState(refreshedState)

        await model.refreshState()

        #expect(model.endpointURLText == "https://draft.ts.net/hooks/sensekit")
        #expect(model.bearerToken == "draft-token")
        #expect(model.hmacSecret == "saved-secret")
        #expect(model.timelineEntries.count == 1)
        #expect(model.timelineEntries.first?.message == "Background refresh")
    }

    @Test
    func setHomeRegionFromCurrentLocationUpdatesDraftConfiguration() async throws {
        let service = FakeSenseKitAppService(
            initialState: SenseKitLoadedState(
                configuration: RuntimeConfiguration(deviceID: "device-1", enabledFeatures: [.homeWork])
            ),
            nextCurrentRegion: RegionConfiguration(
                identifier: "home",
                latitude: 47.3769,
                longitude: 8.5417,
                radiusMeters: 175
            )
        )
        let model = SenseKitAppModel(service: service)

        await model.load()
        model.homeRadiusMeters = 175

        await model.setHomeRegionFromCurrentLocation()

        let capturedRequests = await service.captureRequests
        let savedConfiguration = await service.savedConfigurations.last
        #expect(capturedRequests.count == 1)
        #expect(capturedRequests.first?.0 == "home")
        #expect(capturedRequests.first?.1 == 175)
        #expect(model.homeRegionSummary.contains("47.37690"))
        #expect(model.feedback?.style == .success)
        #expect(model.feedback?.message == "Home region updated and saved.")
        #expect(savedConfiguration?.homeRegion?.identifier == "home")
        #expect(savedConfiguration?.enabledFeatures.contains(.homeWork) == true)
    }

    @Test
    func searchHomeRegionFromAddressUpdatesDraftConfiguration() async throws {
        let service = FakeSenseKitAppService(
            initialState: SenseKitLoadedState(
                configuration: RuntimeConfiguration(deviceID: "device-1")
            ),
            nextSearchRegion: RegionConfiguration(
                identifier: "home",
                displayName: "Bahnhofstrasse 1, Zurich",
                latitude: 47.42310,
                longitude: 8.54760,
                radiusMeters: 200
            )
        )
        let model = SenseKitAppModel(service: service)

        await model.load()
        model.homeSearchQuery = "Bahnhofstrasse 1 Zurich"
        model.homeRadiusMeters = 200

        await model.searchHomeRegionFromAddress()

        let searchRequests = await service.searchRequests
        let savedConfiguration = await service.savedConfigurations.last
        #expect(searchRequests.count == 1)
        #expect(searchRequests.first?.0 == "home")
        #expect(searchRequests.first?.1 == "Bahnhofstrasse 1 Zurich")
        #expect(searchRequests.first?.2 == 200)
        #expect(model.selectedFeatures.contains(.homeWork))
        #expect(model.homeRegionSummary.contains("Bahnhofstrasse 1, Zurich"))
        #expect(model.feedback?.message == "Home region found and saved.")
        #expect(savedConfiguration?.homeRegion?.identifier == "home")
    }

    @Test
    func addFixedPlaceFromAddressSavesNamedCustomPlace() async throws {
        let service = FakeSenseKitAppService(
            initialState: SenseKitLoadedState(
                configuration: RuntimeConfiguration(deviceID: "device-1")
            ),
            nextSearchRegion: RegionConfiguration(
                identifier: "placeholder",
                latitude: 47.42310,
                longitude: 8.54760,
                radiusMeters: 200
            )
        )
        let model = SenseKitAppModel(service: service)

        await model.load()

        await model.addFixedPlaceFromAddress(
            name: "Gym",
            query: "Dubsstrasse 2 Zurich",
            radiusMeters: 200
        )

        let searchRequests = await service.searchRequests
        let savedConfiguration = await service.savedConfigurations.last
        let savedPlace = try #require(savedConfiguration?.fixedPlaces.first)
        #expect(searchRequests.count == 1)
        #expect(searchRequests.first?.0.hasPrefix("place-gym") == true)
        #expect(searchRequests.first?.1 == "Dubsstrasse 2 Zurich")
        #expect(searchRequests.first?.2 == 200)
        #expect(savedConfiguration?.enabledFeatures.contains(.homeWork) == true)
        #expect(savedPlace.identifier.hasPrefix("place-gym"))
        #expect(savedPlace.displayName == "Gym")
        #expect(savedPlace.latitude == 47.42310)
        #expect(savedPlace.longitude == 8.54760)
        #expect(model.fixedPlaces.count == 1)
        #expect(model.fixedPlaces.first?.displayName == "Gym")
        #expect(model.feedback?.message == "Gym added and saved.")
    }

    @Test
    func refreshPlaceSearchSuggestionsStoresSuggestionsFromService() async throws {
        let service = FakeSenseKitAppService(
            initialState: SenseKitLoadedState(configuration: RuntimeConfiguration(deviceID: "device-1")),
            nextSuggestions: [
                PlaceSearchSuggestion(
                    id: "1",
                    title: "GymOne",
                    subtitle: "Zurich",
                    query: "GymOne Zurich"
                ),
                PlaceSearchSuggestion(
                    id: "2",
                    title: "David Gym",
                    subtitle: "Oerlikon",
                    query: "David Gym Oerlikon"
                )
            ]
        )
        let model = SenseKitAppModel(service: service)

        await model.load()
        await model.refreshPlaceSearchSuggestions(query: "gym")

        let suggestionRequests = await service.suggestionRequests
        #expect(suggestionRequests == ["gym"])
        #expect(model.placeSearchSuggestions.count == 2)
        #expect(model.placeSearchSuggestions.first?.title == "GymOne")
        #expect(model.placeSearchSuggestions.first?.subtitle == "Zurich")
    }

    @Test
    func refreshPlaceSearchSuggestionsTracksLoadingStateWhileRequestRuns() async throws {
        let service = FakeSenseKitAppService(
            initialState: SenseKitLoadedState(configuration: RuntimeConfiguration(deviceID: "device-1")),
            nextSuggestions: [
                PlaceSearchSuggestion(
                    id: "1",
                    title: "GymOne",
                    subtitle: "Zurich",
                    query: "GymOne Zurich"
                )
            ],
            suggestionDelayNanoseconds: 100_000_000
        )
        let model = SenseKitAppModel(service: service)

        await model.load()
        let task = Task { await model.refreshPlaceSearchSuggestions(query: "gym") }
        await Task.yield()

        #expect(model.isLoadingPlaceSearchSuggestions)

        await task.value

        #expect(!model.isLoadingPlaceSearchSuggestions)
        #expect(model.placeSearchSuggestions.count == 1)
    }

    @Test
    func addFixedPlaceFromSuggestionUsesSuggestionResolution() async throws {
        let suggestion = PlaceSearchSuggestion(
            id: "gym-suggestion",
            title: "GymOne",
            subtitle: "Zurich",
            query: "GymOne Zurich"
        )
        let service = FakeSenseKitAppService(
            initialState: SenseKitLoadedState(configuration: RuntimeConfiguration(deviceID: "device-1")),
            nextSuggestionRegion: RegionConfiguration(
                identifier: "placeholder",
                latitude: 47.41000,
                longitude: 8.55000,
                radiusMeters: 180
            )
        )
        let model = SenseKitAppModel(service: service)

        await model.load()
        let added = await model.addFixedPlaceFromSuggestion(
            name: "Gym",
            suggestion: suggestion,
            radiusMeters: 180
        )

        let suggestionResolutionRequests = await service.suggestionResolutionRequests
        let searchRequests = await service.searchRequests
        let savedConfiguration = await service.savedConfigurations.last
        #expect(added)
        #expect(suggestionResolutionRequests.count == 1)
        #expect(suggestionResolutionRequests.first?.0 == suggestion.id)
        #expect(suggestionResolutionRequests.first?.1.hasPrefix("place-gym") == true)
        #expect(searchRequests.isEmpty)
        #expect(savedConfiguration?.fixedPlaces.first?.displayName == "Gym")
        #expect(savedConfiguration?.fixedPlaces.first?.latitude == 47.41000)
        #expect(model.feedback?.message == "Gym added and saved.")
    }

    @Test
    func refreshPlaceSearchSuggestionsClearsSuggestionsForShortQuery() async throws {
        let service = FakeSenseKitAppService(
            initialState: SenseKitLoadedState(configuration: RuntimeConfiguration(deviceID: "device-1")),
            nextSuggestions: [
                PlaceSearchSuggestion(
                    id: "1",
                    title: "GymOne",
                    subtitle: "Zurich",
                    query: "GymOne Zurich"
                )
            ]
        )
        let model = SenseKitAppModel(service: service)

        await model.load()
        await model.refreshPlaceSearchSuggestions(query: "gym")
        #expect(model.placeSearchSuggestions.count == 1)

        await model.refreshPlaceSearchSuggestions(query: "g")

        let suggestionRequests = await service.suggestionRequests
        #expect(suggestionRequests == ["gym"])
        #expect(model.placeSearchSuggestions.isEmpty)
    }

    @Test
    func refreshPlaceSearchSuggestionsMarksEmptyStateForCurrentQuery() async throws {
        let service = FakeSenseKitAppService(
            initialState: SenseKitLoadedState(configuration: RuntimeConfiguration(deviceID: "device-1"))
        )
        let model = SenseKitAppModel(service: service)

        await model.load()
        await model.refreshPlaceSearchSuggestions(query: "unknown")

        #expect(!model.isLoadingPlaceSearchSuggestions)
        #expect(model.placeSearchSuggestions.isEmpty)
        #expect(model.placeSearchSuggestionsQuery == "unknown")
    }

    @Test
    func removeFixedPlacePersistsUpdatedConfiguration() async throws {
        let service = FakeSenseKitAppService(
            initialState: SenseKitLoadedState(
                configuration: RuntimeConfiguration(
                    deviceID: "device-1",
                    enabledFeatures: [.homeWork],
                    fixedPlaces: [
                        RegionConfiguration(
                            identifier: "place-gym",
                            displayName: "Gym",
                            latitude: 47.42310,
                            longitude: 8.54760,
                            radiusMeters: 200
                        ),
                        RegionConfiguration(
                            identifier: "place-office",
                            displayName: "Office",
                            latitude: 47.37690,
                            longitude: 8.54170,
                            radiusMeters: 150
                        )
                    ]
                )
            )
        )
        let model = SenseKitAppModel(service: service)

        await model.load()
        await model.removeFixedPlace(identifier: "place-gym")

        let savedConfiguration = await service.savedConfigurations.last
        #expect(savedConfiguration?.fixedPlaces.count == 1)
        #expect(savedConfiguration?.fixedPlaces.first?.identifier == "place-office")
        #expect(model.fixedPlaces.count == 1)
        #expect(model.fixedPlaces.first?.displayName == "Office")
        #expect(model.feedback?.message == "Gym removed.")
    }

    @Test
    func refreshStateUpdatesLastStatusRefreshAt() async throws {
        let service = FakeSenseKitAppService(
            initialState: SenseKitLoadedState(configuration: RuntimeConfiguration(deviceID: "device-1"))
        )
        let model = SenseKitAppModel(service: service)

        await model.load()
        let firstRefresh = try #require(model.lastStatusRefreshAt)

        try? await Task.sleep(for: .milliseconds(20))
        await model.refreshState()

        let secondRefresh = try #require(model.lastStatusRefreshAt)
        #expect(secondRefresh >= firstRefresh)
    }

    @Test
    func filteredTimelineEntriesUsesSelectedServiceFilter() async throws {
        let service = FakeSenseKitAppService(
            initialState: SenseKitLoadedState(
                configuration: RuntimeConfiguration(deviceID: "device-1"),
                timelineEntries: [
                    DebugTimelineEntry(createdAt: Date(), category: .signal, message: "Received raw motion activity walking"),
                    DebugTimelineEntry(createdAt: Date(), category: .evaluation, message: "Location collector started"),
                    DebugTimelineEntry(createdAt: Date(), category: .evaluation, message: "Saved runtime configuration")
                ]
            )
        )
        let model = SenseKitAppModel(service: service)

        await model.load()
        model.selectedTimelineServiceFilter = .location

        #expect(model.filteredTimelineEntries.count == 1)
        #expect(model.filteredTimelineEntries.first?.message == "Location collector started")
    }

    @Test
    func availableTimelineServiceFiltersIncludeSeenServices() async throws {
        let service = FakeSenseKitAppService(
            initialState: SenseKitLoadedState(
                configuration: RuntimeConfiguration(deviceID: "device-1"),
                timelineEntries: [
                    DebugTimelineEntry(createdAt: Date(), category: .signal, message: "Received raw motion activity walking"),
                    DebugTimelineEntry(createdAt: Date(), category: .evaluation, message: "Location collector started")
                ]
            )
        )
        let model = SenseKitAppModel(service: service)

        await model.load()

        #expect(model.availableTimelineServiceFilters == [.all, .motion, .location])
    }

    @Test
    func filteredAuditEntriesUsesSelectedEventType() async throws {
        let service = FakeSenseKitAppService(
            initialState: SenseKitLoadedState(
                configuration: RuntimeConfiguration(deviceID: "device-1"),
                auditEntries: [
                    AuditLogEntry(
                        createdAt: Date(),
                        eventType: "arrived_home",
                        destination: "https://example.ts.net/hooks/sensekit",
                        status: .delivered,
                        payloadSummary: "HTTP 200",
                        retryCount: 0
                    ),
                    AuditLogEntry(
                        createdAt: Date(),
                        eventType: "motion_activity_observed",
                        destination: "https://example.ts.net/hooks/sensekit",
                        status: .delivered,
                        payloadSummary: "HTTP 200",
                        retryCount: 0
                    )
                ]
            )
        )
        let model = SenseKitAppModel(service: service)

        await model.load()
        model.selectedAuditEventType = "arrived_home"

        #expect(model.filteredAuditEntries.count == 1)
        #expect(model.filteredAuditEntries.first?.eventType == "arrived_home")
    }

    @Test
    func startupStatusTextExplainsCurrentLaunchState() async throws {
        let service = FakeSenseKitAppService(
            initialState: SenseKitLoadedState(configuration: RuntimeConfiguration(deviceID: "device-1"))
        )
        let model = SenseKitAppModel(service: service)

        #expect(model.startupTitle == "Starting SenseKit")
        #expect(model.startupMessage == "Opening the local runtime, loading saved events, and checking motion and location collectors.")

        await model.load()

        #expect(model.startupTitle == "SenseKit Ready")
    }
}

struct EntryCopyFormatterTests {
    @Test
    func auditEntryCopyTextIncludesUsefulFields() {
        let entry = AuditLogEntry(
            createdAt: Date(timeIntervalSince1970: 1_775_520_000),
            eventType: "driving_started",
            destination: "https://example.ts.net/hooks/sensekit",
            status: .delivered,
            payloadSummary: "HTTP 200",
            retryCount: 0
        )

        let text = EntryCopyFormatter.auditEntry(entry)

        #expect(text.contains("type: audit"))
        #expect(text.contains("event_type: driving_started"))
        #expect(text.contains("status: delivered"))
        #expect(text.contains("destination: https://example.ts.net/hooks/sensekit"))
        #expect(text.contains("payload_summary: HTTP 200"))
    }

    @Test
    func timelineEntryCopyTextIncludesPayloadWhenPresent() {
        let entry = DebugTimelineEntry(
            createdAt: Date(timeIntervalSince1970: 1_775_520_000),
            category: .scenario,
            message: "Manual test scenario driving_signals",
            payload: "score=0.70"
        )

        let text = EntryCopyFormatter.timelineEntry(entry)

        #expect(text.contains("type: timeline"))
        #expect(text.contains("category: scenario"))
        #expect(text.contains("message: Manual test scenario driving_signals"))
        #expect(text.contains("payload: score=0.70"))
    }

    @Test
    func timelineServiceFilterInfersLocationFromLocationMessages() {
        let entry = DebugTimelineEntry(
            createdAt: Date(timeIntervalSince1970: 1_775_520_000),
            category: .evaluation,
            message: "Location collector started"
        )

        #expect(TimelineServiceFilter.inferredService(for: entry) == .location)
    }
}

private actor FakeSenseKitAppService: SenseKitAppService {
    private var currentState: SenseKitLoadedState
    private(set) var savedConfigurations: [RuntimeConfiguration] = []
    private(set) var sentTestScenarios: [SignalTestScenario] = []
    private let currentRegionResult: RegionConfiguration?
    private let searchRegionResult: RegionConfiguration?
    private let suggestionRegionResult: RegionConfiguration?
    private let suggestionsResult: [PlaceSearchSuggestion]
    private let suggestionDelayNanoseconds: UInt64
    private(set) var captureRequests: [(String, Double)] = []
    private(set) var searchRequests: [(String, String, Double)] = []
    private(set) var suggestionRequests: [String] = []
    private(set) var suggestionResolutionRequests: [(String, String, Double)] = []

    init(
        initialState: SenseKitLoadedState,
        nextCurrentRegion: RegionConfiguration? = nil,
        nextSearchRegion: RegionConfiguration? = nil,
        nextSuggestionRegion: RegionConfiguration? = nil,
        nextSuggestions: [PlaceSearchSuggestion] = [],
        suggestionDelayNanoseconds: UInt64 = 0
    ) {
        self.currentState = initialState
        self.currentRegionResult = nextCurrentRegion
        self.searchRegionResult = nextSearchRegion
        self.suggestionRegionResult = nextSuggestionRegion
        self.suggestionsResult = nextSuggestions
        self.suggestionDelayNanoseconds = suggestionDelayNanoseconds
    }

    func loadState() async throws -> SenseKitLoadedState {
        currentState
    }

    func saveConfiguration(_ configuration: RuntimeConfiguration) async throws {
        savedConfigurations.append(configuration)
        currentState = SenseKitLoadedState(
            configuration: configuration,
            timelineEntries: currentState.timelineEntries,
            auditEntries: currentState.auditEntries
        )
    }

    func sendTestScenario(_ scenario: SignalTestScenario) async throws {
        sentTestScenarios.append(scenario)
    }

    func captureCurrentRegion(identifier: String, radiusMeters: Double) async throws -> RegionConfiguration {
        captureRequests.append((identifier, radiusMeters))
        guard let currentRegionResult else {
            throw NSError(domain: "FakeSenseKitAppService", code: 1)
        }
        return currentRegionResult
    }

    func searchRegion(query: String, identifier: String, radiusMeters: Double) async throws -> RegionConfiguration {
        searchRequests.append((identifier, query, radiusMeters))
        guard let searchRegionResult else {
            throw NSError(domain: "FakeSenseKitAppService", code: 2)
        }
        return searchRegionResult
    }

    func suggestRegions(query: String) async throws -> [PlaceSearchSuggestion] {
        suggestionRequests.append(query)
        if suggestionDelayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: suggestionDelayNanoseconds)
        }
        return suggestionsResult
    }

    func searchRegion(suggestion: PlaceSearchSuggestion, identifier: String, radiusMeters: Double) async throws -> RegionConfiguration {
        suggestionResolutionRequests.append((suggestion.id, identifier, radiusMeters))
        guard let suggestionRegionResult else {
            throw NSError(domain: "FakeSenseKitAppService", code: 3)
        }
        return suggestionRegionResult
    }

    func setNextLoadedState(_ state: SenseKitLoadedState) {
        currentState = state
    }
}
