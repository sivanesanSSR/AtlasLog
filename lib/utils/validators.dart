/// Validates a member's mobile number field as a plain 10-digit Indian
/// mobile number. Previously this accepted 10-13 digits with optional
/// "+" country codes and separators, which was looser than what the
/// gym actually enters (a plain local 10-digit number) and let through
/// numbers of the wrong length.
///
/// Strips spaces/hyphens first so "98765 43210" and "9876543210" both
/// validate the same way, then requires exactly 10 digits.
String? validateMobileNumber(String? value) {
  final trimmed = (value ?? '').trim();
  if (trimmed.isEmpty) return 'Required';

  final cleaned = trimmed.replaceAll(RegExp(r'[\s\-]'), '');

  if (!RegExp(r'^[0-9]+$').hasMatch(cleaned)) {
    return 'Mobile number can only contain digits';
  }

  if (cleaned.length != 10) {
    return 'Enter a 10-digit mobile number';
  }

  return null;
}
