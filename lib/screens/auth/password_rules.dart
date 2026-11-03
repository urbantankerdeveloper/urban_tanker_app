/// Password rules shown under the password field. The server's own rules may be
/// stricter; its message is shown if it refuses a password.
const passwordMinLength = 8;

typedef PasswordCheck = ({String label, bool met});

/// The checks in the order the user sees them.
List<PasswordCheck> passwordChecks(String password) => [
      (
        label: 'At least $passwordMinLength characters',
        met: password.length >= passwordMinLength,
      ),
      (label: 'An uppercase letter', met: RegExp('[A-Z]').hasMatch(password)),
      (label: 'A lowercase letter', met: RegExp('[a-z]').hasMatch(password)),
      (label: 'A number', met: RegExp(r'\d').hasMatch(password)),
    ];

/// True when every check passes.
bool isStrongPassword(String password) =>
    passwordChecks(password).every((check) => check.met);
