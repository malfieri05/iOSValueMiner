//
//  AuthViewModel.swift
//  ValueMiner(cursorbuild)
//
//  Created by Michael Alfieri on 1/24/26.
//

import Foundation
import Combine
import FirebaseAuth

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var user: User?
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var authError: String?

    private var listener: AuthStateDidChangeListenerHandle?

    init() {
        // Share auth session with share extension via App Group
        try? Auth.auth().useUserAccessGroup("9Q6S64UNWA.group.org.valueminer.shared")
        
        listener = Auth.auth().addStateDidChangeListener { _, user in
            self.user = user
        }
    }

    var userId: String? { user?.uid }

    func signUp() async {
        authError = nil
        do {
            _ = try await Auth.auth().createUser(withEmail: email, password: password)
        } catch {
            authError = error.localizedDescription
        }
    }

    func signIn() async {
        authError = nil
        do {
            _ = try await Auth.auth().signIn(withEmail: email, password: password)
        } catch {
            authError = error.localizedDescription
        }
    }

    func signOut() {
        authError = nil
        do {
            try Auth.auth().signOut()
        } catch {
            authError = error.localizedDescription
        }
    }
}
