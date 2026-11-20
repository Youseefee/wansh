import 'package:intl/intl.dart';

import '../models/enums.dart';

/// Arabic (primary) and English localization helpers for Wenshy domain enums,
/// trip lifecycle stages, and numeric/unit formatting.
abstract final class WenshyLabels {
  /// Primary Arabic brand name.
  static const String appNameAr = 'ونشي';

  /// Primary English brand name.
  static const String appNameEn = 'Wenshy';

  /// Localized Wenshy brand name (`ونشي` / `Wenshy`).
  static String appName({String locale = 'ar'}) =>
      _pick(locale, appNameAr, appNameEn);

  /// Localized Wenshy brand tagline.
  static String appTagline({String locale = 'ar'}) => _pick(
        locale,
        'إنقاذ الطريق السريع على مدار الساعة',
        '24/7 Fast Roadside Rescue',
      );

  /// Returns `true` when [locale] represents Arabic (`'ar'`, `'ar_EG'`, etc.).
  static bool isArabic(String locale) =>
      locale.trim().toLowerCase().startsWith('ar');

  static String _pick(String locale, String ar, String en) =>
      isArabic(locale) ? ar : en;

  /// Localized label for [AppRole].
  static String appRole(AppRole role, {String locale = 'ar'}) => switch (role) {
        AppRole.customer => _pick(locale, 'عميل', 'Customer'),
        AppRole.driver => _pick(locale, 'سائق ونش', 'Tow Driver'),
        AppRole.admin => _pick(locale, 'مشرف', 'Admin'),
      };

  /// Localized label for [DriverApprovalStatus].
  static String driverApprovalStatus(
    DriverApprovalStatus status, {
    String locale = 'ar',
  }) =>
      switch (status) {
        DriverApprovalStatus.pending =>
          _pick(locale, 'قيد الانتظار', 'Pending'),
        DriverApprovalStatus.underReview =>
          _pick(locale, 'قيد المراجعة', 'Under Review'),
        DriverApprovalStatus.approved => _pick(locale, 'معتمد', 'Approved'),
        DriverApprovalStatus.rejected => _pick(locale, 'مرفوض', 'Rejected'),
        DriverApprovalStatus.suspended => _pick(locale, 'موقوف', 'Suspended'),
      };

  /// Detailed guidance text for each [DriverApprovalStatus] on the approval
  /// gate screen.
  static String driverApprovalDescription(
    DriverApprovalStatus status, {
    String locale = 'ar',
  }) =>
      switch (status) {
        DriverApprovalStatus.pending => _pick(
            locale,
            'يرجى استكمال بيانات الونش ورفع المستندات المطلوبة لتفعيل حسابك.',
            'Please add your tow truck details and upload required KYC documents to activate your account.',
          ),
        DriverApprovalStatus.underReview => _pick(
            locale,
            'تم استلام مستنداتك وجارٍ مراجعتها من فريق ونشي.',
            'Your documents have been received and are being reviewed by the Wenshy team.',
          ),
        DriverApprovalStatus.approved => _pick(
            locale,
            'حسابك معتمد وجاهز لاستقبال طلبات الإنقاذ.',
            'Your account is approved and ready to receive rescue requests.',
          ),
        DriverApprovalStatus.rejected => _pick(
            locale,
            'تم رفض طلب الانضمام. يرجى مراجعة السبب وإعادة رفع المستندات المطلوبة.',
            'Your application was rejected. Review the reason below and re-upload the requested documents.',
          ),
        DriverApprovalStatus.suspended => _pick(
            locale,
            'تم إيقاف الحساب مؤقتاً. يرجى التواصل مع الدعم الفني.',
            'Your account is currently suspended. Please contact support.',
          ),
      };

  /// Localized label for [TripStatus] (matching SQL comments in Migration 001).
  static String tripStatus(TripStatus status, {String locale = 'ar'}) =>
      switch (status) {
        TripStatus.searching =>
          _pick(locale, 'في انتظار سائق', 'Searching for Driver'),
        TripStatus.driverAssigned =>
          _pick(locale, 'تم قبول الطلب وتعيين السائق', 'Driver Assigned'),
        TripStatus.enRouteToPickup =>
          _pick(locale, 'السائق في الطريق لموقع العطل', 'En Route to Pickup'),
        TripStatus.arrivedAtPickup =>
          _pick(locale, 'السائق وصل لموقع العطل', 'Arrived at Pickup'),
        TripStatus.vehicleLoaded =>
          _pick(locale, 'تم تحميل السيارة على الونش', 'Vehicle Loaded'),
        TripStatus.enRouteToDropoff =>
          _pick(locale, 'في الطريق للوجهة', 'En Route to Dropoff'),
        TripStatus.delivered =>
          _pick(locale, 'تم التوصيل بنجاح', 'Delivered'),
        TripStatus.cancelled => _pick(locale, 'تم إلغاء الطلب', 'Cancelled'),
        TripStatus.expired =>
          _pick(locale, 'انتهت مهلة البحث دون قبول', 'Expired'),
      };

  /// Short concise label for compact timeline chips and status pills.
  static String tripStatusShort(TripStatus status, {String locale = 'ar'}) =>
      switch (status) {
        TripStatus.searching => _pick(locale, 'جاري البحث', 'Searching'),
        TripStatus.driverAssigned => _pick(locale, 'تم التعيين', 'Assigned'),
        TripStatus.enRouteToPickup =>
          _pick(locale, 'في الطريق إليك', 'En Route'),
        TripStatus.arrivedAtPickup =>
          _pick(locale, 'وصل للموقع', 'Arrived'),
        TripStatus.vehicleLoaded => _pick(locale, 'تم التحميل', 'Loaded'),
        TripStatus.enRouteToDropoff =>
          _pick(locale, 'متجه للوجهة', 'Towing'),
        TripStatus.delivered => _pick(locale, 'تم التوصيل', 'Delivered'),
        TripStatus.cancelled => _pick(locale, 'ملغي', 'Cancelled'),
        TripStatus.expired => _pick(locale, 'منتهي', 'Expired'),
      };

  /// Driver CTA label to transition into [nextStatus].
  static String tripStageAction(TripStatus nextStatus, {String locale = 'ar'}) =>
      switch (nextStatus) {
        TripStatus.enRouteToPickup =>
          _pick(locale, 'بدء التوجه لموقع العطل', 'Start Trip to Pickup'),
        TripStatus.arrivedAtPickup =>
          _pick(locale, 'تأكيد الوصول لموقع العطل', 'Arrived at Pickup'),
        TripStatus.vehicleLoaded =>
          _pick(locale, 'تأكيد تحميل السيارة', 'Confirm Vehicle Loaded'),
        TripStatus.enRouteToDropoff =>
          _pick(locale, 'بدء التوجه للوجهة', 'Start Tow to Dropoff'),
        TripStatus.delivered =>
          _pick(locale, 'إنهاء الرحلة وتأكيد التوصيل', 'Complete Delivery'),
        _ => tripStatus(nextStatus, locale: locale),
      };

  /// Localized label for [OfferStatus].
  static String offerStatus(OfferStatus status, {String locale = 'ar'}) =>
      switch (status) {
        OfferStatus.pending => _pick(locale, 'في الانتظار', 'Pending'),
        OfferStatus.accepted => _pick(locale, 'مقبول', 'Accepted'),
        OfferStatus.rejected => _pick(locale, 'مرفوض', 'Rejected'),
        OfferStatus.expired => _pick(locale, 'منتهي الصلاحية', 'Expired'),
        OfferStatus.cancelled => _pick(locale, 'ملغي', 'Cancelled'),
      };

  /// Localized label for [DocumentType].
  static String documentType(DocumentType type, {String locale = 'ar'}) =>
      switch (type) {
        DocumentType.nationalIdFront =>
          _pick(locale, 'البطاقة الشخصية (أمامي)', 'National ID (Front)'),
        DocumentType.nationalIdBack =>
          _pick(locale, 'البطاقة الشخصية (خلفي)', 'National ID (Back)'),
        DocumentType.driverLicenseFront =>
          _pick(locale, 'رخصة القيادة (أمامي)', 'Driver License (Front)'),
        DocumentType.driverLicenseBack =>
          _pick(locale, 'رخصة القيادة (خلفي)', 'Driver License (Back)'),
        DocumentType.winchLicenseFront =>
          _pick(locale, 'رخصة الونش (أمامي)', 'Winch License (Front)'),
        DocumentType.winchLicenseBack =>
          _pick(locale, 'رخصة الونش (خلفي)', 'Winch License (Back)'),
        DocumentType.criminalRecord =>
          _pick(locale, 'فيش وتشبيه (صحيفة الحالة الجنائية)', 'Criminal Record'),
        DocumentType.selfieWithId =>
          _pick(locale, 'صورة شخصية مع البطاقة', 'Selfie with ID'),
      };

  /// Localized label for [DocumentReviewStatus].
  static String documentReviewStatus(
    DocumentReviewStatus status, {
    String locale = 'ar',
  }) =>
      switch (status) {
        DocumentReviewStatus.pending =>
          _pick(locale, 'قيد المراجعة', 'Pending Review'),
        DocumentReviewStatus.approved => _pick(locale, 'مقبول', 'Approved'),
        DocumentReviewStatus.rejected => _pick(locale, 'مرفوض', 'Rejected'),
      };

  /// Localized label for [VehicleCategory].
  static String vehicleCategory(
    VehicleCategory category, {
    String locale = 'ar',
  }) =>
      switch (category) {
        VehicleCategory.sedan => _pick(locale, 'سيدان', 'Sedan'),
        VehicleCategory.hatchback => _pick(locale, 'هاتشباك', 'Hatchback'),
        VehicleCategory.suv => _pick(locale, 'دفع رباعي / SUV', 'SUV'),
        VehicleCategory.pickup => _pick(locale, 'بيك أب', 'Pickup'),
        VehicleCategory.van => _pick(locale, 'فان', 'Van'),
        VehicleCategory.luxuryLowClearance => _pick(
            locale,
            'سيارة فاخرة / منخفضة الارتفاع',
            'Luxury / Low Clearance',
          ),
        VehicleCategory.motorcycle =>
          _pick(locale, 'دراجة نارية', 'Motorcycle'),
        VehicleCategory.lightTruck =>
          _pick(locale, 'نقل خفيف', 'Light Truck'),
      };

  /// Localized label for [PaymentMethod].
  static String paymentMethod(PaymentMethod method, {String locale = 'ar'}) =>
      switch (method) {
        PaymentMethod.cash => _pick(locale, 'نقداً (كاش)', 'Cash'),
        PaymentMethod.card => _pick(locale, 'بطاقة بنكية', 'Card'),
        PaymentMethod.wallet => _pick(locale, 'محفظة إلكترونية', 'Wallet'),
      };

  /// Localized label for [PaymentStatus].
  static String paymentStatus(PaymentStatus status, {String locale = 'ar'}) =>
      switch (status) {
        PaymentStatus.pending => _pick(locale, 'في انتظار الدفع', 'Pending'),
        PaymentStatus.paid => _pick(locale, 'تم الدفع', 'Paid'),
        PaymentStatus.refunded => _pick(locale, 'مسترد', 'Refunded'),
        PaymentStatus.failed => _pick(locale, 'فشل الدفع', 'Failed'),
      };

  /// Localized label for [ComplaintCategory].
  static String complaintCategory(
    ComplaintCategory category, {
    String locale = 'ar',
  }) =>
      switch (category) {
        ComplaintCategory.pricing =>
          _pick(locale, 'مشكلة في التسعير', 'Pricing Issue'),
        ComplaintCategory.driverBehavior =>
          _pick(locale, 'سلوك السائق', 'Driver Behavior'),
        ComplaintCategory.customerBehavior =>
          _pick(locale, 'سلوك العميل', 'Customer Behavior'),
        ComplaintCategory.vehicleDamage =>
          _pick(locale, 'تلف أو ضرر بالمركبة', 'Vehicle Damage'),
        ComplaintCategory.delay =>
          _pick(locale, 'تأخير عن الموعد', 'Delay'),
        ComplaintCategory.appIssue =>
          _pick(locale, 'مشكلة تقنية بالتطبيق', 'App Issue'),
        ComplaintCategory.other => _pick(locale, 'أخرى', 'Other'),
      };

  /// Localized label for [ComplaintStatus].
  static String complaintStatus(
    ComplaintStatus status, {
    String locale = 'ar',
  }) =>
      switch (status) {
        ComplaintStatus.open => _pick(locale, 'مفتوحة', 'Open'),
        ComplaintStatus.inProgress =>
          _pick(locale, 'قيد المعالجة', 'In Progress'),
        ComplaintStatus.resolved => _pick(locale, 'تم الحل', 'Resolved'),
        ComplaintStatus.dismissed => _pick(locale, 'مرفوضة / مغلقة', 'Dismissed'),
      };

  static final NumberFormat _decimalFormat = NumberFormat('#,##0.##', 'en_US');
  static final DateFormat _dateTimeFormat = DateFormat('yyyy/MM/dd HH:mm');

  /// Formats a monetary amount with currency symbol (`ج.م` in Arabic, or
  /// [currency] code in English).
  static String formatPrice(
    num amount, {
    String currency = 'EGP',
    String locale = 'ar',
  }) {
    final formatted = _decimalFormat.format(amount);
    if (isArabic(locale) && currency.toUpperCase() == 'EGP') {
      return '$formatted ج.م';
    }
    return '$formatted $currency';
  }

  /// Formats a distance in kilometers.
  static String formatDistanceKm(num km, {String locale = 'ar'}) {
    final formatted = _decimalFormat.format(km);
    return isArabic(locale) ? '$formatted كم' : '$formatted km';
  }

  /// Formats a distance given in meters, switching to km at >= 1000m.
  static String formatDistanceMeters(int meters, {String locale = 'ar'}) {
    if (meters >= 1000) {
      final km = (meters / 1000.0);
      final formatted = NumberFormat('#,##0.0', 'en_US').format(km);
      return isArabic(locale) ? '$formatted كم' : '$formatted km';
    }
    return isArabic(locale) ? '$meters م' : '$meters m';
  }

  /// Formats an estimated duration in minutes.
  static String formatEtaMinutes(int minutes, {String locale = 'ar'}) {
    return isArabic(locale) ? '$minutes دقيقة' : '$minutes min';
  }

  /// Formats a [DateTime] into local `yyyy/MM/dd HH:mm`.
  static String formatDateTime(DateTime dateTime) =>
      _dateTimeFormat.format(dateTime.toLocal());

  /// Formats a human-friendly relative timestamp for notifications and trip
  /// activity feeds.
  static String formatRelativeTime(
    DateTime dateTime, {
    DateTime? now,
    String locale = 'ar',
  }) {
    final reference = (now ?? DateTime.now()).toUtc();
    final diff = reference.difference(dateTime.toUtc());
    if (diff.inSeconds < 60) {
      return _pick(locale, 'الآن', 'Just now');
    }
    if (diff.inMinutes < 60) {
      final m = diff.inMinutes;
      return isArabic(locale) ? 'منذ $m دقيقة' : '${m}m ago';
    }
    if (diff.inHours < 24) {
      final h = diff.inHours;
      return isArabic(locale) ? 'منذ $h ساعة' : '${h}h ago';
    }
    if (diff.inDays < 7) {
      final d = diff.inDays;
      return isArabic(locale) ? 'منذ $d يوم' : '${d}d ago';
    }
    return formatDateTime(dateTime);
  }
}
