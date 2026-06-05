import Foundation

/// Loads runtime-consumable Style Profiles that are bundled into the app as
/// `*_runtime_contract.json` resources and decodes them into the real
/// `SceneRuntimeModels.StyleProfile` contract.
///
/// Phone-test interim scope (2026-06-04, advanced plan Step 1/5): the canonical
/// source of truth for these JSON files is
/// `docs/workstreams/backend-style-profile-training/stage8_runtime_detail_expansion/`.
/// The copy under `AIPhotographer/RuntimeStyleProfiles/` is the build-time bundled
/// copy of that artifact and must stay byte-identical to it.
///
/// This is intentionally a thin loader: it only decodes the strict runtime-contract
/// projection (`SceneRuntimeModels.StyleProfile`). It does not start broader Scene
/// Runtime or Final Moment integration — callers decide how to consume the profile.
final class BundledRuntimeStyleProfileStore {
    static let shared = BundledRuntimeStyleProfileStore()

    /// Per-resource decode result, kept for provenance/logging so the device console
    /// can show which bundled profile actually decoded against the live Swift contract.
    struct DecodeOutcome {
        let resourceName: String
        let styleProfileId: String?
        let decoded: Bool
        let failureReason: String?
    }

    private let profilesById: [String: SceneRuntimeModels.StyleProfile]
    let outcomes: [DecodeOutcome]

    init(bundle: Bundle = .main) {
        var byId: [String: SceneRuntimeModels.StyleProfile] = [:]
        var outcomes: [DecodeOutcome] = []

        let runtimeContractURLs = (bundle.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? [])
            .filter { $0.lastPathComponent.hasSuffix("_runtime_contract.json") }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        let decoder = JSONDecoder()
        for url in runtimeContractURLs {
            let name = url.lastPathComponent
            do {
                let data = try Data(contentsOf: url)
                let profile = try decoder.decode(SceneRuntimeModels.StyleProfile.self, from: data)
                byId[profile.styleProfileId] = profile
                outcomes.append(
                    DecodeOutcome(resourceName: name, styleProfileId: profile.styleProfileId, decoded: true, failureReason: nil)
                )
            } catch {
                outcomes.append(
                    DecodeOutcome(resourceName: name, styleProfileId: nil, decoded: false, failureReason: String(describing: error))
                )
            }
        }

        self.profilesById = byId
        self.outcomes = outcomes
    }

    /// Returns the bundled, decoded runtime Style Profile for the given id, or `nil`
    /// when no bundled profile matches. Callers fall back to local-test defaults on nil.
    func profile(for styleProfileId: String) -> SceneRuntimeModels.StyleProfile? {
        profilesById[styleProfileId]
    }

    var loadedStyleProfileIds: [String] {
        profilesById.keys.sorted()
    }

    /// One-line provenance summary for device-console logging.
    var summary: String {
        let loaded = outcomes.filter { $0.decoded }.compactMap { $0.styleProfileId }
        let failed = outcomes.filter { !$0.decoded }.map { $0.resourceName }
        return "BundledRuntimeStyleProfileStore loaded=\(loaded) failed=\(failed)"
    }
}
