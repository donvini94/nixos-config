# Draft email to amiconsult IT — Thunderbird OAuth2 consent for mu4e

> **Send to:** your IT admin / M365 tenant admin.
> **Subject:** Request: Tenant admin consent for Mozilla Thunderbird OAuth2 app

---

Hi [IT admin name],

I'm setting up Emacs mu4e on my Mac as my mail client (in addition to / replacing Outlook for daily work). It needs OAuth2 access to my mailbox via IMAP and SMTP, which on M365 requires either tenant-admin consent for an existing multi-tenant app, or a dedicated app registration.

**The simplest option** is to grant tenant-admin consent for **Mozilla Thunderbird's** OAuth2 application. Mozilla maintains this as a multi-tenant app specifically for desktop mail clients (Thunderbird itself, mu4e, mutt, etc. all reuse it). You can grant consent in one click:

1. Open this URL while signed in as a tenant admin:
   `https://login.microsoftonline.com/amiconsult.onmicrosoft.com/adminconsent?client_id=08162f7c-0fd2-4200-a84a-f25a4db0b584`
   (replace `amiconsult.onmicrosoft.com` with the correct tenant domain if different)

2. Review the requested permissions:
   - `IMAP.AccessAsUser.All` — read/write the *consenting user's* mailbox via IMAP
   - `SMTP.Send` — send mail as the *consenting user*
   - `offline_access` — refresh tokens so users don't re-auth hourly

3. Click **Accept**. After consent, individual users (just me for now) can sign in to Thunderbird-based clients without further admin involvement.

**Scope of access:** Permissions are *delegated* — the app can only act as the signed-in user, not as the tenant or other users. Equivalent to what Outlook itself does.

**Audit/revocation:** You can revoke at any time from Entra ID → Enterprise Applications → Mozilla Thunderbird → Properties → Enabled for users to sign-in = No.

**If you prefer a dedicated app registration instead** (e.g., for tighter audit), I'm happy to walk through registering one under amiconsult's tenant with the same delegated scopes (`IMAP.AccessAsUser.All`, `SMTP.Send`, `offline_access`, public-client / native flow, redirect URI `http://localhost`). About 15 minutes in Entra portal.

Happy to jump on a quick call if any of this needs discussion.

Thanks,
Vincenzo

---

## Technical context (for your IT, optional)

- Client tool: mu4e in Emacs + mbsync (isync) + msmtp, brokered by pizauth (Rust OAuth2 daemon)
- Auth flow: OAuth2 Authorization Code + PKCE, loopback redirect URI
- Token storage: encrypted on local disk via macOS keychain / GPG
- Equivalent rationale to allowing Apple Mail / Thunderbird / eM Client
