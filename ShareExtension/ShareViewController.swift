import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Share Extension's main view controller
@objc(ShareViewController)
class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        let rootView: AnyView
        do {
            let modelContainer = try createSharedModelContainer()
            rootView = AnyView(
                ShareExtensionView(
                    extensionContext: extensionContext
                )
                .modelContainer(modelContainer)
            )
        } catch {
            rootView = AnyView(
                ShareExtensionErrorView(message: error.localizedDescription) { [weak self] in
                    self?.extensionContext?.completeRequest(returningItems: nil)
                }
            )
        }

        let hostingController = UIHostingController(
            rootView: rootView
        )

        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        hostingController.didMove(toParent: self)
    }
}

private struct ShareExtensionErrorView: View {
    let message: String
    let dismiss: () -> Void
    @AppStorage(UserDefaultsKeys.outputLanguagePreference, store: UserDefaults(suiteName: appGroupID))
    private var outputLanguageRawValue = OutputLanguagePreference.automatic.rawValue

    private var strings: AppStrings {
        AppStrings(rawPreferenceValue: outputLanguageRawValue)
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.orange)

            Text(strings.shareExtensionUnavailableTitle)
                .font(.headline)

            Text(strings.localizedExtractionError(message))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button(strings.close, action: dismiss)
                .buttonStyle(.borderedProminent)
        }
        .padding(24)
    }
}
