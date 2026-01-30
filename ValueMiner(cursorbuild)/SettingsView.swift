//
//  SettingsView.swift
//  ValueMiner(cursorbuild)
//
//  Created by Michael Alfieri on 1/24/26.
//
import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions

struct SettingsView: View {
    let onSignOut: () -> Void
    
    @AppStorage("scrollReportEnabled") private var scrollReportEnabled = false
    @AppStorage("scrollReportIntervalDays") private var scrollReportIntervalDays = 7
    @AppStorage("scrollReportSendTime") private var scrollReportSendTime = Date()
    
    @State private var isHydratingSettings = true
    @State private var isSendingNow = false
    @State private var sendNowStatus: String?
    @State private var clipCount: Int = 0
    @State private var clipCountSinceLastReport: Int = 0
    @State private var lastReportDate: Date?
    @State private var showSettingsMenu = false
    
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
            .overlay(alignment: .topTrailing) {
                if showSettingsMenu {
                    ZStack(alignment: .topTrailing) {
                        Color.clear
                            .contentShape(Rectangle())
                            .frame(width: 120, height: 100)
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.15)) { showSettingsMenu = false }
                            }
                        
                        VStack(alignment: .trailing, spacing: 0) {
                            Spacer().frame(height: 50)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.15)) { showSettingsMenu = false }
                                }
                            Button(action: {
                                showSettingsMenu = false
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
                            .frame(minWidth: 90, alignment: .center)
                        }
                        .frame(width: 120, height: 100)
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 6)
                    .contentShape(Rectangle())
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .onAppear {
            loadScrollReportSettings()
            loadClipCount()
            loadClipCountSinceLastReport()
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
            
            Button(action: { withAnimation(.easeInOut(duration: 0.15)) { showSettingsMenu.toggle() } }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
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
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .frame(maxWidth: .infinity)
        .frame(height: 110)
    }
    
    private var reportCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your scroll report:")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Receive new automated email report of your saved clips per set time period:")
                .font(.footnote)
                .foregroundColor(.white.opacity(0.6))
            
            Toggle(isOn: $scrollReportEnabled) {
                Text("Enable report emails")
                    .foregroundColor(.white)
            }
            .tint(Color(red: 164/255, green: 93/255, blue: 233/255))
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Schedule")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                
                HStack(spacing: 8) {
                    Text("Every")
                        .foregroundColor(.white)
                    
                    HStack(spacing: 8) {
                        Button(action: { updateInterval(-1) }) {
                            Image(systemName: "minus")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 24, height: 24)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Circle())
                        }
                        
                        Text("\(scrollReportIntervalDays)")
                            .font(.system(size: 14, weight: .semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(8)
                        
                        Button(action: { updateInterval(1) }) {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 24, height: 24)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Circle())
                        }
                    }
                    
                    Text(scrollReportIntervalDays == 1 ? "day" : "days")
                        .foregroundColor(.white)
                }
                .disabled(!scrollReportEnabled)
                
                HStack(spacing: 8) {
                    Text("at")
                        .foregroundColor(.white)
                    DatePicker(
                        "Send time",
                        selection: $scrollReportSendTime,
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                    .disabled(!scrollReportEnabled)
                }
            }
            
            Text("Reports send to \(userEmail)")
                .font(.footnote)
                .foregroundColor(.white.opacity(0.6))
            
            Text("Includes clips mined since your last report.")
                .font(.footnote)
                .foregroundColor(.white.opacity(0.6))
            
            Button(action: sendScrollReportNow) {
                ZStack {
                    if isSendingNow {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Send current scroll report now!")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(red: 164/255, green: 93/255, blue: 233/255).opacity(0.8), lineWidth: 1)
                )
                .cornerRadius(12)
            }
            .disabled(isSendingNow)
            
            if let status = sendNowStatus {
                Text(status)
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                sendNowStatus = nil
            }
            loadClipCount()
            loadClipCountSinceLastReport()
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
}
