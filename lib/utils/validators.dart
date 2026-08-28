/// Validates a member's mobile number field. Previously any non-empty
/// string passed (including typos, letters, or a handful of digits),
/// which meant bad numbers only surfaced later when WhatsApp/SMS
/// reminders silently failed to open the right chat.
///
/// Accepts digits with optional spaces, hyphens, and a leading "+" for
/// country code (e.g. "+91 98765 43210", "9876543210") and requires
/// 10-13 digits once formatting characters are stripped — covering a
/// plain 10-digit Indian mobile number up to a full international
/// number with country code.
String? validateMobileNumber(String? value) {
  final trimmed = (value ?? '').trim();
  if (trimmed.isEmpty) return 'Required';

  if (!RegExp(r'^[0-9+\-\s]+$').hasMatch(trimmed)) {
    return 'Mobile number can only contain digits';
  }

  final digitsOnly = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
  if (digitsOnly.length < 10 || digitsOnly.length > 13) {
    return 'Enter a valid mobile number';
  }

  return null;
}
