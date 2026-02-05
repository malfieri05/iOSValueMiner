






import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import UIKit

private struct DayNumberAnchorKey: PreferenceKey {
    static var defaultValue: Anchor<CGPoint>? = nil
    static func reduce(value: inout Anchor<CGPoint>?, nextValue: () -> Anchor<CGPoint>?) {
        value = nextValue() ?? value
    }
}

private struct AtLabelWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct FloatingPrimaryButtonStyle: ButtonStyle {
    let fill: Color
    let border: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(fill)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(border, lineWidth: 1)
            )
            .cornerRadius(12)
            // Subtle depth / "floating" effect
            .shadow(color: Color.black.opacity(configuration.isPressed ? 0.18 : 0.30), radius: configuration.isPressed ? 8 : 14, x: 0, y: configuration.isPressed ? 3 : 7)
            .shadow(color: fill.opacity(configuration.isPressed ? 0.12 : 0.18), radius: configuration.isPressed ? 6 : 10, x: 0, y: 0)
            // Press feel
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct SettingsView: View {
    let onSignOut: () -> Void
    let subscriptionManager: SubscriptionManager
    
    @AppStorage("scrollReportEnabled") private var scrollReportEnabled = false
    // Default schedule interval (used when no setting exists yet)
    @AppStorage("scrollReportIntervalDays") private var scrollReportIntervalDays = 3
    @AppStorage("scrollReportSendTimeInterval") private var scrollReportSendTimeInterval = Date().timeIntervalSince1970
    
    @State private var isHydratingSettings = true
    @State private var isSendingNow = false
    @State private var sendNowStatus: String?
    @State private var clipCount: Int = 0
    @State private var clipCountSinceLastReport: Int = 0
    @State private var lastReportDate: Date?
    @State private var clipCreatedAt: [Timestamp] = []
    @State private var clipsListener: ListenerRegistration?
    @State private var userDocListener: ListenerRegistration?
    @State private var showSettingsMenu = false
    @State private var atLabelWidth: CGFloat = 0
    @State private var showShareSheetHelp = false
    @State private var showColorPicker = false
    @State private var showPaywallPreview = false
    @State private var showLanguagePicker = false
    @State private var showDeleteAccountConfirm = false
    @State private var isDeletingAccount = false
    @State private var deleteAccountStatus: String?
    @State private var showAccountSheet = false
    @State private var newAccountEmail = ""
    @State private var accountStatus: String?
    @State private var isUpdatingAccount = false
    @AppStorage("themeAccent") private var themeAccent = ThemeColors.defaultAccent
    @AppStorage("transcriptLanguage") private var transcriptLanguage = "en"
    
    // Match the mined clip cell outline style (ClipCard)
    private var outlineColor: Color { ThemeColors.color(from: themeAccent).opacity(0.9) }
    private var accentPurple: Color { ThemeColors.color(from: themeAccent) }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerRow
                    .background(Color.black)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        accountEmailBar
                            .padding(.horizontal, 16)
                        
                        HStack(spacing: 12) {
                            totalClipsCard
                            sinceLastReportCard
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 24)
                        .padding(.bottom, 24)
                        
                        reportCard
                        subscriptionCard
                        languageCard
                        accountManagementCard
                    }
                    .padding(.bottom, 24)
                }
            }
        }
        .onAppear {
            // Defensive: if AppStorage gets corrupted or a wrong type is written,
            // ensure we always show a valid interval (and the UI never renders blank).
            if scrollReportIntervalDays < 1 || scrollReportIntervalDays > 7 {
                scrollReportIntervalDays = 3
            }
            loadScrollReportSettings()
            startLiveClipListeners()
        }
        .onDisappear {
            stopLiveClipListeners()
        }
        .onChange(of: scrollReportEnabled) { _, _ in
            persistScrollReportSettings()
        }
        .onChange(of: scrollReportIntervalDays) { _, _ in
            persistScrollReportSettings()
        }
        .onChange(of: scrollReportSendTime) { _, _ in
            persistScrollReportSettings()
        }
    }
    
    private var headerRow: some View {
        HStack {
            Text("Profile")
                .font(.title2).bold()
                .foregroundColor(.white)
            
            Spacer()

            // Gear with "Sign out" pill that expands to the LEFT
            ZStack(alignment: .trailing) {
                if showSettingsMenu {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) { showSettingsMenu = false }
                        onSignOut()
                    }) {
                        Text("Sign out")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(accentPurple)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color.black))
                            .overlay(
                                Capsule()
                                    .stroke(accentPurple.opacity(0.6), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    // Place it to the left of the gear with a small gap
                    .offset(x: -54)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }

                Button(action: { withAnimation(.easeInOut(duration: 0.15)) { showSettingsMenu.toggle() } }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 16)
        .onTapGesture {
            if showSettingsMenu {
                withAnimation(.easeInOut(duration: 0.15)) {
                    showSettingsMenu = false
                }
            }
        }
    }
    
    private var accountEmailBar: some View {
        HStack(spacing: 6) {
            Button(action: { showAccountSheet = true }) {
                HStack(spacing: 6) {
                    Text("Account:")
                        .font(.system(size: 13, weight: .semibold))
                    Text(userEmail)
                        .font(.system(size: 13, weight: .regular))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .minimumScaleFactor(0.7)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.06))
                .cornerRadius(999)
            }
            Spacer()
            Button(action: { showColorPicker = true }) {
                Text("Color")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(accentPurple)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(10)
            }
            Button(action: { showShareSheetHelp = true }) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(accentPurple)
                    .padding(6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(outlineColor, lineWidth: 1.2)
        )
        .cornerRadius(16)
        .sheet(isPresented: $showShareSheetHelp) {
            ShareSheetOnboardingView(onDismiss: {
                showShareSheetHelp = false
            }, allowsEarlyDismiss: true)
        }
        .sheet(isPresented: $showColorPicker) {
            ThemeColorPicker(selectedAccent: $themeAccent)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showAccountSheet) {
            AccountSettingsSheet(
                currentEmail: userEmail,
                newEmail: $newAccountEmail,
                status: $accountStatus,
                isUpdating: $isUpdatingAccount,
                onUpdateEmail: updateAccountEmail,
                onResetPassword: sendPasswordResetEmail
            )
            .presentationDetents([.medium])
        }
    }
    
    private var totalClipsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Total saved clips:")
                .font(.headline)
                .foregroundColor(.white)
            
            Spacer()
            
            Text("\(clipCount)")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .center)
            
            Spacer()
        }
        .padding(16)
        .background(Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(outlineColor, lineWidth: 1.2)
        )
        .cornerRadius(16)
        .frame(maxWidth: .infinity)
        .frame(height: 110)
    }

    private var subscriptionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Subscription")
                .font(.headline)
                .foregroundColor(.white)

            HStack {
                Text("Current plan:")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Text(currentPlanLabel)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.white.opacity(0.8))
            }

            Button(action: openManageSubscriptions) {
                HStack(spacing: 8) {
                    Image(systemName: "creditcard.fill")
                    Text("Manage Subscription")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(accentPurple)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.06))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(accentPurple.opacity(0.6), lineWidth: 1)
                )
            }

            Button(action: { showPaywallPreview = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                    Text("Preview Paywall")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.white.opacity(0.85))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.04))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
            }
        }
        .padding(16)
        .background(Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(outlineColor, lineWidth: 1.2)
        )
        .cornerRadius(16)
        .padding(.horizontal, 16)
        .sheet(isPresented: $showPaywallPreview) {
            PaywallView(subscriptionManager: subscriptionManager)
                .presentationDetents([.medium])
        }
    }
    
    private var sinceLastReportCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Since last report:")
                .font(.headline)
                .foregroundColor(.white)
            
            Spacer()
            
            Text("\(clipCountSinceLastReport)")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .center)
            
            Spacer()
        }
        .padding(16)
        .background(Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(outlineColor, lineWidth: 1.2)
        )
        .cornerRadius(16)
        .frame(maxWidth: .infinity)
        .frame(height: 110)
    }
    
    private var reportCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your scroll report:")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .underline(true, color: .white)
            
            Text("Receive new automated email report of your saved clips per set time period:")
                .font(.footnote)
                .foregroundColor(.white.opacity(0.6))

            // Toggle row: label (smaller/gray) + toggle on same line
            HStack(spacing: 12) {
                Text("Enable report emails:")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Toggle("", isOn: $scrollReportEnabled)
                    .labelsHidden()
                .tint(accentPurple)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Schedule:")
                    .font(.headline)
                    .foregroundColor(.white)
                    .underline(true, color: .white)

                // Centered schedule controls with no truncation ("...") ever.
                VStack(spacing: 12) {
                    HStack {
                        Spacer(minLength: 0)
                        HStack(spacing: 10) {
                            Text("Every")
                                .foregroundColor(.white)
                                .fixedSize(horizontal: true, vertical: false)

                            Button(action: { updateInterval(-1) }) {
                                Image(systemName: "minus")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(accentPurple)
                                    .frame(width: 29, height: 29) // +10% bigger
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(Circle())
                            }
                            .simultaneousGesture(TapGesture().onEnded { lightHaptic() })

                            Text("\(scrollReportIntervalDays)")
                                .font(.system(size: 16, weight: .semibold)) // +10% bigger
                                .foregroundColor(.white)
                                .monospacedDigit()
                                .frame(minWidth: 32, alignment: .center) // +10% bigger
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(8)
                                // Capture the center of the day-number pill so we can
                                // center the time picker directly underneath it.
                                .anchorPreference(key: DayNumberAnchorKey.self, value: .center) { $0 }

                            Button(action: { updateInterval(1) }) {
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(accentPurple)
                                    .frame(width: 29, height: 29) // +10% bigger
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(Circle())
                            }
                            .simultaneousGesture(TapGesture().onEnded { lightHaptic() })

                            Text("day(s)")
                                .foregroundColor(.white)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .fixedSize(horizontal: true, vertical: false)
                        Spacer(minLength: 0)
                    }

                    // Reserve vertical space; we position the time picker via the anchor.
                    Color.clear.frame(height: 34)
                }
                .overlayPreferenceValue(DayNumberAnchorKey.self) { anchor in
                    GeometryReader { proxy in
                        if let anchor {
                            let p = proxy[anchor]
                            // Keep the time picker horizontally fixed at p.x, and place "at"
                            // immediately to its left without shifting the picker.
                            // Strategy:
                            // - Render as HStack("at", DatePicker)
                            // - Position the *HStack* such that the DatePicker's center remains at p.x
                            //   (i.e. HStack center is shifted left by (atWidth + spacing)/2).
                            HStack(spacing: 8) {
                                Text("at")
                                    .foregroundColor(.white)
                                    .font(.footnote)
                                    .background(
                                        GeometryReader { g in
                                            Color.clear.preference(key: AtLabelWidthKey.self, value: g.size.width)
                                        }
                                    )
                                    .onPreferenceChange(AtLabelWidthKey.self) { atLabelWidth = $0 }

                    DatePicker(
                        "Send time",
                        selection: Binding(
                            get: { Date(timeIntervalSince1970: scrollReportSendTimeInterval) },
                            set: { scrollReportSendTimeInterval = $0.timeIntervalSince1970 }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                                .labelsHidden()
                                .datePickerStyle(.compact)
                            }
                            .fixedSize()
                            // Ensure the "at" text stays visible above the picker.
                            .zIndex(2)
                            // Keep the DatePicker's horizontal position fixed at p.x.
                            .position(x: p.x - (atLabelWidth + 8) / 2, y: p.y + 44)
                        }
                    }
                }
                .disabled(!scrollReportEnabled)
            }
            
            Text("Reports send to \(userEmail)")
                .font(.footnote)
                .foregroundColor(.white.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .center)
            
            Text("Includes clips mined since your last report.")
                .font(.footnote)
                .foregroundColor(.white.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .center)
            
            Button {
                lightHaptic()
                sendScrollReportNow()
            } label: {
                ZStack {
                    if isSendingNow {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Send current report now!")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.black)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(FloatingPrimaryButtonStyle(fill: accentPurple, border: accentPurple.opacity(0.95)))
            .padding(.top, 10)
            .disabled(isSendingNow)
            
            if let status = sendNowStatus {
                Text(status)
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(16)
        .background(Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(outlineColor, lineWidth: 1.2)
        )
        .cornerRadius(16)
        .padding(.horizontal, 16)
    }

    private var languageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Transcription Language")
                .font(.headline)
                .foregroundColor(.white)

            HStack {
                Text("Current:")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Text(languageName(for: transcriptLanguage))
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.white.opacity(0.8))
            }

            Button(action: { showLanguagePicker = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "globe")
                    Text("Choose Language")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(accentPurple)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.06))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(accentPurple.opacity(0.6), lineWidth: 1)
                )
            }
        }
        .padding(16)
        .background(Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(outlineColor, lineWidth: 1.2)
        )
        .cornerRadius(16)
        .padding(.horizontal, 16)
        .sheet(isPresented: $showLanguagePicker) {
            LanguagePickerView(
                selectedLanguage: $transcriptLanguage,
                options: languageOptions
            )
            .presentationDetents([.medium, .large])
        }
    }

    private var accountManagementCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Account Management")
                .font(.headline)
                .foregroundColor(.white)

            Button(role: .destructive, action: { showDeleteAccountConfirm = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "trash")
                    Text(isDeletingAccount ? "Deleting..." : "Delete Account")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.red)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.06))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.red.opacity(0.6), lineWidth: 1)
                )
            }
            .disabled(isDeletingAccount)

            if let status = deleteAccountStatus {
                Text(status)
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(16)
        .background(Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(outlineColor, lineWidth: 1.2)
        )
        .cornerRadius(16)
        .padding(.horizontal, 16)
        .alert("Delete account?", isPresented: $showDeleteAccountConfirm) {
            Button("Delete", role: .destructive) {
                deleteAccount()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete your account and all saved clips.")
        }
    }

    private var currentPlanLabel: String {
        switch subscriptionManager.currentTier {
        case .free: return "Free"
        case .starter: return "Starter"
        case .silver: return "Silver"
        case .gold: return "Gold"
        }
    }

    private func openManageSubscriptions() {
        guard let url = URL(string: "https://apps.apple.com/account/subscriptions") else { return }
        UIApplication.shared.open(url)
    }

    private var languageOptions: [(code: String, name: String)] {
        [
            ("en", "English"),
            ("es", "Spanish"),
            ("fr", "French"),
            ("de", "German"),
            ("it", "Italian"),
            ("pt", "Portuguese"),
            ("nl", "Dutch"),
            ("sv", "Swedish"),
            ("da", "Danish"),
            ("no", "Norwegian"),
            ("fi", "Finnish"),
            ("pl", "Polish"),
            ("cs", "Czech"),
            ("tr", "Turkish"),
            ("ru", "Russian"),
            ("uk", "Ukrainian"),
            ("ar", "Arabic"),
            ("he", "Hebrew"),
            ("hi", "Hindi"),
            ("id", "Indonesian"),
            ("ms", "Malay"),
            ("th", "Thai"),
            ("vi", "Vietnamese"),
            ("ja", "Japanese"),
            ("ko", "Korean"),
            ("zh", "Chinese"),
            ("el", "Greek")
        ]
    }

    private func languageName(for code: String) -> String {
        languageOptions.first(where: { $0.code == code })?.name ?? "English"
    }

    private func deleteAccount() {
        guard let user = Auth.auth().currentUser else {
            deleteAccountStatus = "No signed-in user."
            return
        }
        isDeletingAccount = true
        deleteAccountStatus = nil
        Task {
            do {
                if let uid = userId {
                    try await deleteUserData(userId: uid)
                }
                try await user.delete()
                deleteAccountStatus = "Account deleted."
            } catch {
                let nsError = error as NSError
                if nsError.code == AuthErrorCode.requiresRecentLogin.rawValue {
                    deleteAccountStatus = "Please sign out and sign back in, then try again."
                } else {
                    deleteAccountStatus = "Failed to delete account."
                }
                print("Delete account error:", error)
            }
            isDeletingAccount = false
        }
    }

    private func deleteUserData(userId: String) async throws {
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(userId)

        // Delete clips
        let clipsSnapshot = try await userRef.collection("clips").getDocuments()
        for doc in clipsSnapshot.documents {
            try await doc.reference.delete()
        }

        // Delete categories
        let categoriesSnapshot = try await userRef.collection("categories").getDocuments()
        for doc in categoriesSnapshot.documents {
            try await doc.reference.delete()
        }

        // Delete user document
        try await userRef.delete()
    }

    private func updateAccountEmail() {
        let trimmed = newAccountEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            accountStatus = "Enter a new email address."
            return
        }
        guard let user = Auth.auth().currentUser else {
            accountStatus = "No signed-in user."
            return
        }

        isUpdatingAccount = true
        accountStatus = nil
        Task {
            do {
                try await user.updateEmail(to: trimmed)
                accountStatus = "Email updated."
            } catch {
                let nsError = error as NSError
                if nsError.code == AuthErrorCode.requiresRecentLogin.rawValue {
                    accountStatus = "Please sign out and sign back in, then try again."
                } else {
                    accountStatus = "Failed to update email."
                }
                print("Update email error:", error)
            }
            isUpdatingAccount = false
        }
    }

    private func sendPasswordResetEmail() {
        let email = userEmail
        guard !email.isEmpty else {
            accountStatus = "No email on file."
            return
        }
        isUpdatingAccount = true
        accountStatus = nil
        Task {
            do {
                try await Auth.auth().sendPasswordReset(withEmail: email)
                accountStatus = "Password reset email sent."
            } catch {
                accountStatus = "Failed to send reset email."
                print("Password reset error:", error)
            }
            isUpdatingAccount = false
        }
    }
    
    private var userEmail: String {
        Auth.auth().currentUser?.email ?? "Signed in"
    }
    
    private var userId: String? {
        Auth.auth().currentUser?.uid
    }
    
    private func sendScrollReportNow() {
        guard !isSendingNow else { return }
        guard userId != nil else {
            sendNowStatus = "Please sign in to send reports."
            return
        }
        
        isSendingNow = true
        sendNowStatus = nil
        
        let callable = Functions.functions().httpsCallable("sendScrollReportNow")
        callable.call(["source": "manual"]) { result, error in
            isSendingNow = false
            if let error = error {
                sendNowStatus = "Failed to send report."
                print("Send report error:", error)
                return
            }
            sendNowStatus = "Report sent."
            // Immediately reflect that a report was just sent:
            // - Reset "Since last report" to 0 in the UI
            // - Set lastReportDate so subsequent queries treat "now" as the new baseline
            lastReportDate = Date()
            updateCountsFromCache()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                sendNowStatus = nil
            }
            print("Send report result:", result?.data ?? "")
        }
    }
    
    private func loadScrollReportSettings() {
        guard let uid = userId else { return }
        let docRef = Firestore.firestore().collection("users").document(uid)
        docRef.getDocument { snapshot, error in
            if let error = error {
                print("Load scroll report settings error:", error)
                return
            }
            
            guard let data = snapshot?.data(),
                  let report = data["scrollReport"] as? [String: Any] else {
                isHydratingSettings = false
                return
            }
            
            if let enabled = report["enabled"] as? Bool {
                scrollReportEnabled = enabled
            }
            if let interval = report["intervalDays"] as? Int {
                scrollReportIntervalDays = min(max(interval, 1), 7)
            }
            if let sendTime = report["sendTime"] as? String,
               let parsed = parseSendTime(sendTime) {
                scrollReportSendTimeInterval = parsed.timeIntervalSince1970
            }
            if let lastSent = report["lastSentAt"] as? Timestamp {
                lastReportDate = lastSent.dateValue()
            } else {
                lastReportDate = nil
            }
            
            isHydratingSettings = false
        }
    }
    
    private func loadClipCount() {
        guard let uid = userId else { return }
        Firestore.firestore()
            .collection("users")
            .document(uid)
            .collection("clips")
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Load clip count error:", error)
                    return
                }
                let docs = snapshot?.documents ?? []
                clipCount = docs.filter { isValidClipData($0.data()) }.count
            }
    }
    
    private func loadClipCountSinceLastReport() {
        guard let uid = userId else { return }
        guard let lastReportDate else {
            clipCountSinceLastReport = clipCount
            return
        }
        
        Firestore.firestore()
            .collection("users")
            .document(uid)
            .collection("clips")
            .whereField("createdAt", isGreaterThan: Timestamp(date: lastReportDate))
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Load clip count since last report error:", error)
                    return
                }
                let docs = snapshot?.documents ?? []
                clipCountSinceLastReport = docs.filter { isValidClipData($0.data()) }.count
            }
    }

    private func startLiveClipListeners() {
        guard let uid = userId else { return }
        stopLiveClipListeners()

        clipsListener = Firestore.firestore()
            .collection("users")
            .document(uid)
            .collection("clips")
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Live clip listener error:", error)
                    return
                }
                let docs = snapshot?.documents ?? []
                clipCreatedAt = docs.compactMap { doc in
                    let data = doc.data()
                    guard isValidClipData(data), let createdAt = data["createdAt"] as? Timestamp else {
                        return nil
                    }
                    return createdAt
                }
                updateCountsFromCache()
            }

        userDocListener = Firestore.firestore()
            .collection("users")
            .document(uid)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Live user doc listener error:", error)
                    return
                }
                guard let data = snapshot?.data(),
                      let report = data["scrollReport"] as? [String: Any]
                else { return }

                let newLastReportDate: Date?
                if let lastSent = report["lastSentAt"] as? Timestamp {
                    newLastReportDate = lastSent.dateValue()
                } else {
                    newLastReportDate = nil
                }

                if newLastReportDate != lastReportDate {
                    lastReportDate = newLastReportDate
                    updateCountsFromCache()
                }
            }
    }

    private func stopLiveClipListeners() {
        clipsListener?.remove()
        clipsListener = nil
        userDocListener?.remove()
        userDocListener = nil
    }

    private func updateCountsFromCache() {
        clipCount = clipCreatedAt.count
        guard let lastReportDate else {
            clipCountSinceLastReport = clipCount
            return
        }
        let sinceCount = clipCreatedAt.filter { $0.dateValue() > lastReportDate }.count
        clipCountSinceLastReport = sinceCount
    }
    
    private func isValidClipData(_ data: [String: Any]) -> Bool {
        let url = data["url"] as? String
        let transcript = data["transcript"] as? String
        let category = data["category"] as? String
        let platform = data["platform"] as? String
        let createdAt = data["createdAt"] as? Timestamp
        return url != nil && transcript != nil && category != nil && platform != nil && createdAt != nil
    }
    
    private func persistScrollReportSettings() {
        guard !isHydratingSettings else { return }
        guard let uid = userId else { return }
        
        let sendTime = formatSendTime(scrollReportSendTime)
        var payload: [String: Any] = [
            "scrollReport": [
                "enabled": scrollReportEnabled,
                "intervalDays": scrollReportIntervalDays,
                "sendTime": sendTime,
                "timeZone": TimeZone.current.identifier,
                "updatedAt": Timestamp(date: Date())
            ]
        ]
        if let email = Auth.auth().currentUser?.email {
            payload["email"] = email
        }
        
        Firestore.firestore()
            .collection("users")
            .document(uid)
            .setData(payload, merge: true) { error in
                if let error = error {
                    print("Save scroll report settings error:", error)
                }
            }
    }
    
    private func formatSendTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    private func parseSendTime(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        guard let date = formatter.date(from: value) else { return nil }
        
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return calendar.date(
            bySettingHour: components.hour ?? 9,
            minute: components.minute ?? 0,
            second: 0,
            of: now
        )
    }

    private var scrollReportSendTime: Date {
        get { Date(timeIntervalSince1970: scrollReportSendTimeInterval) }
        set { scrollReportSendTimeInterval = newValue.timeIntervalSince1970 }
    }
    
    private func updateInterval(_ delta: Int) {
        let next = scrollReportIntervalDays + delta
        scrollReportIntervalDays = min(max(next, 1), 7)
    }

    private func lightHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }
}

private struct AccountSettingsSheet: View {
    let currentEmail: String
    @Binding var newEmail: String
    @Binding var status: String?
    @Binding var isUpdating: Bool
    let onUpdateEmail: () -> Void
    let onResetPassword: () -> Void
    @AppStorage("themeAccent") private var themeAccent = ThemeColors.defaultAccent

    private var accentColor: Color { ThemeColors.color(from: themeAccent) }

    var body: some View {
        ZStack {
            Color.clear.ignoresSafeArea()
            VStack(spacing: 16) {
                Text("Account Settings")
                    .font(.headline)
                    .foregroundColor(.white)

                Text("Current email: \(currentEmail)")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .center)

                TextField("New email address", text: $newEmail)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .padding(12)
                    .background(Color.white.opacity(0.12))
                    .foregroundColor(.white)
                    .cornerRadius(12)

                Button(action: onUpdateEmail) {
                    Text(isUpdating ? "Updating..." : "Update Email")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundColor(.white)
                        .background(Color.white.opacity(0.18))
                        .cornerRadius(12)
                }
                .disabled(isUpdating)

                Button(action: onResetPassword) {
                    Text("Send Password Reset")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundColor(.white)
                        .background(Color.white.opacity(0.14))
                        .cornerRadius(12)
                }
                .disabled(isUpdating)

                if let status = status {
                    Text(status)
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.8))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(accentColor.opacity(0.7), lineWidth: 1)
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
    }
}

private struct ThemeColorPicker: View {
    @Binding var selectedAccent: String
    private let columns = [GridItem(.adaptive(minimum: 70), spacing: 12)]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 16) {
                Text("Choose Color Theme")
                    .font(.headline)
                    .foregroundColor(.white)

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(ThemeColors.options, id: \.id) { option in
                        Button(action: {
                            selectedAccent = option.id.rawValue
                        }) {
                            VStack(spacing: 8) {
                                Circle()
                                    .fill(option.color)
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.35), lineWidth: 1)
                                    )
                                    .overlay(
                                        Group {
                                            if selectedAccent == option.id.rawValue {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 14, weight: .bold))
                                                    .foregroundColor(.white)
                                            }
                                        }
                                    )
                                Text(option.name)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.85))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.04))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer()
            }
            .padding(20)
        }
    }
}


