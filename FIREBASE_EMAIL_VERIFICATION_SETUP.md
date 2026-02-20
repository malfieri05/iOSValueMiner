# Firebase: Branded “Verify for Scroll Mine” Email (Click-by-Click)

Do these steps in the **Firebase Console** so verification emails are branded and use a clean button instead of a long link.

---

## 1. Open Firebase and your project

1. Go to **https://console.firebase.google.com** and sign in.
2. Click your project (the one used by ValueMiner / Scroll Mine — e.g. **valueminer-912d5** or similar).
3. In the left sidebar, click **Build** → **Authentication** (under “Build”).

---

## 2. Open the email verification template

1. In **Authentication**, click the **Templates** tab at the top (or the **“Templates”** link in the Auth section).
2. Find **“Email address verification”** in the list.
3. Click **“Email address verification”** (or the pencil/edit icon next to it) to open the template editor.

---

## 3. Set the subject line

1. In **“Subject”**, clear the default text.
2. Type exactly:  
   **`Verify for Scroll Mine`**
3. Leave this tab/window open; we’ll set the body next.

---

## 4. Set the email body (button + Scroll Mine branding)

1. Find the **“Body”** or **“Email body”** field (often a text area or HTML editor).
2. **Replace the entire body** with the text below.  
   Firebase usually supports a variable like **`%LINK%`** or **`{{link}}`** for the verification URL — check the existing template for the exact placeholder (e.g. “Insert link” or “Action URL”) and use that same one in the snippet.

   If the template uses **`%LINK%`** (Firebase’s common placeholder), use this:

```html
Hello,

Thanks for signing up for Scroll Mine. Tap the button below to verify your email address.

<a href="%LINK%" style="display:inline-block;padding:14px 28px;background:#007AFF;color:#ffffff;text-decoration:none;border-radius:10px;font-weight:600;font-size:16px;">Verify my email</a>

If the button doesn’t work, copy and paste this link into your browser:
%LINK%

If you didn’t create an account with Scroll Mine, you can ignore this email.

Thanks,
The Scroll Mine team
```

   If your template uses **`{{link}}`** or **`{{ .Link }}`** instead, replace every **`%LINK%`** in the block above with that placeholder.

3. **Remove** any old text that says “project-673161992063” or “Your project-673161992063 team”.
4. If there is a **“Sender name”** or **“From name”** field elsewhere on the same page, set it to **Scroll Mine** (or **Scroll Mine Team**).
5. Click **Save** (or **Update**) to save the template.

---

## 5. Confirm what you changed

- **Subject:** “Verify for Scroll Mine”
- **Body:** Scroll Mine greeting, one blue **“Verify my email”** button using the link variable, plain-link fallback, “The Scroll Mine team” sign-off, no “project-673161992063”.
- **Sender name:** “Scroll Mine” or “Scroll Mine Team” (if the option exists).

---

## 6. Test it

1. In your app, sign up with a **new** email address (or use “Resend verification email” for an existing unverified account).
2. Check the inbox (and spam folder) for that address.
3. You should see:
   - Subject: **Verify for Scroll Mine**
   - From: **Scroll Mine** (if you set it)
   - One clear **“Verify my email”** button (and the long link only as fallback text)
   - Sign-off: **The Scroll Mine team**

If the button doesn’t appear and you only see a link, your template might not support HTML. In that case use the same body but as **plain text** and a single line: “Verify my email: %LINK%” — the in-app screen still tells users to “tap the button in that email,” so you can later switch to an HTML-capable template or custom sender if needed.

---

## Optional: Custom action URL (shorter link)

If you have a domain (e.g. scrollmine.com):

1. In Firebase **Authentication** → **Templates** (or **Settings**), look for **“Action URL”** or **“Customize action URL”**.
2. Set it to something like: **`https://yourdomain.com/verify`**
3. On your server, make **`/verify`** redirect to the full Firebase link (Firebase may pass the real link as a query parameter; implement the redirect as documented in Firebase “Customize action URL”).

This makes the link in the email shorter and more branded; the button in the template still uses the same link variable.

---

You’re done. New verification emails will be branded and use a single clear button (and fallback link) instead of a long chaotic link.
