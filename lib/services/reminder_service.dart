import 'package:url_launcher/url_launcher.dart';
import '../models/member.dart';
import '../models/gym_profile.dart';
import '../models/plan.dart';
import 'message_template_service.dart';

/// Builds and launches WhatsApp / SMS messages for plan-expiry reminders.
///
/// Important: there is no backend here, so "sending" is always a manual
/// action — this opens WhatsApp or the SMS app with the message
/// pre-filled, and the gym owner taps Send themselves. True automatic
/// sending (no tap required) would need the WhatsApp Business API or an
/// SMS gateway account, which requires a paid backend integration and is
/// out of scope for a serverless app. The on-device local notification
/// (see NotificationService) is the only fully-automatic reminder —
/// it alerts the gym owner, not the member.
class ReminderService {
  /// Default country code prepended to mobile numbers that don't already
  /// start with "+". WhatsApp's URL schemes require the full
  /// international number (country code + number) to resolve correctly —
  /// a plain 10-digit Indian number without "+91" will silently fail to
  /// open the right chat. Change this if targeting a different country.
  static const String defaultCountryCode = '+91';

  /// Renders a message template by substituting placeholder tokens with
  /// this member's actual data. See message_template_service.dart for
  /// the list of supported tokens.
  String renderTemplate({
    required String template,
    required Member member,
    required GymProfile? gymProfile,
    Plan? plan,
  }) {
    final gymName = gymProfile?.name.isNotEmpty == true ? gymProfile!.name : 'the gym';
    final daysLeft = member.endDate.difference(DateTime.now()).inDays;
    final dateStr = '${member.endDate.day}/${member.endDate.month}/${member.endDate.year}';
    final planName = plan?.name ?? '';
    final amount = plan != null ? '₹${plan.price.toStringAsFixed(0)}' : '';

    return template
        .replaceAll('{{MEMBERNAME}}', member.name)
        .replaceAll('{{GYMNAME}}', gymName)
        .replaceAll('{{EXPIRYDATE}}', dateStr)
        .replaceAll('{{DAYSLEFT}}', daysLeft.abs().toString())
        .replaceAll('{{PLANNAME}}', planName)
        .replaceAll('{{AMOUNT}}', amount);
  }

  /// Convenience fallback when no saved template is available yet.
  String buildMessage({
    required Member member,
    required GymProfile? gymProfile,
    Plan? plan,
  }) {
    return renderTemplate(
      template: defaultReminderTemplate,
      member: member,
      gymProfile: gymProfile,
      plan: plan,
    );
  }

  /// Normalizes a mobile number for WhatsApp/SMS URI schemes: strips
  /// everything except digits and a leading "+", then prepends the
  /// default country code if the number doesn't already start with "+".
  String _sanitizeMobile(String mobile) {
    var cleaned = mobile.replaceAll(RegExp(r'[^\d+]'), '');
    if (!cleaned.startsWith('+')) {
      // Strip a leading 0 (common in local-format numbers) before adding
      // the country code, e.g. "098765..." -> "+9198765...".
      if (cleaned.startsWith('0')) {
        cleaned = cleaned.substring(1);
      }
      cleaned = '$defaultCountryCode$cleaned';
    }
    return cleaned;
  }

  /// Opens WhatsApp with a pre-filled message to this member's number.
  /// Tries the native app scheme first (most reliable when WhatsApp is
  /// installed), then falls back to the web-based wa.me link, then to
  /// api.whatsapp.com as a last resort. Returns false only if none of
  /// these could be launched.
  Future<bool> sendViaWhatsApp({
    required Member member,
    required GymProfile? gymProfile,
    Plan? plan,
    String? customMessage,
    String? template,
  }) async {
    final phone = _sanitizeMobile(member.mobile);
    // WhatsApp URL schemes expect the number without the leading "+".
    final phoneDigitsOnly = phone.replaceFirst('+', '');
    final message = customMessage ??
        renderTemplate(
          template: template ?? defaultReminderTemplate,
          member: member,
          gymProfile: gymProfile,
          plan: plan,
        );
    final encodedMessage = Uri.encodeComponent(message);

    final candidates = [
      Uri.parse('whatsapp://send?phone=$phoneDigitsOnly&text=$encodedMessage'),
      Uri.parse('https://wa.me/$phoneDigitsOnly?text=$encodedMessage'),
      Uri.parse('https://api.whatsapp.com/send?phone=$phoneDigitsOnly&text=$encodedMessage'),
    ];

    for (final uri in candidates) {
      try {
        final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (launched) return true;
      } catch (_) {
        // Try the next candidate.
      }
    }
    return false;
  }

  /// Opens the default SMS app with a pre-filled message to this
  /// member's number.
  Future<bool> sendViaSms({
    required Member member,
    required GymProfile? gymProfile,
    Plan? plan,
    String? customMessage,
    String? template,
  }) async {
    final phone = _sanitizeMobile(member.mobile);
    final message = customMessage ??
        renderTemplate(
          template: template ?? defaultReminderTemplate,
          member: member,
          gymProfile: gymProfile,
          plan: plan,
        );
    final uri = Uri(
      scheme: 'sms',
      path: phone,
      queryParameters: {'body': message},
    );

    try {
      return await launchUrl(uri);
    } catch (_) {
      return false;
    }
  }
}
