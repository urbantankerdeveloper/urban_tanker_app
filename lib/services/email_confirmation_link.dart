/// True for the link the signup email opens: `urbantanker://auth/email-confirmed`.
///
/// Supabase puts its own tokens in the fragment of this link. The app does not
/// read them. The user signs in with their password after confirming, so the
/// link only means "show the sign-in form with a confirmed notice".
bool isEmailConfirmationLink(Uri uri) =>
    uri.scheme == 'urbantanker' &&
    uri.host == 'auth' &&
    uri.pathSegments.length == 1 &&
    uri.pathSegments.first == 'email-confirmed';
