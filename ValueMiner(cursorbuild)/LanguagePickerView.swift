//
//  LanguagePickerView.swift
//  ValueMiner(cursorbuild)
//
//  Created by Michael Alfieri on 2/03/26.
//

import SwiftUI

struct LanguagePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedLanguage: String
    let options: [(code: String, name: String)]
    @AppStorage(ThemeColors.backgroundKey) private var themeBackground = ThemeColors.defaultBackground

    private var primaryText: Color { ThemeColors.primaryText(from: themeBackground) }
    private var backgroundColor: Color { ThemeColors.background(from: themeBackground) }

    var body: some View {
        NavigationStack {
            List {
                ForEach(options, id: \.code) { option in
                    Button {
                        selectedLanguage = option.code
                        dismiss()
                    } label: {
                        HStack {
                            Text(option.name)
                                .foregroundColor(primaryText)
                            Spacer()
                            if selectedLanguage == option.code {
                                Image(systemName: "checkmark")
                                    .foregroundColor(primaryText.opacity(0.7))
                            }
                        }
                        .contentShape(Rectangle())
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(backgroundColor)
            .navigationTitle("Language")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
