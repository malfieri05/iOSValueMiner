# App Store Resubmission Plan – ScrollMiner

Based on Apple’s feedback from **February 9, 2026** (Submission ID: 88bd7987-95b9-4828-ba1e-665b26253afd).

---

## 1. Guideline 5.2.3 – Intellectual Property (Audio/Video Downloading)

**Issue:** App appears to allow saving/downloading music, video, or other media without authorization.

**Reality:** ScrollMiner only saves **links** and **text transcripts** (via Supadata API with `text: true`). It does **not** download or store video or audio.

**Actions:**
- **In app:** Add a short disclaimer (e.g. on Mine screen or Paywall): *"ScrollMiner saves links and text transcripts only. No video or audio is downloaded."*
- **App Store Connect:** In the app description (and possibly “What’s New”), clearly state that the app does **not** download or store video or audio—it only saves links and text transcripts for personal reference.
- **Review Notes (optional):** Briefly explain: “The app only saves the user’s chosen URL and a text transcript. No video or audio files are downloaded or stored.”

---

## 2. Guideline 5.1.2 – Privacy / Data Use and Sharing (Tracking)

**Issue:** Privacy label indicates the app collects data “to track the user,” but the app doesn’t use App Tracking Transparency (ATT).

**Actions (choose one):**
- **If the app does NOT track users:**  
  In **App Store Connect → App Privacy**, update the privacy information so it does **not** indicate that data is used for tracking. Remove or correct any “tracking” purposes and data types that are only used for tracking. Then in **Review Notes** state: “This app does not track users. App Privacy has been updated accordingly.”
- **If the app DOES track users:**  
  Implement the **App Tracking Transparency** framework, request permission before tracking, and in Review Notes tell Apple where the permission request appears.

Most likely the label was over-declared; correcting it in App Store Connect (and clarifying in Review Notes) is usually enough.

---

## 3. Guideline 2.3.2 – Accurate Metadata (Promotional Images)

**Issue:**  
- Promotional image is the same as the app icon.  
- Duplicate/identical promotional images for different IAP products.

**Actions (App Store Connect only):**
- Create **new promotional images** for the in-app purchase(s) that:
  - Are **not** the app icon.
  - Clearly represent the **subscription / IAP** (e.g. “Unlock more clips,” plan names, benefits).
- Use **different** images for each promoted product/offer (no duplicates).
- If you don’t plan to promote a specific IAP, you can **delete** its promotional image in App Store Connect.

No code changes required.

---

## 4. Guideline 2.1 – App Completeness (IAP Bug)

**Issue:** “Unable to see the subscription plans” (reviewed on iPad Air 11-inch (M3), iPadOS 26.2.1).

**Actions (code):**
- Use **SubscriptionStoreView** (StoreKit, iOS 17+) so subscription plans are presented in a standard, reliable way (often fixes “plans not visible” in review).
- When products haven’t loaded yet or fail to load:
  - Show a **loading state** (e.g. “Loading subscription options…”).
  - Offer a **Retry** button that calls `SubscriptionManager.loadProducts()` again.
- Ensure the paywall is tested on **iPad** in Sandbox so plans are visible and tappable.

---

## 5. Guideline 3.1.2 – Subscriptions (Terms & Privacy)

**Issue:**  
- App must include **in the app**: functional links to **Terms of Use (EULA)** and **Privacy Policy**.  
- App Store metadata must include functional links to **Terms of Use** and **Privacy Policy**.

**Actions:**
- **In the app:**
  - Use **SubscriptionStoreView** with:
    - `.subscriptionStorePolicyDestination(url: privacyPolicyURL, for: .privacyPolicy)`
    - `.subscriptionStorePolicyDestination(url: termsURL, for: .termsOfService)`
  - If you keep any custom paywall UI, add **tappable links** there too (Terms of Use, Privacy Policy) that open the same URLs.
- **App Store Connect:**
  - **Privacy Policy:** Set the **Privacy Policy URL** in the app’s metadata (required field).
  - **Terms of Use (EULA):** Either:
    - Add a **functional link to your Terms of Use** in the **App Description**, or  
    - If using a custom EULA, add it in the **EULA** field in App Store Connect.

You must host real, working URLs for Privacy Policy and Terms of Use (e.g. on your website or a static page).

**In this project:** Add two keys to `Secrets.plist` (same file used for API keys) so the paywall can show policy links and SubscriptionStoreView can use them:
- `PRIVACY_POLICY_URL` (string) – e.g. `https://yoursite.com/privacy`
- `TERMS_OF_USE_URL` (string) – e.g. `https://yoursite.com/terms`

If these are missing, the app still builds; the paywall will show SubscriptionStoreView without policy destination links. For approval you must set them and add the same URLs in App Store Connect.

---

## Checklist Before Resubmitting

| # | Guideline | Done |
|---|-----------|------|
| 1 | 5.2.3 – In-app disclaimer + ASC description (no video/audio download) | |
| 2 | 5.1.2 – App Privacy updated in ASC (no tracking) or ATT implemented | |
| 3 | 2.3.2 – Unique IAP promotional images in ASC | |
| 4 | 2.1 – Paywall uses SubscriptionStoreView + loading/retry; test on iPad | |
| 5 | 3.1.2 – Terms & Privacy links in app (SubscriptionStoreView + custom UI) | |
| 6 | 3.1.2 – Terms & Privacy URLs in App Store Connect metadata | |

---

## Code Changes (this repo)

- **PaywallView:** Use `SubscriptionStoreView` with product IDs and `.subscriptionStorePolicyDestination` for Terms and Privacy; add loading/retry when products are empty.
- **Config/URLs:** Add constants (or Config) for Terms of Use and Privacy Policy URLs so you can replace placeholders with your real links.
- **Disclaimer:** Add one-line “saves links and text only, no video/audio” on Mine or Paywall for 5.2.3.

Everything else (privacy labels, promo images, metadata URLs) is done in **App Store Connect** and optionally in **Review Notes**.
