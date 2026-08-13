import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'local_storage_service.dart';
import 'notification_service.dart';
import 'gym_repository.dart';
import 'backup_service.dart';
import 'message_template_service.dart';

final localStorageServiceProvider = Provider<LocalStorageService>((ref) => LocalStorageService());

final notificationServiceProvider = Provider<NotificationService>((ref) => NotificationService());

final gymRepositoryProvider = Provider<GymRepository>((ref) {
  return GymRepository(
    ref.watch(localStorageServiceProvider),
    ref.watch(notificationServiceProvider),
  );
});

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(ref.watch(localStorageServiceProvider));
});

final messageTemplateServiceProvider = Provider<MessageTemplateService>((ref) {
  return MessageTemplateService(ref.watch(localStorageServiceProvider));
});
