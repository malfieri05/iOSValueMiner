# Backend: transcript language (Firebase)

**Only when you're in your Firebase backend repo:** do these three things in the code that processes `clipQueue` and calls Supadata:

1. **Read** `preferredTranscriptLang` from the queue doc → default to `"en"` if missing.
2. **Call Supadata** with that value as the `lang` query param (e.g. `?url=...&lang=en&text=true&mode=auto`).
3. **After Supadata responds:** if `response.lang !== preferredTranscriptLang`, translate the transcript to `preferredTranscriptLang` (e.g. Google Cloud Translation), then save the **translated** text as the clip’s `transcript`. Otherwise save the response content as-is.

Then deploy: `firebase deploy --only functions`.
