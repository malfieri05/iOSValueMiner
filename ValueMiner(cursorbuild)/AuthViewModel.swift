//
//  AuthViewModel.swift
//  ValueMiner(cursorbuild)
//
//  Created by Michael Alfieri on 1/24/26.
//

import Foundation
import Combine
import UIKit
import FirebaseAuth
import FirebaseCore
import CryptoKit
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var user: User?
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var authError: String?
    @Published var authInfo: String?

    private var listener: AuthStateDidChangeListenerHandle?

    init() {
        // Share auth session with share extension via App Group
        try? Auth.auth().useUserAccessGroup("9Q6S64UNWA.group.org.valueminer.shared")
        
        listener = Auth.auth().addStateDidChangeListener { _, user in
            self.user = user
        }
    }

    var userId: String? { user?.uid }
    var isEmailVerified: Bool { user?.isEmailVerified ?? false }

    var requiresEmailVerification: Bool {
        guard let user else { return false }
        let usesPassword = user.providerData.contains { $0.providerID == EmailAuthProviderID }
        return usesPassword && !user.isEmailVerified
    }

    func signUp() async {
        authError = nil
        authInfo = nil
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            try await result.user.sendEmailVerification()
            authInfo = "Verification email sent."
        } catch {
            showError(error.localizedDescription)
        }
    }

    func signIn() async {
        authError = nil
        authInfo = nil
        do {
            _ = try await Auth.auth().signIn(withEmail: email, password: password)
        } catch {
            showError(error.localizedDescription)
        }
    }

    func signOut() {
        authError = nil
        authInfo = nil
        do {
            try Auth.auth().signOut()
        } catch {
            showError(error.localizedDescription)
        }
    }

    func sendPasswordReset() async {
        authError = nil
        authInfo = nil
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            showError("Enter your email to reset password.")
            return
        }
        do {
            try await Auth.auth().sendPasswordReset(withEmail: trimmed)
            authInfo = "Password reset email sent."
        } catch {
            showError(error.localizedDescription)
        }
    }

    func refreshUser() async {
        authError = nil
        authInfo = nil
        do {
            try await Auth.auth().currentUser?.reload()
            self.user = Auth.auth().currentUser
        } catch {
            showError(error.localizedDescription)
        }
    }

    func resendVerificationEmail() async {
        authError = nil
        authInfo = nil
        do {
            try await Auth.auth().currentUser?.sendEmailVerification()
            authInfo = "Verification email resent."
        } catch {
            showError(error.localizedDescription)
        }
    }

    func signInWithApple(idToken: String, nonce: String, fullName: PersonNameComponents?) async {
        authError = nil
        authInfo = nil
        let credential = OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: nonce,
            fullName: fullName
        )
        do {
            _ = try await Auth.auth().signIn(with: credential)
        } catch {
            showError(error.localizedDescription)
        }
    }

    func signInWithGoogle(presenting: UIViewController) async {
        authError = nil
        authInfo = nil
        #if canImport(GoogleSignIn)
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            showError("Missing Google client ID.")
            return
        }
        let config = GIDConfiguration(clientID: clientID)
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenting, hint: nil, additionalScopes: nil, configuration: config)
            guard let idToken = result.user.idToken?.tokenString else {
                showError("Missing Google ID token.")
                return
            }
            let accessToken = result.user.accessToken.tokenString
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
            _ = try await Auth.auth().signIn(with: credential)
        } catch {
            showError(error.localizedDescription)
        }
        #else
        showError("Google Sign-In not configured.")
        #endif
    }

    func showError(_ message: String) {
        authError = message
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if authError == message {
                authError = nil
            }
        }
    }

    func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            let errorCode = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            if errorCode != errSecSuccess {
                fatalError("Unable to generate nonce. SecRandomCopyBytes failed.")
            }

            randoms.forEach { random in
                if remainingLength == 0 { return }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }

        return result
    }

    func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}
