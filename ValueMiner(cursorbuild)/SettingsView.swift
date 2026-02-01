






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
    
    @AppStorage("scrollReportEnabled") private var scrollReportEnabled = false
    // Default schedule interval (used when no setting exists yet)
    @AppStorage("scrollReportIntervalDays") private var scrollReportIntervalDays = 3
    @AppStorage("scrollReportSendTime") private var scrollReportSendTime = Date()
    
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
    
    // Match the mined clip cell outline style (ClipCard)
    private let outlineColor = Color(red: 164/255, green: 93/255, blue: 233/255).opacity(0.9)
    private let accentPurple = Color(red: 164/255, green: 93/255, blue: 233/255)
    
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
                            .foregroundColor(Color(red: 164/255, green: 93/255, blue: 233/255))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color.black))
                            .overlay(
                                Capsule()
                                    .stroke(Color(red: 164/255, green: 93/255, blue: 233/255).opacity(0.6), lineWidth: 1)
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
            Text("Account:")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
            Text(userEmail)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(1)
                .truncationMode(.middle)
                .minimumScaleFactor(0.7)
            Spacer()
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
                    .tint(Color(red: 164/255, green: 93/255, blue: 233/255))
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
                                    selection: $scrollReportSendTime,
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
            
            Text("Includes clips mined since your last report.")
                .font(.footnote)
                .foregroundColor(.white.opacity(0.6))
            
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
            if let sendTime = report["sendTime"] as? String {
                scrollReportSendTime = parseSendTime(sendTime) ?? scrollReportSendTime
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


