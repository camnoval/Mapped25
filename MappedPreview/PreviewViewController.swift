//
//  PreviewViewController.swift
//  MappedPreview
//
//  Created by Noval, Cameron on 11/12/25.
//
import UIKit
import QuickLook

class PreviewViewController: UIViewController, QLPreviewingController {
    
    private var fileURL: URL?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
    }
    
    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        self.fileURL = url
        
        // Read the file
        guard let data = try? Data(contentsOf: url) else {
            handler(NSError(domain: "MappedPreview", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to read file"]))
            return
        }
        
        var jsonData = data
        
        // Strip magic header if present
        let magicHeaders = [
            "MAPPED_JOURNEY_FILE\n".data(using: .utf8)!,
            "MAPPED_JOURNEY_V1\n".data(using: .utf8)!
        ]
        
        for header in magicHeaders {
            if jsonData.starts(with: header) {
                jsonData = jsonData.dropFirst(header.count)
                break
            }
        }
        
        // CRITICAL: Validate this is actually a Mapped file
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        var senderName = "Friend"
        var locationCount = 0
        var dateRange = ""
        var isValidMappedFile = false
        
        // Try to decode with sender name
        if let journeyData = try? decoder.decode(ShareableJourneyData.self, from: jsonData) {
            senderName = journeyData.senderName
            locationCount = journeyData.exportData.totalLocations
            isValidMappedFile = true
            
            if let range = journeyData.exportData.dateRange {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                dateRange = "\(formatter.string(from: range.earliest)) - \(formatter.string(from: range.latest))"
            }
        } else if let legacyData = try? decoder.decode(ExportableLocationData.self, from: jsonData) {
            locationCount = legacyData.totalLocations
            isValidMappedFile = true
            
            if let range = legacyData.dateRange {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                dateRange = "\(formatter.string(from: range.earliest)) - \(formatter.string(from: range.latest))"
            }
        }
        
        // If this isn't a valid Mapped file, reject it
        guard isValidMappedFile else {
            handler(NSError(domain: "MappedPreview", code: -2, userInfo: [NSLocalizedDescriptionKey: "Not a valid Mapped journey file"]))
            return
        }
        
        // Create the beautiful preview UI
        createPreviewUI(senderName: senderName, locationCount: locationCount, dateRange: dateRange)
        
        handler(nil)
    }
    
    private func createPreviewUI(senderName: String, locationCount: Int, dateRange: String) {
        view.subviews.forEach { $0.removeFromSuperview() }
        
        // BOLD gradient - same as your video export background
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor(red: 0.2, green: 0.3, blue: 0.5, alpha: 1.0).cgColor,
            UIColor(red: 0.1, green: 0.1, blue: 0.3, alpha: 1.0).cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0, y: 1)
        gradientLayer.frame = view.bounds
        view.layer.insertSublayer(gradientLayer, at: 0)
        
        // Subtle particles (optional - can remove if too much)
        addFloatingCircles()
        
        // Center everything
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 20
        view.addSubview(stackView)
        
        // HUGE icon
        let iconImageView = UIImageView()
        iconImageView.image = UIImage(systemName: "map.circle.fill")
        iconImageView.tintColor = .white
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(iconImageView)
        
        // Name - BIG and BOLD
        let nameLabel = UILabel()
        nameLabel.text = senderName
        nameLabel.font = .systemFont(ofSize: 48, weight: .black)
        nameLabel.textColor = .white
        nameLabel.textAlignment = .center
        stackView.addArrangedSubview(nameLabel)
        
        // Simple tagline
        let taglineLabel = UILabel()
        taglineLabel.text = "wants to share their journey"
        taglineLabel.font = .systemFont(ofSize: 18, weight: .medium)
        taglineLabel.textColor = .white.withAlphaComponent(0.85)
        taglineLabel.textAlignment = .center
        stackView.addArrangedSubview(taglineLabel)
        
        // Single stat - just the number that matters
        let statLabel = UILabel()
        statLabel.text = "\(locationCount) locations"
        statLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        statLabel.textColor = UIColor(red: 0.4, green: 0.8, blue: 1.0, alpha: 1.0) // Light blue accent
        statLabel.textAlignment = .center
        stackView.addArrangedSubview(statLabel)
        
        // Spacer
        let spacer = UIView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(spacer)
        
        // Simple CTA at bottom
        let ctaLabel = UILabel()
        ctaLabel.text = "Tap 'Open in Mapped' below to add"
        ctaLabel.font = .systemFont(ofSize: 16, weight: .regular)
        ctaLabel.textColor = .white.withAlphaComponent(0.7)
        ctaLabel.textAlignment = .center
        stackView.addArrangedSubview(ctaLabel)
        
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            
            iconImageView.widthAnchor.constraint(equalToConstant: 120),
            iconImageView.heightAnchor.constraint(equalToConstant: 120),
            
            spacer.heightAnchor.constraint(equalToConstant: 40),
        ])
    }

    private func addFloatingCircles() {
        for i in 0..<5 { // Fewer, more subtle
            let circle = UIView()
            circle.backgroundColor = UIColor.white.withAlphaComponent(0.05)
            circle.layer.cornerRadius = CGFloat.random(in: 20...60)
            let size = circle.layer.cornerRadius * 2
            circle.frame = CGRect(
                x: CGFloat.random(in: 0...view.bounds.width),
                y: CGFloat.random(in: 0...view.bounds.height),
                width: size,
                height: size
            )
            view.addSubview(circle)
            
            UIView.animate(
                withDuration: Double.random(in: 4...8),
                delay: Double(i) * 0.3,
                options: [.repeat, .autoreverse, .curveEaseInOut],
                animations: {
                    circle.transform = CGAffineTransform(translationX: CGFloat.random(in: -40...40), y: CGFloat.random(in: -60...60))
                }
            )
        }
    }

    
    @objc private func openInMapped() {
        guard let url = fileURL else { return }
        
        do {
            let data = try Data(contentsOf: url)
            
            // Store the data in shared UserDefaults (this DOES work in Quick Look extensions)
            if let sharedDefaults = UserDefaults(suiteName: "group.com.novalco.mapped") {
                // Convert data to base64 string for storage
                let base64String = data.base64EncodedString()
                sharedDefaults.set(base64String, forKey: "pendingImportData")
                sharedDefaults.set(url.lastPathComponent, forKey: "pendingImportFilename")
                sharedDefaults.synchronize()
                
                print("✅ Saved data to shared defaults (\(data.count) bytes)")
                
                // Open main app with custom URL scheme
                if let appURL = URL(string: "mapped://import") {
                    extensionContext?.open(appURL, completionHandler: { success in
                        print(success ? "✅ Opened main app" : "❌ Failed to open main app")
                    })
                }
            } else {
                print("❌ Failed to get shared UserDefaults")
            }
        } catch {
            print("❌ Failed to process file: \(error)")
        }
    }
}

// MARK: - Data Models (copy from your existing code)

struct ShareableJourneyData: Codable {
    let senderName: String
    let exportData: ExportableLocationData
}

struct ExportableLocationData: Codable {
    let locations: [ExportableLocation]
    let exportDate: Date
    let totalLocations: Int
    let dateRange: DateRange?
    
    struct ExportableLocation: Codable {
        let latitude: Double
        let longitude: Double
        let timestamp: Date
    }
    
    struct DateRange: Codable {
        let earliest: Date
        let latest: Date
    }
}

