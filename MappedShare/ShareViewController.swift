import UIKit
import Social

class ShareViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Immediately try to process the file
        processSharedFile()
    }
    
    private func processSharedFile() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let itemProvider = extensionItem.attachments?.first else {
            completeWithError("No file found")
            return
        }
        
        // Try to load as file URL
        if itemProvider.hasItemConformingToTypeIdentifier("public.file-url") {
            itemProvider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { [weak self] (item, error) in
                if let error = error {
                    self?.completeWithError("Error loading file: \(error.localizedDescription)")
                    return
                }
                
                guard let url = item as? URL else {
                    self?.completeWithError("Invalid file")
                    return
                }
                
                // Only handle .mapped files
                guard url.pathExtension.lowercased() == "mapped" else {
                    self?.completeWithError("Please select a .mapped file")
                    return
                }
                
                // Read the file
                guard let data = try? Data(contentsOf: url) else {
                    self?.completeWithError("Could not read file")
                    return
                }
                
                // Store in shared container
                if let sharedDefaults = UserDefaults(suiteName: "group.com.novalco.mapped") {
                    let base64String = data.base64EncodedString()
                    sharedDefaults.set(base64String, forKey: "pendingImportData")
                    sharedDefaults.set(url.lastPathComponent, forKey: "pendingImportFilename")
                    sharedDefaults.synchronize()
                    
                    print("✅ Share Extension: Stored \(data.count) bytes")
                    
                    // Open main app
                    DispatchQueue.main.async {
                        self?.openMainApp()
                        
                        // Show success and close
                        self?.showSuccessAndClose()
                    }
                } else {
                    self?.completeWithError("Could not access app storage")
                }
            }
        } else {
            completeWithError("File type not supported")
        }
    }
    
    private func openMainApp() {
        // Try to open the main app using the custom URL scheme
        guard let appURL = URL(string: "mapped://import") else { return }
        
        // Use the extension context to open the URL
        _ = self.openURL(url: appURL)
    }
    
    @objc private func openURL(url: URL) -> Bool {
        var responder: UIResponder? = self
        while let r = responder {
            if let application = r as? UIApplication {
                if application.canOpenURL(url) {
                    application.open(url, options: [:], completionHandler: nil)
                    return true
                }
            }
            responder = r.next
        }
        return false
    }
    
    private func showSuccessAndClose() {
        let alert = UIAlertController(
            title: "Opening Mapped",
            message: "Your friend's journey is being imported!",
            preferredStyle: .alert
        )
        
        present(alert, animated: true) {
            // Auto-dismiss after 1 second
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
            }
        }
    }
    
    private func completeWithError(_ message: String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(
                title: "Cannot Import",
                message: message,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
            })
            self.present(alert, animated: true)
        }
    }
}
