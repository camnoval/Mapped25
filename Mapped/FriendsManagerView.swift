import SwiftUI
import PhotosUI
import LinkPresentation

struct FriendsManagerView: View {
    @ObservedObject var photoLoader: PhotoLoader
    @State private var showImportPicker = false
    @State private var showNameInput = false
    @State private var pendingImportData: Data?
    @State private var newFriendName = ""
    @State private var editingFriend: FriendData?
    @State private var customizingFriend: FriendData?
    @State private var showShareSheet = false
    @State private var shareURL: URL?
    @State private var isExporting = false
    @State private var showYourCustomization = false
    
    // User's own customization
    @AppStorage("userEmoji") private var userEmoji = "🚶"
    @AppStorage("userColor") private var userColor = "#33CCBB"
    @AppStorage("userName") private var userName = "You"
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 25) {
                    // Header
                    VStack(spacing: 10) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.orange)
                        
                        Text("Friends")
                            .font(.largeTitle)
                            .bold()
                        
                        Text("Compare journeys with friends")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 30)
                    
                    // Export button section
                    VStack(spacing: 15) {
                        Button(action: exportLocationData) {
                            HStack {
                                Image(systemName: "paperplane.fill")
                                Text("Share Your Journey")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [Color.blue, Color.blue.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(15)
                            .shadow(color: .blue.opacity(0.3), radius: 5, x: 0, y: 3)
                        }
                        .disabled(photoLoader.locations.isEmpty)
                        
                        if photoLoader.locations.isEmpty {
                            Text("Load your photos first to share")
                                .font(.caption)
                                .foregroundColor(.gray)
                        } else {
                            Text("Send to friends via Messages or AirDrop")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal)
                    
                    Divider()
                        .padding(.vertical, 10)
                    
                    // Section header for friends list
                    HStack {
                        Text("Imported Friends")
                            .font(.title3)
                            .bold()
                        Spacer()
                        if !photoLoader.friends.isEmpty {
                            Text("\(photoLoader.friends.count)")
                                .font(.title3)
                                .bold()
                                .foregroundColor(.orange)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Friends list
                    if photoLoader.friends.isEmpty {
                        EmptyFriendsView()
                    } else {
                        VStack(spacing: 15) {
                            ForEach(photoLoader.friends) { friend in
                                FriendCard(
                                    friend: friend,
                                    photoLoader: photoLoader,
                                    onCustomize: { customizingFriend = friend },
                                    onDelete: { photoLoader.deleteFriend(id: friend.id) },
                                    onToggleVisibility: { photoLoader.toggleFriendVisibility(id: friend.id) }
                                )
                            }
                        }
                        .padding(.horizontal)
                        
                        // Clear all button
                        if photoLoader.friends.count > 1 {
                            Button(action: {
                                photoLoader.clearAllFriends()
                            }) {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("Clear All Friends")
                                }
                                .font(.headline)
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(15)
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    Spacer(minLength: 30)
                }
            }
            
            // Loading overlay when exporting
            if isExporting {
                Color.black.opacity(0.5)
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 20) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(2.0)
                    
                    Text("Preparing your journey...")
                        .foregroundColor(.white)
                        .font(.headline)
                    
                    Text("This may take a moment")
                        .foregroundColor(.white.opacity(0.8))
                        .font(.subheadline)
                }
                .padding(50)
                .background(Color.black.opacity(0.8))
                .cornerRadius(20)
            }
        }
        .background(Color(.systemGroupedBackground))
        .alert("Name Your Friend", isPresented: $showNameInput) {
            TextField("Friend's Name", text: $newFriendName)
            Button("Cancel", role: .cancel) {
                pendingImportData = nil
                newFriendName = ""
            }
            Button("Import") {
                importFriendWithName()
            }
            .disabled(newFriendName.trimmingCharacters(in: .whitespaces).isEmpty)
        } message: {
            Text("Give this friend a name to identify them")
        }
        .sheet(isPresented: Binding(
            get: { customizingFriend != nil },
            set: { if !$0 { customizingFriend = nil } }
        )) {
            if let friend = customizingFriend {
                FriendCustomizationSheet(
                    photoLoader: photoLoader,
                    friend: friend,
                    onSave: { updatedFriend in
                        photoLoader.updateFriend(updatedFriend)
                        customizingFriend = nil
                    }
                )
            }
        }
        .sheet(isPresented: $showYourCustomization) {
            YourCustomizationSheet(
                userName: $userName,
                userEmoji: $userEmoji,
                userColor: $userColor
            )
        }
    }

    private func exportLocationData() {
        guard !photoLoader.locations.isEmpty else {
            print("❌ No locations to export")
            return
        }
        
        let alert = UIAlertController(
            title: "What's your name?",
            message: "Your friend will see this when they import your journey",
            preferredStyle: .alert
        )
        
        alert.addTextField { textField in
            textField.placeholder = "Your Name"
            textField.text = self.userName
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        alert.addAction(UIAlertAction(title: "Share", style: .default) { _ in
            let exportName = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespaces) ?? "Friend"
            self.userName = exportName
            
            self.isExporting = true
            
            DispatchQueue.global(qos: .userInitiated).async {
                let exportableLocations = zip(self.photoLoader.locations, self.photoLoader.photoTimeStamps).map { location, timestamp in
                    ExportableLocationData.ExportableLocation(
                        latitude: location.latitude,
                        longitude: location.longitude,
                        timestamp: timestamp
                    )
                }
                
                let dateRange: ExportableLocationData.DateRange?
                if let earliest = self.photoLoader.photoTimeStamps.min(),
                   let latest = self.photoLoader.photoTimeStamps.max() {
                    dateRange = ExportableLocationData.DateRange(earliest: earliest, latest: latest)
                } else {
                    dateRange = nil
                }
                
                let journeyData = ShareableJourneyData(
                    senderName: exportName,
                    exportData: ExportableLocationData(
                        locations: exportableLocations,
                        exportDate: Date(),
                        totalLocations: self.photoLoader.locations.count,
                        dateRange: dateRange
                    )
                )
                
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                encoder.outputFormatting = .prettyPrinted
                
                guard let jsonData = try? encoder.encode(journeyData) else {
                    DispatchQueue.main.async {
                        self.isExporting = false
                    }
                    return
                }
                
                DispatchQueue.main.async {
                    self.isExporting = false
                    
                    // Create file URL
                    let tempDir = FileManager.default.temporaryDirectory
                    let fileName = "\(exportName.replacingOccurrences(of: " ", with: "_"))_Journey.mapped"
                    let fileURL = tempDir.appendingPathComponent(fileName)
                    
                    // Write file with magic header
                    var fileData = Data()
                    let magicHeader = "MAPPED_JOURNEY_V1\n".data(using: .utf8)!
                    fileData.append(magicHeader)
                    fileData.append(jsonData)
                    
                    do {
                        try? FileManager.default.removeItem(at: fileURL)
                        try fileData.write(to: fileURL, options: .atomic)
                        
                        // Create message item source
                        let messageItem = MappedMessageItem(
                            senderName: exportName,
                            locationCount: self.photoLoader.locations.count,
                            dateRange: dateRange
                        )
                        
                        // Pass BOTH the message AND the file
                        let activityVC = UIActivityViewController(
                            activityItems: [messageItem, fileURL],
                            applicationActivities: nil
                        )
                        
                        activityVC.excludedActivityTypes = [
                            .addToReadingList,
                            .assignToContact,
                            .openInIBooks
                        ]
                        
                        // Present activity view controller
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let rootVC = windowScene.windows.first?.rootViewController {
                            var topController = rootVC
                            while let presented = topController.presentedViewController {
                                topController = presented
                            }
                            topController.present(activityVC, animated: true)
                        }
                    } catch {
                        print("❌ Failed to write file: \(error)")
                    }
                }
            }
        })
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            var topController = rootVC
            while let presented = topController.presentedViewController {
                topController = presented
            }
            topController.present(alert, animated: true)
        }
    }
    
    private func handleFileImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            guard url.startAccessingSecurityScopedResource() else {
                print("❌ Failed to access file")
                return
            }
            
            defer { url.stopAccessingSecurityScopedResource() }
            
            do {
                let data = try Data(contentsOf: url)
                pendingImportData = data
                newFriendName = ""
                showNameInput = true
            } catch {
                print("❌ Failed to read file: \(error)")
            }
            
        case .failure(let error):
            print("❌ File import failed: \(error)")
        }
    }
    
    private func importFriendWithName() {
        guard let data = pendingImportData else { return }
        let name = newFriendName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        
        photoLoader.importFriend(from: data, name: name)
        
        pendingImportData = nil
        newFriendName = ""
    }
}

// MARK: - NEW: Your Customization Sheet

struct YourCustomizationSheet: View {
    @Binding var userName: String
    @Binding var userEmoji: String
    @Binding var userColor: String
    
    @State private var editedName: String
    @State private var selectedEmoji: String
    @State private var selectedColor: String
    @State private var customEmojiText: String = ""
    @State private var showImagePicker = false  // ADD THIS
    @State private var profileImage: UIImage?   // ADD THIS
    @Environment(\.dismiss) var dismiss
    
    // AppStorage for profile image
    @AppStorage("userProfileImageData") private var userProfileImageData: Data?  // ADD THIS
    
    // Quick emoji options (same as friend customization)
    let quickEmojis = [
        "⭐", "✨", "🌟", "💫", "🔥", "💥", "⚡", "🌈", "☀️", "🌙",
        "🎨", "🎭", "🎪", "🎯", "🎲", "🎮", "🎸", "🎺", "🎻", "🎹",
        "⚽", "🏀", "🏈", "⚾", "🎾", "🏐", "🏉", "🎸", "🏆", "🎀",
        "🌸", "🌺", "🌻", "🌷", "🌹", "🌴", "🌲", "🌵", "🍀", "🌿",
        "🐶", "🐱", "🐭", "🐹", "🐰", "🦊", "🐻", "🐼", "🐨", "🐯",
        "🦁", "🐮", "🐷", "🐸", "🐵", "🦆", "🦉", "🦋", "🐛", "🐞",
        "🍎", "🍊", "🍋", "🍌", "🍉", "🍇", "🍓", "🍑", "🍒", "🥥",
        "🚀", "✈️", "🚁", "🛸", "🚂", "🚗", "🚙", "🏎️", "🚕", "🚌",
        "🏠", "🏰", "🗽", "🗼", "⛺", "🏖️", "🏔️", "⛰️", "🌋", "🗻",
        "💎", "👑", "🏆", "🎖️", "🏅", "⚔️", "🛡️", "🔮", "💰", "🎓"
    ]
    
    // Predefined colors (same as friend customization)
    let colorOptions = [
        ("Red", "#FF0000"), ("Orange", "#FF8800"), ("Yellow", "#FFD700"),
        ("Green", "#00FF00"), ("Teal", "#00CCCC"), ("Blue", "#0000FF"),
        ("Purple", "#8800FF"), ("Pink", "#FF0088"), ("Magenta", "#FF00FF"),
        ("Cyan", "#00FFFF"), ("Lime", "#00FF88"), ("Coral", "#FF6666"),
        ("Indigo", "#4B0082"), ("Violet", "#8B008B"), ("Crimson", "#DC143C"),
        ("Navy", "#000080"), ("Maroon", "#800000"), ("Olive", "#808000")
    ]
    
    init(userName: Binding<String>, userEmoji: Binding<String>, userColor: Binding<String>) {
        self._userName = userName
        self._userEmoji = userEmoji
        self._userColor = userColor
        self._editedName = State(initialValue: userName.wrappedValue)
        self._selectedEmoji = State(initialValue: userEmoji.wrappedValue)
        self._selectedColor = State(initialValue: userColor.wrappedValue)
        
        if let data = UserDefaults.standard.data(forKey: "userProfileImageData"),
           let image = UIImage(data: data) {
            self._profileImage = State(initialValue: image)
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 25) {
                        // UPDATED: Preview with profile picture option
                        VStack(spacing: 15) {
                            Text("Preview")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                            
                            ZStack {
                                Circle()
                                    .fill(Color(hex: selectedColor) ?? .gray)
                                    .frame(width: 120, height: 120)
                                
                                if let image = profileImage {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 110, height: 110)
                                        .clipShape(Circle())
                                } else {
                                    Text(selectedEmoji)
                                        .font(.system(size: 50))
                                }
                                

                                VStack {
                                    Spacer()
                                    HStack {
                                        Spacer()
                                        Button(action: {
                                            showImagePicker = true
                                        }) {
                                            Image(systemName: "camera.circle.fill")
                                                .font(.system(size: 35))
                                                .foregroundColor(.white)
                                                .background(
                                                    Circle()
                                                        .fill(Color.blue)
                                                        .frame(width: 40, height: 40)
                                                )
                                        }
                                        .offset(x: 10, y: 10)
                                    }
                                }
                                .frame(width: 120, height: 120)
                            }
                            
                            if profileImage != nil {
                                Button(action: {
                                    profileImage = nil
                                }) {
                                    Text("Remove Photo")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                            
                            Text("This is how you'll appear on maps")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 20)
                        
                        // Name Section
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Display Name")
                                .font(.headline)
                            
                            TextField("Your Name", text: $editedName)
                                .textFieldStyle(.roundedBorder)
                                .font(.body)
                            
                            Text("This name will appear when you share your journey")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        
                        Divider()
                        
                        // Emoji Section
                        VStack(alignment: .leading, spacing: 15) {
                            HStack {
                                Text("Emoji")
                                    .font(.headline)
                                Spacer()
                                Text("Current: \(selectedEmoji)")
                                    .font(.title)
                            }
                            
                            // Custom emoji input
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Type Your Own Emoji")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                HStack {
                                    TextField("Enter any emoji", text: $customEmojiText)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.title)
                                        .onChange(of: customEmojiText) { newValue in
                                            if !newValue.isEmpty {
                                                let filtered = newValue.filter { $0.isEmoji }
                                                if let firstEmoji = filtered.first {
                                                    customEmojiText = String(firstEmoji)
                                                    selectedEmoji = String(firstEmoji)
                                                } else {
                                                    customEmojiText = ""
                                                }
                                            }
                                        }
                                    
                                    if !customEmojiText.isEmpty {
                                        Button(action: {
                                            customEmojiText = ""
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.gray)
                                        }
                                    }
                                }
                            }
                            
                            Text("Or Choose a Quick Emoji")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.top, 5)
                            
                            // Quick emoji grid
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 10), spacing: 8) {
                                ForEach(quickEmojis, id: \.self) { emoji in
                                    Button(action: {
                                        selectedEmoji = emoji
                                        customEmojiText = emoji
                                    }) {
                                        Text(emoji)
                                            .font(.system(size: 28))
                                            .frame(width: 40, height: 40)
                                            .background(
                                                selectedEmoji == emoji ?
                                                Color.blue.opacity(0.2) :
                                                Color(.systemGray6)
                                            )
                                            .cornerRadius(8)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        Divider()
                        
                        // Color Section
                        VStack(alignment: .leading, spacing: 15) {
                            HStack {
                                Text("Path Color")
                                    .font(.headline)
                                Spacer()
                                Circle()
                                    .fill(Color(hex: selectedColor) ?? .gray)
                                    .frame(width: 30, height: 30)
                            }
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 10) {
                                ForEach(colorOptions, id: \.1) { colorName, colorHex in
                                    Button(action: {
                                        selectedColor = colorHex
                                    }) {
                                        VStack(spacing: 5) {
                                            Circle()
                                                .fill(Color(hex: colorHex) ?? .gray)
                                                .frame(width: 44, height: 44)
                                                .overlay(
                                                    Circle()
                                                        .stroke(
                                                            selectedColor == colorHex ? Color.primary : Color.clear,
                                                            lineWidth: 3
                                                        )
                                                )
                                            
                                            Text(colorName)
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        Spacer(minLength: 30)
                    }
                }
            }
            .navigationTitle("Customize Your Appearance")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Save") {
                    saveCustomization()
                }
                .disabled(editedName.trimmingCharacters(in: .whitespaces).isEmpty)
            )
            .sheet(isPresented: $showImagePicker) {
                ImagePickerView(image: $profileImage)
            }
        }
    }
    
    private func saveCustomization() {
        userName = editedName.trimmingCharacters(in: .whitespaces)
        userEmoji = selectedEmoji
        userColor = selectedColor
        

        if let image = profileImage {
            userProfileImageData = image.jpegData(compressionQuality: 0.8)
        } else {
            userProfileImageData = nil
        }
        
        dismiss()
    }
}

// MARK: - Friend Customization Sheet

struct FriendCustomizationSheet: View {
    @ObservedObject var photoLoader: PhotoLoader
    let friend: FriendData
    let onSave: (FriendData) -> Void
    
    @State private var editedName: String
    @State private var selectedEmoji: String
    @State private var selectedColor: String
    @State private var customEmojiText: String = ""
    @State private var showImagePicker = false // CHANGED: from selectedPhoto
    @State private var profileImage: UIImage?
    @Environment(\.dismiss) var dismiss
    
    // Quick emoji options (abstract/fun - no skin tones)
    let quickEmojis = [
        "⭐", "✨", "🌟", "💫", "🔥", "💥", "⚡", "🌈", "☀️", "🌙",
        "🎨", "🎭", "🎪", "🎯", "🎲", "🎮", "🎸", "🎺", "🎻", "🎹",
        "⚽", "🏀", "🏈", "⚾", "🎾", "🏐", "🏓", "🏸", "🏑", "🏒",
        "🌸", "🌺", "🌻", "🌷", "🌹", "🌴", "🌲", "🌵", "🍀", "🌿",
        "🐶", "🐱", "🐭", "🐹", "🐰", "🦊", "🐻", "🐼", "🐨", "🐯",
        "🦁", "🐮", "🐷", "🐸", "🐵", "🦆", "🦉", "🦋", "🐛", "🐞",
        "🍎", "🍊", "🍋", "🍌", "🍉", "🍇", "🍓", "🍑", "🍒", "🥥",
        "🚀", "✈️", "🚁", "🛸", "🚂", "🚗", "🚙", "🏎️", "🚕", "🚌",
        "🏠", "🏰", "🗽", "🗼", "⛺", "🏖️", "🏔️", "⛰️", "🌋", "🗻",
        "💎", "👑", "🏆", "🎖️", "🏅", "⚔️", "🛡️", "🔮", "💰", "🎓"
    ]
    
    // Predefined colors
    let colorOptions = [
        ("Red", "#FF0000"), ("Orange", "#FF8800"), ("Yellow", "#FFD700"),
        ("Green", "#00FF00"), ("Teal", "#00CCCC"), ("Blue", "#0000FF"),
        ("Purple", "#8800FF"), ("Pink", "#FF0088"), ("Magenta", "#FF00FF"),
        ("Cyan", "#00FFFF"), ("Lime", "#00FF88"), ("Coral", "#FF6666"),
        ("Indigo", "#4B0082"), ("Violet", "#8B008B"), ("Crimson", "#DC143C"),
        ("Navy", "#000080"), ("Maroon", "#800000"), ("Olive", "#808000")
    ]
    
    init(photoLoader: PhotoLoader, friend: FriendData, onSave: @escaping (FriendData) -> Void) {
        self.photoLoader = photoLoader
        self.friend = friend
        self.onSave = onSave
        self._editedName = State(initialValue: friend.name)
        self._selectedEmoji = State(initialValue: friend.emoji)
        self._selectedColor = State(initialValue: friend.color)
        
        if let imageData = friend.profileImageData,
           let image = UIImage(data: imageData) {
            self._profileImage = State(initialValue: image)
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 25) {
                        // Profile Picture Section
                        VStack(spacing: 15) {
                            Text("Profile Picture")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                            
                            ZStack {
                                Circle()
                                    .fill(Color(hex: selectedColor) ?? .gray)
                                    .frame(width: 120, height: 120)
                                
                                if let image = profileImage {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 110, height: 110)
                                        .clipShape(Circle())
                                } else {
                                    Text(selectedEmoji)
                                        .font(.system(size: 50))
                                }
                                
                                VStack {
                                    Spacer()
                                    HStack {
                                        Spacer()
                                        Button(action: {
                                            showImagePicker = true
                                        }) {
                                            Image(systemName: "camera.circle.fill")
                                                .font(.system(size: 35))
                                                .foregroundColor(.white)
                                                .background(
                                                    Circle()
                                                        .fill(Color.blue)
                                                        .frame(width: 40, height: 40)
                                                )
                                        }
                                        .offset(x: 10, y: 10)
                                    }
                                }
                                .frame(width: 120, height: 120)
                            }
                            
                            if profileImage != nil {
                                Button(action: {
                                    profileImage = nil
                                }) {
                                    Text("Remove Photo")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        .padding(.top, 20)
                        
                        // Name Section
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Name")
                                .font(.headline)
                            
                            TextField("Friend's Name", text: $editedName)
                                .textFieldStyle(.roundedBorder)
                                .font(.body)
                        }
                        .padding(.horizontal)
                        
                        Divider()
                        
                        // Emoji Section
                        VStack(alignment: .leading, spacing: 15) {
                            HStack {
                                Text("Emoji")
                                    .font(.headline)
                                Spacer()
                                Text("Current: \(selectedEmoji)")
                                    .font(.title)
                            }
                            
                            // Custom emoji input
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Type Your Own Emoji")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                HStack {
                                    TextField("Enter any emoji", text: $customEmojiText)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.title)
                                        .onChange(of: customEmojiText) { newValue in
                                            // Only keep the first emoji character
                                            if !newValue.isEmpty {
                                                let filtered = newValue.filter { $0.isEmoji }
                                                if let firstEmoji = filtered.first {
                                                    customEmojiText = String(firstEmoji)
                                                    selectedEmoji = String(firstEmoji)
                                                } else {
                                                    customEmojiText = ""
                                                }
                                            }
                                        }
                                    
                                    if !customEmojiText.isEmpty {
                                        Button(action: {
                                            customEmojiText = ""
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.gray)
                                        }
                                    }
                                }
                            }
                            
                            Text("Or Choose a Quick Emoji")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.top, 5)
                            
                            // Quick emoji grid
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 10), spacing: 8) {
                                ForEach(quickEmojis, id: \.self) { emoji in
                                    Button(action: {
                                        selectedEmoji = emoji
                                        customEmojiText = emoji
                                    }) {
                                        Text(emoji)
                                            .font(.system(size: 28))
                                            .frame(width: 40, height: 40)
                                            .background(
                                                selectedEmoji == emoji ?
                                                Color.blue.opacity(0.2) :
                                                Color(.systemGray6)
                                            )
                                            .cornerRadius(8)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        Divider()
                        
                        // Color Section
                        VStack(alignment: .leading, spacing: 15) {
                            HStack {
                                Text("Color")
                                    .font(.headline)
                                Spacer()
                                Circle()
                                    .fill(Color(hex: selectedColor) ?? .gray)
                                    .frame(width: 30, height: 30)
                            }
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 10) {
                                ForEach(colorOptions, id: \.1) { colorName, colorHex in
                                    Button(action: {
                                        selectedColor = colorHex
                                    }) {
                                        VStack(spacing: 5) {
                                            Circle()
                                                .fill(Color(hex: colorHex) ?? .gray)
                                                .frame(width: 44, height: 44)
                                                .overlay(
                                                    Circle()
                                                        .stroke(
                                                            selectedColor == colorHex ? Color.primary : Color.clear,
                                                            lineWidth: 3
                                                        )
                                                )
                                            
                                            Text(colorName)
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        Spacer(minLength: 30)
                    }
                }
            }
            .navigationTitle("Customize Friend")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Save") {
                    saveFriend()
                }
                .disabled(editedName.trimmingCharacters(in: .whitespaces).isEmpty)
            )
            .sheet(isPresented: $showImagePicker) {
                ImagePickerView(image: $profileImage)
            }
        }
    }
    
    private func saveFriend() {
        var updatedFriend = friend
        updatedFriend.name = editedName.trimmingCharacters(in: .whitespaces)
        updatedFriend.emoji = selectedEmoji
        updatedFriend.color = selectedColor
        
        if let image = profileImage {
            updatedFriend.profileImageData = image.jpegData(compressionQuality: 0.8)
        } else {
            updatedFriend.profileImageData = nil
        }
        
        onSave(updatedFriend)
        dismiss()
    }
}

// MARK: - Character Extension for Emoji Detection

extension Character {
    var isEmoji: Bool {
        guard let scalar = unicodeScalars.first else { return false }
        return scalar.properties.isEmoji && (scalar.value > 0x238C || unicodeScalars.count > 1)
    }
}

// MARK: - iOS 15 Compatible Image Picker

struct ImagePickerView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerView
        
        init(_ parent: ImagePickerView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                let resized = resizeImage(image: image, targetSize: CGSize(width: 200, height: 200))
                parent.image = resized
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
        
        private func resizeImage(image: UIImage, targetSize: CGSize) -> UIImage {
            let size = image.size
            let widthRatio  = targetSize.width  / size.width
            let heightRatio = targetSize.height / size.height
            let scaleFactor = min(widthRatio, heightRatio)
            
            let scaledSize = CGSize(width: size.width * scaleFactor, height: size.height * scaleFactor)
            
            let renderer = UIGraphicsImageRenderer(size: scaledSize)
            let scaledImage = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: scaledSize))
            }
            
            return scaledImage
        }
    }
}

// MARK: - Empty State View

struct EmptyFriendsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 80))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No Friends Yet")
                .font(.title2)
                .bold()
                .foregroundColor(.gray)
            
            // ADDED: Clear step-by-step instructions
            VStack(alignment: .leading, spacing: 12) {
                Text("How to add a friend:")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack(alignment: .top, spacing: 12) {
                    Text("1️⃣")
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Ask your friend to share their journey")
                            .font(.subheadline)
                        Text("(They tap 'Share Your Journey' above)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack(alignment: .top, spacing: 12) {
                    Text("2️⃣")
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("They send you the .mapped file")
                            .font(.subheadline)
                        Text("(Via Messages, AirDrop, etc.)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack(alignment: .top, spacing: 12) {
                    Text("3️⃣")
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tap the file, hit the 'Open in Mapped' button and hit 'Add Friend'")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                            .bold()
                        Text("(Friend imported automatically!)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(15)
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 60)
    }
}

// MARK: - Friend Card

struct FriendCard: View {
    let friend: FriendData
    @ObservedObject var photoLoader: PhotoLoader
    let onCustomize: () -> Void
    let onDelete: () -> Void
    let onToggleVisibility: () -> Void
    
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Profile picture or emoji + color indicator
                ZStack {
                    Circle()
                        .fill(Color(hex: friend.color) ?? .red)
                        .frame(width: 50, height: 50)
                    
                    if let imageData = friend.profileImageData,
                       let image = UIImage(data: imageData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 46, height: 46)
                            .clipShape(Circle())
                    } else {
                        Text(friend.emoji)
                            .font(.system(size: 28))
                    }
                }
                
                // Name
                VStack(alignment: .leading, spacing: 2) {
                    Text(friend.name)
                        .font(.title3)
                        .bold()
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(hex: friend.color) ?? .red)
                            .frame(width: 8, height: 8)
                        Text(friend.color.uppercased())
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                // Visibility toggle
                Button(action: onToggleVisibility) {
                    Image(systemName: friend.isVisible ? "eye.fill" : "eye.slash.fill")
                        .font(.title3)
                        .foregroundColor(friend.isVisible ? .blue : .gray)
                }
                .buttonStyle(.plain)
            }
            
            // Stats
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("LOCATIONS")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(friend.locations.count)")
                        .font(.title2)
                        .bold()
                }
                
                if let dateRange = friend.dateRange {
                    Divider()
                        .frame(height: 40)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("DATE RANGE")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(formatDateRange(dateRange))
                            .font(.caption)
                            .bold()
                    }
                }
            }
            
            // Import date
            HStack {
                Image(systemName: "calendar")
                    .font(.caption)
                    .foregroundColor(.gray)
                Text("Imported \(formatDate(friend.dateImported))")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            // Actions
            HStack(spacing: 12) {
                Button(action: onCustomize) {
                    HStack {
                        Image(systemName: "paintbrush.fill")
                        Text("Customize")
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                
                Button(action: { showDeleteConfirmation = true }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete")
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .alert("Delete Friend?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Are you sure you want to delete \(friend.name)? This cannot be undone.")
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func formatDateRange(_ dateRange: ExportableLocationData.DateRange) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: dateRange.earliest)) - \(formatter.string(from: dateRange.latest))"
    }
}

// MARK: - Custom Share Item with Prepopulated Message

class MappedMessageItem: NSObject, UIActivityItemSource {
    let senderName: String
    let locationCount: Int
    let dateRange: ExportableLocationData.DateRange?
    
    init(senderName: String, locationCount: Int, dateRange: ExportableLocationData.DateRange?) {
        self.senderName = senderName
        self.locationCount = locationCount
        self.dateRange = dateRange
        super.init()
    }
    
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return generateShareMessage()
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        // Only provide text for message/mail types, nil for others (so they just get the file)
        if activityType == .message ||
           activityType == .mail ||
           activityType?.rawValue.contains("Message") == true ||
           activityType?.rawValue.contains("Mail") == true {
            return generateShareMessage()
        }
        return nil // Don't include text for AirDrop, etc.
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        return "🗺️ My 2025 Journey - \(locationCount) places!"
    }
    
    private func generateShareMessage() -> String {
        let dateString: String
        if let range = dateRange {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            dateString = "\(formatter.string(from: range.earliest)) - \(formatter.string(from: range.latest))"
        } else {
            dateString = "throughout 2025"
        }
        
        return """
        Check out my 2025 journey! I traveled to \(locationCount) places \(dateString).

        Download Mapped25 to map YOUR year with an interactive timeline, 12-photo carousel, animated collage videos, and a constellation view of everywhere you went.

        Then share your journey back so we can compare paths and compete on the leaderboard!

        Tap the attached .mapped file after downloading to add me as a friend.
        """
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?) -> String {
        return "com.novalco.mapped25.journey"
    }
   
    private func createPreviewIcon() -> UIImage {
        let size = CGSize(width: 300, height: 300)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            let ctx = context.cgContext
            
            // Gradient background
            let colors = [
                UIColor(red: 0.2, green: 0.3, blue: 0.5, alpha: 1.0).cgColor,
                UIColor(red: 0.1, green: 0.1, blue: 0.3, alpha: 1.0).cgColor
            ]
            
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                        colors: colors as CFArray,
                                        locations: [0.0, 1.0]) {
                ctx.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: 0, y: 0),
                    end: CGPoint(x: 0, y: size.height),
                    options: []
                )
            }
            
            // Large map icon
            let iconSize: CGFloat = 140
            let iconRect = CGRect(
                x: (size.width - iconSize) / 2,
                y: (size.height - iconSize) / 2 - 20,
                width: iconSize,
                height: iconSize
            )
            
            if let mapIcon = UIImage(systemName: "map.circle.fill") {
                let config = UIImage.SymbolConfiguration(pointSize: iconSize, weight: .bold)
                let configuredIcon = mapIcon.withConfiguration(config)
                configuredIcon.withTintColor(.white, renderingMode: .alwaysOriginal).draw(in: iconRect)
            }
            
            // Badge with location count
            let badgeText = "\(locationCount)"
            let badgeAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            
            let badgeSize = badgeText.size(withAttributes: badgeAttrs)
            let badgeRect = CGRect(
                x: (size.width - badgeSize.width) / 2,
                y: size.height - 60,
                width: badgeSize.width,
                height: badgeSize.height
            )
            
            badgeText.draw(in: badgeRect, withAttributes: badgeAttrs)
        }
    }
}
// MARK: - Color Extension

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

extension UIColor {
    convenience init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        
        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}
