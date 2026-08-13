import 'local_storage_service.dart';

/// Default reminder message template, using placeholder tokens the gym
/// owner can rearrange or remove. Rendered by ReminderService.
const String defaultReminderTemplate =
    'Hi {{MEMBERNAME}}, this is a reminder that your membership at '
    '{{GYMNAME}} expires on {{EXPIRYDATE}} (in {{DAYSLEFT}} days). '
    'kindly renew your membership \n'
    'Thank you🙂!\n'
    'Stay Strong 💪🏻';

/// Available placeholder tokens, shown to the gym owner when editing
/// the template so they know what they can use.
const List<String> reminderTemplatePlaceholders = [
  '{{MEMBERNAME}}',
  '{{GYMNAME}}',
  '{{EXPIRYDATE}}',
  '{{DAYSLEFT}}',
  '{{PLANNAME}}',
  '{{AMOUNT}}',
];

class MessageTemplateService {
  final LocalStorageService _storage;
  static const _fileName = 'reminder_template.txt';

  MessageTemplateService(this._storage);

  Future<String> getTemplate() async {
    return _storage.readFile(_fileName, defaultContent: defaultReminderTemplate);
  }

  Future<void> saveTemplate(String template) async {
    await _storage.writeFile(_fileName, template);
  }

  Future<void> resetToDefault() async {
    await _storage.writeFile(_fileName, defaultReminderTemplate);
  }
}
