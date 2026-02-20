//
//  BookEquivalentExplainerView.swift
//  ValueMiner(cursorbuild)
//

import SwiftUI

struct BookEquivalentExplainerView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("themeAccent") private var themeAccent = ThemeColors.defaultAccent
    @AppStorage(ThemeColors.backgroundKey) private var themeBackground = ThemeColors.defaultBackground

    private var accentColor: Color { ThemeColors.color(from: themeAccent) }
    private var primaryText: Color { ThemeColors.primaryText(from: themeBackground) }
    private var backgroundColor: Color { ThemeColors.background(from: themeBackground) }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        headerSection
                        formulaSection
                        whySection
                        researchSection
                        whatItMeansSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("How It Works")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(accentColor)
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "function")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(accentColor)
                Text("The Science Behind Book Equivalents")
                    .font(.title3.bold())
                    .foregroundColor(primaryText)
            }

            Text("Your knowledge tracking is backed by educational research.")
                .font(.subheadline)
                .foregroundColor(primaryText.opacity(0.7))
        }
        .padding(.top, 16)
    }

    // MARK: - Formula

    private var formulaSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(icon: "equal.circle", title: "The Formula")

            VStack(spacing: 16) {
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Text("1 Book Equivalent")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(primaryText)
                        Text("=")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(accentColor)
                        Text("5,000 words")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(accentColor)
                        Text("of transcribed content")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(primaryText.opacity(0.7))
                    }
                    Spacer()
                }
                .padding(.vertical, 20)
                .background(accentColor.opacity(ThemeColors.accentTintOpacity(from: themeBackground)))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    // MARK: - Why 5,000?

    private var whySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(icon: "book.closed", title: "Why 5,000 Words?")

            VStack(alignment: .leading, spacing: 12) {
                bulletPoint(
                    "The average nonfiction book contains",
                    highlight: "50,000 words"
                )

                bulletPoint(
                    "Research shows only about",
                    highlight: "10% is core, actionable content"
                )

                bulletPoint(
                    "The rest is elaboration, examples, stories, and filler",
                    highlight: nil
                )

                Text("We track the essence of what you're learning—not padding.")
                    .font(.subheadline)
                    .foregroundColor(primaryText.opacity(0.8))
                    .italic()
                    .padding(.top, 4)
            }
            .padding(16)
            .background(primaryText.opacity(ThemeColors.inputFillOpacity(from: themeBackground)))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    // MARK: - Research

    private var researchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(icon: "doc.text.magnifyingglass", title: "The Research")

            VStack(spacing: 12) {
                researchCard(
                    authors: "Daley & Rawson (2021)",
                    journal: "Educational Psychology Review",
                    finding: "Textbook elaborations impose a large time cost without improving memory for main ideas. Elaborated texts can be less effective than unelaborated versions."
                )

                researchCard(
                    authors: "Reder & Anderson (1980)",
                    journal: "Journal of Verbal Learning and Verbal Behavior",
                    finding: "Summaries outperformed full texts for memory retention at every interval tested—20 minutes, 1 week, and 6-12 months."
                )

                researchCard(
                    authors: "Industry Analysis",
                    journal: "Publishing Research",
                    finding: "Analysis of bestsellers like 'Drive' found ~40% of content was filler—glossaries, recaps, reading lists that don't help readers apply the material."
                )

                researchCard(
                    authors: "Brysbaert (2019)",
                    journal: "Journal of Memory and Language",
                    finding: "Adults read nonfiction at an average of 238 words per minute. A 50,000-word book takes ~3.5 hours of focused reading."
                )
            }
        }
    }

    // MARK: - What This Means

    private var whatItMeansSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(icon: "lightbulb", title: "What This Means For You")

            VStack(alignment: .leading, spacing: 12) {
                Text("By saving and organizing clips on topics you care about, you're building a personal knowledge library of high-density information.")
                    .font(.subheadline)
                    .foregroundColor(primaryText.opacity(0.85))

                Text("This is the equivalent of reading the core insights from multiple books—curated by you, relevant to your interests, without the fluff.")
                    .font(.subheadline)
                    .foregroundColor(primaryText.opacity(0.85))

                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundColor(accentColor)
                    Text("Learning on your terms.")
                        .font(.subheadline.bold())
                        .foregroundColor(primaryText)
                }
                .padding(.top, 8)
            }
            .padding(16)
            .background(accentColor.opacity(ThemeColors.accentTintOpacity(from: themeBackground) * 0.5))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    // MARK: - Helper Views

    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(accentColor)
            Text(title)
                .font(.headline)
                .foregroundColor(primaryText)
        }
    }

    private func bulletPoint(_ text: String, highlight: String?) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(accentColor)
                .frame(width: 6, height: 6)
                .padding(.top, 6)

            if let highlight = highlight {
                (Text(text + " ")
                    .foregroundColor(primaryText.opacity(0.8))
                + Text(highlight)
                    .foregroundColor(accentColor)
                    .fontWeight(.semibold))
                    .font(.subheadline)
            } else {
                Text(text)
                    .font(.subheadline)
                    .foregroundColor(primaryText.opacity(0.8))
            }
        }
    }

    private func researchCard(authors: String, journal: String, finding: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(authors)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(primaryText)
                Spacer()
            }

            Text(journal)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(accentColor.opacity(0.9))

            Text(finding)
                .font(.system(size: 13))
                .foregroundColor(primaryText.opacity(0.75))
                .italic()
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(primaryText.opacity(ThemeColors.inputFillOpacity(from: themeBackground)))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
