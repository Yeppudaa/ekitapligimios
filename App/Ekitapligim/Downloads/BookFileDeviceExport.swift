import SwiftUI
import UIKit
import EkitapligimCore

enum BookFileDeviceExportError: Error, Equatable {
    case sourceMissing
}

enum BookFileDeviceExport {
    private static let exportFolderName = "BookFileExports"

    static func sanitizedFileName(title: String, bookID: String, fileExtension: String) -> String {
        let ext = DownloadFilePolicy.resolvedFileExtension(for: fileExtension)
        return "\(sanitizedBaseName(title: title, bookID: bookID)).\(ext)"
    }

    static func makeExportCopy(
        from source: URL,
        title: String,
        bookID: String,
        fileExtension: String,
        fileManager: FileManager = .default
    ) throws -> URL {
        guard fileManager.fileExists(atPath: source.path) else {
            throw BookFileDeviceExportError.sourceMissing
        }
        let name = sanitizedFileName(title: title, bookID: bookID, fileExtension: fileExtension)
        let directory = try exportRoot(fileManager: fileManager)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        var excluded = directory
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? excluded.setResourceValues(values)
        let destination = directory.appendingPathComponent(name, isDirectory: false)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: source, to: destination)
        try? fileManager.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: destination.path
        )
        return destination
    }

    static func removeExportCopy(_ url: URL, fileManager: FileManager = .default) {
        let directory = url.deletingLastPathComponent().standardizedFileURL
        guard let root = try? exportRoot(fileManager: fileManager).standardizedFileURL,
              directory.deletingLastPathComponent().standardizedFileURL.path == root.path else {
            return
        }
        try? fileManager.removeItem(at: directory)
    }

    static func exportRoot(fileManager: FileManager = .default) throws -> URL {
        let caches = try fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return caches.appendingPathComponent(exportFolderName, isDirectory: true)
    }

    private static func sanitizedBaseName(title: String, bookID: String) -> String {
        let separators = CharacterSet(charactersIn: "/\\:")
            .union(.newlines)
            .union(.controlCharacters)
        let parts = title.components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: ".")) }
            .map(stripRemainingControls)
            .filter { !$0.isEmpty && $0 != "." && $0 != ".." }
        var name = parts.joined(separator: "-")
        name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        name = name.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        if name.count > 80 {
            name = String(name.prefix(80)).trimmingCharacters(in: .whitespacesAndNewlines)
            name = name.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        }
        if name.isEmpty {
            return fallbackBaseName(bookID: bookID)
        }
        return name
    }

    private static func stripRemainingControls(_ value: String) -> String {
        String(value.unicodeScalars.filter { scalar in
            !CharacterSet.controlCharacters.contains(scalar) && scalar != "\u{007F}"
        })
    }

    private static func fallbackBaseName(bookID: String) -> String {
        let allowed = bookID.filter { character in
            character.isASCII && (character.isLetter || character.isNumber || character == "-" || character == "_")
        }
        if allowed.isEmpty {
            return "kitap"
        }
        return "book-\(allowed)"
    }
}

/// Presents the system Files exporter from UIKit so it is not nested inside a SwiftUI sheet.
struct BookFileDeviceExportPresenter: UIViewControllerRepresentable {
    @Binding var fileURL: URL?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        controller.view.backgroundColor = .clear
        controller.view.isUserInteractionEnabled = false
        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        context.coordinator.fileURL = $fileURL
        context.coordinator.host = uiViewController
        context.coordinator.presentIfNeeded()
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        var fileURL: Binding<URL?>?
        weak var host: UIViewController?
        private var presentedURL: URL?
        private var isPresenting = false
        private var retryCount = 0

        func presentIfNeeded() {
            guard let url = fileURL?.wrappedValue else {
                presentedURL = nil
                isPresenting = false
                retryCount = 0
                return
            }
            guard presentedURL != url, !isPresenting else { return }
            isPresenting = true
            DispatchQueue.main.async { [weak self] in
                self?.present(url)
            }
        }

        private func present(_ url: URL) {
            guard fileURL?.wrappedValue == url else {
                isPresenting = false
                return
            }
            guard FileManager.default.fileExists(atPath: url.path) else {
                finish(cleanup: url)
                return
            }
            guard let presenter = presentationController(), presenter.presentedViewController == nil else {
                isPresenting = false
                scheduleRetry(url)
                return
            }
            presentedURL = url
            retryCount = 0
            let picker = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
            picker.shouldShowFileExtensions = true
            picker.delegate = self
            presenter.present(picker, animated: true)
        }

        private func scheduleRetry(_ url: URL) {
            retryCount += 1
            guard retryCount <= 10 else {
                finish(cleanup: url)
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
                guard self?.fileURL?.wrappedValue == url else { return }
                self?.presentIfNeeded()
            }
        }

        private func presentationController() -> UIViewController? {
            if let host {
                if let parent = host.parent, parent.view.window != nil {
                    return Self.topViewController(from: parent)
                }
                if host.view.window != nil {
                    return Self.topViewController(from: host)
                }
            }
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            let window = scenes.flatMap(\.windows).first(where: \.isKeyWindow) ?? scenes.first?.windows.first
            guard let root = window?.rootViewController else { return nil }
            return Self.topViewController(from: root)
        }

        private static func topViewController(from controller: UIViewController) -> UIViewController {
            if let presented = controller.presentedViewController {
                return topViewController(from: presented)
            }
            if let navigation = controller as? UINavigationController, let visible = navigation.visibleViewController {
                return topViewController(from: visible)
            }
            if let tab = controller as? UITabBarController, let selected = tab.selectedViewController {
                return topViewController(from: selected)
            }
            return controller
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            finish(cleanup: presentedURL)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            finish(cleanup: presentedURL)
        }

        private func finish(cleanup url: URL?) {
            presentedURL = nil
            isPresenting = false
            retryCount = 0
            if let url {
                BookFileDeviceExport.removeExportCopy(url)
            }
            fileURL?.wrappedValue = nil
        }
    }
}
