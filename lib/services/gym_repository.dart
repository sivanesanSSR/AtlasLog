import 'dart:convert';
import 'dart:io';
import 'package:uuid/uuid.dart';
import '../models/gym_profile.dart';
import '../models/plan.dart';
import '../models/member.dart';
import '../models/payment.dart';
import '../utils/date_utils.dart';
import 'local_storage_service.dart';
import 'notification_service.dart';

const _uuid = Uuid();

/// Central data access layer. All screens should go through this class
/// rather than talking to LocalStorageService directly.
/// Thrown when adding a member would create a duplicate based on
/// mobile number (which should be unique per member).
class DuplicateMemberException implements Exception {
  final String message;
  DuplicateMemberException(this.message);
  @override
  String toString() => message;
}

class GymRepository {
  final LocalStorageService _storage;
  final NotificationService _notifications;

  GymRepository(this._storage, this._notifications);

  // ---------- Gym Profile ----------

  Future<GymProfile?> getGymProfile() async {
    final content = await _storage.readFile('gym_profile.json', defaultContent: '{}');
    final decoded = jsonDecode(content);
    if (decoded is Map && decoded.isEmpty) return null;
    return GymProfile.fromJson(decoded as Map<String, dynamic>);
  }

  Future<void> saveGymProfile(GymProfile profile, {File? logoFile, bool removeLogo = false}) async {
    var toSave = profile;
    if (removeLogo) {
      toSave = toSave.copyWith(clearLogo: true);
    }
    if (logoFile != null) {
      final logoPath = await _storage.saveGymLogo(logoFile);
      toSave = toSave.copyWith(logoPath: logoPath);
    }
    await _storage.writeFile('gym_profile.json', jsonEncode(toSave.toJson()));
  }

  // ---------- Plans ----------

  Future<List<Plan>> getPlans() async {
    final content = await _storage.readFile('plans.json', defaultContent: '[]');
    final list = jsonDecode(content) as List;
    return list.map((e) => Plan.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Plan> addPlan({
    required String name,
    required int durationMonths,
    required double price,
  }) async {
    final plans = await getPlans();
    final plan = Plan(id: _uuid.v4(), name: name, durationMonths: durationMonths, price: price);
    plans.add(plan);
    await _writePlans(plans);
    return plan;
  }

  Future<void> updatePlan(Plan updated) async {
    final plans = await getPlans();
    final idx = plans.indexWhere((p) => p.id == updated.id);
    if (idx == -1) throw Exception('Plan not found');
    plans[idx] = updated;
    await _writePlans(plans);
  }

  Future<void> deletePlan(String planId) async {
    final plans = await getPlans();
    plans.removeWhere((p) => p.id == planId);
    await _writePlans(plans);
  }

  Future<void> _writePlans(List<Plan> plans) async {
    await _storage.writeFile('plans.json', jsonEncode(plans.map((p) => p.toJson()).toList()));
  }

  // ---------- Members ----------

  Future<List<Member>> getMembers() async {
    final content = await _storage.readFile('members.json', defaultContent: '[]');
    final list = jsonDecode(content) as List;
    return list.map((e) => Member.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Member> addMember({
    required String name,
    required String mobile,
    required Plan plan,
    required double amountPaid,
    File? photoFile,
    String? customMemberCode,
    DateTime? paidOnDate,
    PaymentMode paymentMode = PaymentMode.cash,
  }) async {
    final members = await getMembers();

    // Validate BEFORE writing anything — mobile number must be unique.
    // Checking name+mobile together also catches accidental double-taps
    // on the Add Member button.
    final normalizedMobile = mobile.trim();
    final normalizedName = name.trim().toLowerCase();
    final existingMobile = members.any((m) => m.mobile.trim() == normalizedMobile);
    if (existingMobile) {
      final existing = members.firstWhere((m) => m.mobile.trim() == normalizedMobile);
      throw DuplicateMemberException(
        'A member with this mobile number already exists (${existing.name}, ${existing.memberCode}).',
      );
    }
    final existingNameAndMobile = members.any(
      (m) => m.name.trim().toLowerCase() == normalizedName && m.mobile.trim() == normalizedMobile,
    );
    if (existingNameAndMobile) {
      throw DuplicateMemberException('This member already exists.');
    }

    // Member ID: use the custom one if provided, validating uniqueness;
    // otherwise auto-generate as before.
    String memberCode;
    if (customMemberCode != null && customMemberCode.trim().isNotEmpty) {
      final normalizedCode = customMemberCode.trim();
      final codeTaken = members.any((m) => m.memberCode.toLowerCase() == normalizedCode.toLowerCase());
      if (codeTaken) {
        throw DuplicateMemberException('Member ID "$normalizedCode" is already in use.');
      }
      memberCode = normalizedCode;
    } else {
      memberCode = _generateMemberCode(members.length);
    }

    final start = paidOnDate ?? DateTime.now();
    final endDate = addMonthsClamped(start, plan.durationMonths);
    final price = plan.price;
    final id = _uuid.v4();

    String? photoPath;
    if (photoFile != null) {
      photoPath = await _storage.savePhoto(photoFile, id);
    }

    final member = Member(
      id: id,
      memberCode: memberCode,
      name: name,
      mobile: mobile,
      planId: plan.id,
      startDate: start,
      endDate: endDate,
      amountPaid: amountPaid,
      amountDue: (price - amountPaid).clamp(0, double.infinity),
      updatedAt: DateTime.now(),
      photoPath: photoPath,
    );

    members.add(member);
    await _writeMembers(members);

    if (amountPaid > 0) {
      await addPayment(memberId: member.id, amount: amountPaid, mode: paymentMode, date: start);
    }

    // Schedule the 3-day-before-expiry local reminder. Wrapped so that a
    // notification-scheduling failure (e.g. permission not yet granted)
    // never surfaces as an "add member failed" error — the member record
    // is already saved successfully at this point.
    try {
      await _notifications.scheduleExpiryReminder(
        memberId: member.id,
        memberName: member.name,
        endDate: member.endDate,
      );
    } catch (_) {
      // Non-fatal — member is saved; reminder just wasn't scheduled.
    }

    return member;
  }

  /// Renews a member's plan: extends endDate from the later of
  /// (renewalDate, current endDate) and appends a payment record.
  /// [renewalDate] defaults to today but can be backdated/postdated by
  /// the gym owner (e.g. entering a renewal that happened a few days ago).
  Future<Member> renewMember({
    required String memberId,
    required Plan plan,
    required double amountPaid,
    PaymentMode mode = PaymentMode.cash,
    DateTime? renewalDate,
    DateTime? customEndDate,
  }) async {
    final members = await getMembers();
    final idx = members.indexWhere((m) => m.id == memberId);
    if (idx == -1) throw Exception('Member not found');

    final current = members[idx];
    final effectiveRenewalDate = renewalDate ?? DateTime.now();
    final base = current.endDate.isAfter(effectiveRenewalDate) ? current.endDate : effectiveRenewalDate;
    final newEndDate = addMonthsClamped(base, plan.durationMonths);

    final updated = current.copyWith(
      planId: plan.id,
      startDate: effectiveRenewalDate,
      endDate: newEndDate,
      amountPaid: amountPaid,
      amountDue: (plan.price - amountPaid).clamp(0, double.infinity),
    );

    members[idx] = updated;
    await _writeMembers(members);

    if (amountPaid > 0) {
      await addPayment(memberId: memberId, amount: amountPaid, mode: mode, date: effectiveRenewalDate);
    }

    await _notifications.cancelExpiryReminder(memberId);
    try {
      await _notifications.scheduleExpiryReminder(
        memberId: updated.id,
        memberName: updated.name,
        endDate: updated.endDate,
      );
    } catch (_) {
      // Non-fatal — renewal is saved; reminder just wasn't rescheduled.
    }

    return updated;
  }

  Future<void> deleteMember(String memberId) async {
    final members = await getMembers();
    Member? member;
    for (final m in members) {
      if (m.id == memberId) {
        member = m;
        break;
      }
    }
    members.removeWhere((m) => m.id == memberId);
    await _writeMembers(members);
    await _notifications.cancelExpiryReminder(memberId);
    if (member?.photoPath != null) {
      await _storage.deletePhoto(member!.photoPath);
    }
  }

  /// Updates a member's editable profile fields (name, mobile, photo) —
  /// does not touch plan/expiry/payment data, which goes through
  /// renewMember() instead. Re-validates mobile uniqueness excluding
  /// this member's own current record.
  Future<Member> updateMemberDetails({
    required String memberId,
    required String name,
    required String mobile,
    File? newPhotoFile,
    bool removePhoto = false,
    DateTime? startDate,
  }) async {
    final members = await getMembers();
    final idx = members.indexWhere((m) => m.id == memberId);
    if (idx == -1) throw Exception('Member not found');

    final normalizedMobile = mobile.trim();
    final duplicate = members.any((m) => m.id != memberId && m.mobile.trim() == normalizedMobile);
    if (duplicate) {
      final existing = members.firstWhere((m) => m.id != memberId && m.mobile.trim() == normalizedMobile);
      throw DuplicateMemberException(
        'Another member already uses this mobile number (${existing.name}, ${existing.memberCode}).',
      );
    }

    final current = members[idx];
    String? photoPath = current.photoPath;

    if (removePhoto && current.photoPath != null) {
      await _storage.deletePhoto(current.photoPath);
      photoPath = null;
    }
    if (newPhotoFile != null) {
      if (current.photoPath != null) {
        await _storage.deletePhoto(current.photoPath);
      }
      photoPath = await _storage.savePhoto(newPhotoFile, memberId);
    }

    final updated = current.copyWith(
      name: name,
      mobile: mobile,
      photoPath: photoPath,
      clearPhoto: photoPath == null,
      startDate: startDate,
    );

    members[idx] = updated;
    await _writeMembers(members);
    return updated;
  }

  Future<void> _writeMembers(List<Member> members) async {
    await _storage.writeFile('members.json', jsonEncode(members.map((m) => m.toJson()).toList()));
  }

  String _generateMemberCode(int currentCount) {
    return 'GM${(currentCount + 1).toString().padLeft(4, '0')}';
  }

  // ---------- Payments ----------

  Future<List<Payment>> getPayments({String? memberId}) async {
    final content = await _storage.readFile('payments.json', defaultContent: '[]');
    final list = jsonDecode(content) as List;
    final payments = list.map((e) => Payment.fromJson(e as Map<String, dynamic>)).toList();
    if (memberId != null) {
      return payments.where((p) => p.memberId == memberId).toList();
    }
    return payments;
  }

  Future<Payment> addPayment({
    required String memberId,
    required double amount,
    PaymentMode mode = PaymentMode.cash,
    DateTime? date,
  }) async {
    final payments = await getPayments();
    final payment = Payment(
      id: _uuid.v4(),
      memberId: memberId,
      amount: amount,
      date: date ?? DateTime.now(),
      mode: mode,
    );
    payments.add(payment);
    await _storage.writeFile('payments.json', jsonEncode(payments.map((p) => p.toJson()).toList()));
    return payment;
  }

  /// Corrects a mis-entered payment (wrong amount/mode/date typed in by
  /// mistake). If the payment belongs to the member's CURRENT plan cycle
  /// (i.e. it was made on/after their current startDate), the member's
  /// running amountPaid/amountDue are adjusted by the difference so the
  /// due balance stays accurate. Payments from a *previous* cycle (before
  /// the latest renewal) are historical — amountPaid/amountDue always
  /// track the current cycle only, so editing an older payment updates
  /// the log entry but intentionally leaves today's due balance alone.
  Future<Payment> updatePayment({
    required String paymentId,
    required double amount,
    required PaymentMode mode,
    required DateTime date,
  }) async {
    if (amount <= 0) {
      throw ArgumentError('Payment amount must be greater than zero.');
    }

    final payments = await getPayments();
    final idx = payments.indexWhere((p) => p.id == paymentId);
    if (idx == -1) throw Exception('Payment not found');
    final old = payments[idx];

    final updated = Payment(id: old.id, memberId: old.memberId, amount: amount, date: date, mode: mode);
    payments[idx] = updated;
    await _storage.writeFile('payments.json', jsonEncode(payments.map((p) => p.toJson()).toList()));

    final members = await getMembers();
    final mIdx = members.indexWhere((m) => m.id == old.memberId);
    if (mIdx != -1) {
      final member = members[mIdx];
      if (!old.date.isBefore(member.startDate)) {
        final delta = amount - old.amount;
        members[mIdx] = member.copyWith(
          amountPaid: (member.amountPaid + delta).clamp(0, double.infinity),
          amountDue: (member.amountDue - delta).clamp(0, double.infinity),
        );
        await _writeMembers(members);
      }
    }

    return updated;
  }

  /// Removes a mis-entered payment entirely. Same current-cycle-only rule
  /// as updatePayment() for adjusting the member's due balance.
  Future<void> deletePayment(String paymentId) async {
    final payments = await getPayments();
    final idx = payments.indexWhere((p) => p.id == paymentId);
    if (idx == -1) throw Exception('Payment not found');
    final removed = payments[idx];
    payments.removeAt(idx);
    await _storage.writeFile('payments.json', jsonEncode(payments.map((p) => p.toJson()).toList()));

    final members = await getMembers();
    final mIdx = members.indexWhere((m) => m.id == removed.memberId);
    if (mIdx != -1) {
      final member = members[mIdx];
      if (!removed.date.isBefore(member.startDate)) {
        members[mIdx] = member.copyWith(
          amountPaid: (member.amountPaid - removed.amount).clamp(0, double.infinity),
          amountDue: (member.amountDue + removed.amount).clamp(0, double.infinity),
        );
        await _writeMembers(members);
      }
    }
  }

  /// Settles some or all of a member's outstanding due amount, independent
  /// of renewal — used when a member pays off a balance mid-plan without
  /// changing their plan, start date, or end date. Unlike renewMember(),
  /// this only touches amountPaid/amountDue and appends a payment record.
  Future<Member> recordDuePayment({
    required String memberId,
    required double amount,
    PaymentMode mode = PaymentMode.cash,
    DateTime? date,
  }) async {
    if (amount <= 0) {
      throw ArgumentError('Payment amount must be greater than zero.');
    }

    final members = await getMembers();
    final idx = members.indexWhere((m) => m.id == memberId);
    if (idx == -1) throw Exception('Member not found');

    final current = members[idx];
    if (amount > current.amountDue) {
      throw ArgumentError('Payment amount cannot exceed the outstanding due of ₹${current.amountDue.toStringAsFixed(0)}.');
    }

    final updated = current.copyWith(
      amountPaid: current.amountPaid + amount,
      amountDue: (current.amountDue - amount).clamp(0, double.infinity),
    );

    members[idx] = updated;
    await _writeMembers(members);
    await addPayment(memberId: memberId, amount: amount, mode: mode, date: date);

    return updated;
  }

  /// Corrects a previously recorded payment (e.g. a typo'd amount or wrong
  /// mode). Adjusts the owning member's amountPaid/amountDue by the delta
  /// between the old and new amount so the due balance stays consistent —
  /// does not touch plan/dates.
  Future<Member> editPayment({
    required String paymentId,
    required double newAmount,
    PaymentMode? mode,
    DateTime? date,
  }) async {
    if (newAmount <= 0) {
      throw ArgumentError('Amount must be greater than zero.');
    }

    final payments = await getPayments();
    final pIdx = payments.indexWhere((p) => p.id == paymentId);
    if (pIdx == -1) throw Exception('Payment not found');
    final oldPayment = payments[pIdx];
    final delta = newAmount - oldPayment.amount;

    final members = await getMembers();
    final mIdx = members.indexWhere((m) => m.id == oldPayment.memberId);
    if (mIdx == -1) throw Exception('Member not found');
    final member = members[mIdx];

    final updatedMember = member.copyWith(
      amountPaid: (member.amountPaid + delta).clamp(0, double.infinity),
      amountDue: (member.amountDue - delta).clamp(0, double.infinity),
    );
    members[mIdx] = updatedMember;
    await _writeMembers(members);

    payments[pIdx] = Payment(
      id: oldPayment.id,
      memberId: oldPayment.memberId,
      amount: newAmount,
      date: date ?? oldPayment.date,
      mode: mode ?? oldPayment.mode,
    );
    await _storage.writeFile('payments.json', jsonEncode(payments.map((p) => p.toJson()).toList()));

    return updatedMember;
  }

  /// Removes a payment entered by mistake and reopens the corresponding
  /// amount as due on the member. Does not touch plan/dates.
  Future<Member> deletePayment(String paymentId) async {
    final payments = await getPayments();
    final pIdx = payments.indexWhere((p) => p.id == paymentId);
    if (pIdx == -1) throw Exception('Payment not found');
    final oldPayment = payments[pIdx];

    final members = await getMembers();
    final mIdx = members.indexWhere((m) => m.id == oldPayment.memberId);
    if (mIdx == -1) throw Exception('Member not found');
    final member = members[mIdx];

    final updatedMember = member.copyWith(
      amountPaid: (member.amountPaid - oldPayment.amount).clamp(0, double.infinity),
      amountDue: (member.amountDue + oldPayment.amount).clamp(0, double.infinity),
    );
    members[mIdx] = updatedMember;
    await _writeMembers(members);

    payments.removeAt(pIdx);
    await _storage.writeFile('payments.json', jsonEncode(payments.map((p) => p.toJson()).toList()));

    return updatedMember;
  }

  // ---------- Dashboard aggregates ----------

  Future<Map<String, int>> getDashboardCounts() async {
    final members = await getMembers();
    int active = 0, expiringSoon = 0, expired = 0, paid = 0, unpaid = 0;

    for (final m in members) {
      switch (m.status) {
        case MemberStatus.active:
          active++;
          break;
        case MemberStatus.expiringSoon:
          expiringSoon++;
          break;
        case MemberStatus.expired:
          expired++;
          break;
      }
      if (m.isPaid) {
        paid++;
      } else {
        unpaid++;
      }
    }

    return {
      'total': members.length,
      'active': active,
      'expiringSoon': expiringSoon,
      'expired': expired,
      'paid': paid,
      'unpaid': unpaid,
    };
  }
}
