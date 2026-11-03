# Backend spec: email sign-in and sign-up

For the backend team. The Flutter app (`urban_tanker_app`) already calls the endpoints below. Until they are deployed, the app hides the email code option and keeps password sign-in working. Nothing in this document changes the client's behaviour for phone or username sign-in.

## Summary

| Method | Path | Used for | Status today |
|---|---|---|---|
| POST | `/auth/login` | Email + password, or username + password | Exists |
| POST | `/auth/signup` | Customer sign-up with a password | Exists |
| POST | `/auth/password-reset` | Forgot-password instructions | Exists |
| POST | `/auth/email/request-otp` | Send a one-time code to an email | **New** |
| POST | `/auth/email/verify-otp` | Check the code and sign in | **New** |

All requests and responses are JSON. The client sends `Content-Type: application/json` and `X-Client-Platform: mobile`. Errors use `{ "error": "<message for the user>" }`, and the client shows that message as it is.

## Email one-time codes

### POST /auth/email/request-otp

Request:

```json
{ "email": "asha@example.com" }
```

The client lowercases and trims the address before sending. Please also normalize on the server.

Response `200`:

```json
{ "challengeId": "5f2c1e7a-0b7e-4c8e-9a52-6d1f0a3b9c11" }
```

Errors:
- `400`: the address is not valid. Body `{ "error": "..." }`.
- `429`: too many requests. Body `{ "error": "..." }`.
- `404` or `501`: the endpoint is not deployed. The client turns the email code option off for the rest of the app run and keeps password sign-in. Do not use these codes for any other reason.

Behaviour:
- Generate a 6-digit numeric code. Store only a salted hash of it, never the code.
- The code expires 10 minutes after it is issued. The app tells users so.
- Codes are single use. A used or expired challenge cannot be verified again.
- Resend throttling: 1 code per 30 seconds per email, and 5 per hour per email and per client IP. The client already waits 30 seconds before it offers "Send a new code".
- Respond the same way whether or not an account exists for the address, so the endpoint does not reveal who has an account. A code is only sent when it is useful: for an existing account, or for a new sign-up.
- Send the email through the existing transactional mail provider. Never log the address together with the code.

### POST /auth/email/verify-otp

Request:

```json
{
  "email": "asha@example.com",
  "challengeId": "5f2c1e7a-0b7e-4c8e-9a52-6d1f0a3b9c11",
  "otp": "123456",
  "name": "Asha Kumar",
  "phone": "9876543210"
}
```

`name` and `phone` are sent only by the sign-up path. `phone` is a 10-digit Indian mobile number without the country code.

Response `200`: the same payload as `/auth/phone/verify-otp`, so the client stores it the same way.

```json
{
  "accessToken": "<jwt>",
  "refreshToken": "<opaque>",
  "user": {
    "id": "<uuid>",
    "name": "Asha Kumar",
    "username": "asha",
    "role": "customer",
    "email": "asha@example.com",
    "themeMode": "system",
    "selfieRequired": true
  }
}
```

Errors:
- `400`: the code is wrong. Body `{ "error": "The verification code is incorrect." }`. Count the attempt.
- `400`: the code has expired or was already used. Body `{ "error": "This code has expired. Request a new one." }`.
- `429`: too many attempts. Allow at most 5 verify attempts per challenge. After that, the challenge is dead and the user must request a new code. Body `{ "error": "Too many attempts. Request a new code." }`.
- `404` or `501`: as above.

Behaviour:
- Compare the code in constant time.
- For a new account created through an email code, `name` and `phone` are required. Return `400` if they are missing. Create the account with role `customer` only.
- If the email already belongs to a verified account, sign that account in. The same verified email is always the same account.

## Password sign-up

`POST /auth/signup` already exists. The client sends:

```json
{
  "email": "asha@example.com",
  "password": "Secret123",
  "name": "Asha Kumar",
  "phone": "9876543210",
  "role": "customer",
  "themeMode": "system"
}
```

The client checks these rules before it sends the request, so the server's rules can be stricter but should not be looser: at least 8 characters, with an upper-case letter, a lower-case letter and a number.

Responses the client handles:
- `201` with the auth payload: the user is signed in.
- `201` with `{ "requiresEmailVerification": true, "emailSent": true }`: the client shows "Check your inbox". Send the confirmation link to the address. If `emailSent` is not `true`, the client reports an error, so do not send that flag unless the email was sent.
- `409`: the email is already registered. The client offers a one-tap switch to sign-in with the address filled in. Use `409` for this case only.
- `400`: validation failed. The body's `error` text is shown to the user.

## Password sign-in

`POST /auth/login` with `{ "email": "...", "password": "..." }` when the credential contains `@`, otherwise `{ "username": "...", "password": "..." }`. Return `401` for wrong credentials, with a generic message. Do not say whether the email exists.

## Forgot password

`POST /auth/password-reset` with `{ "email": "..." }`. The client needs `{ "accepted": true }` for every address, whether or not an account exists. It then shows a neutral message.

## Rate limiting and abuse

- Per email and per client IP, for every endpoint above.
- Return `429` with `{ "error": "..." }`. The client shows "Too many requests. Please wait a moment and try again." when no message is given.
- Log failed attempts without the code, the password, or the full address.

## Security notes

- Store codes and passwords only as salted hashes. Tokens are stored by the client in secure storage, as they are today.
- Use HTTPS only.
- Keep the 404 and 501 responses for "endpoint not deployed" only. The client uses them as the signal to switch the feature off.

## Client-side flags

- `AuthFeatureFlags.emailOtp` (`lib/app/auth_feature_flags.dart`) turns the code option on or off in a build.
- `AppController.emailOtpAvailable` is set to `false` at runtime after a `404` or `501`.

## Open questions for the backend

1. Confirm the throttle numbers above (1 per 30 seconds; 5 per hour per email and IP).
2. Confirm whether `/auth/signup` should send a resend endpoint for confirmation emails. The app has no resend button for those yet.
3. Confirm the `409` response for an existing email on sign-up.
