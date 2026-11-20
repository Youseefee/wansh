import 'package:flutter/widgets.dart';

/// Bilingual (Arabic primary + English) UI strings for the Wenshy Customer app.
///
/// Domain enum labels, prices, distances, ETAs, and timestamps are delegated
/// to `WenshyLabels` in `package:wenshy_core/wenshy_core.dart`.
class AppStrings {
  const AppStrings(this.localeCode);

  final String localeCode;

  bool get isArabic => localeCode.toLowerCase().startsWith('ar');

  static AppStrings of(BuildContext context) {
    final code = Localizations.maybeLocaleOf(context)?.languageCode ?? 'ar';
    return AppStrings(code);
  }

  String _pick(String ar, String en) => isArabic ? ar : en;

  // Brand & General
  String get appName => _pick('ونشي', 'Wenshy');
  String get appSubtitle => _pick('إنقاذ الطريق السريع', 'Roadside Rescue');
  String get toggleLanguageLabel => _pick('EN', 'عربي');
  String get retry => _pick('إعادة المحاولة', 'Retry');
  String get save => _pick('حفظ', 'Save');
  String get cancel => _pick('إلغاء', 'Cancel');
  String get confirm => _pick('تأكيد', 'Confirm');
  String get delete => _pick('حذف', 'Delete');
  String get edit => _pick('تعديل', 'Edit');
  String get add => _pick('إضافة', 'Add');
  String get close => _pick('إغلاق', 'Close');
  String get loading => _pick('جاري التحميل...', 'Loading...');
  String get unexpectedError =>
      _pick('حدث خطأ غير متوقع، يرجى المحاولة لاحقاً.', 'Unexpected error, please try again.');
  String get requiredField => _pick('هذا الحقل مطلوب', 'This field is required');

  // Navigation Tabs
  String get navMap => _pick('الخريطة', 'Map');
  String get navTrips => _pick('رحلاتي', 'Trips');
  String get navVehicles => _pick('سياراتي', 'Vehicles');
  String get navProfile => _pick('حسابي', 'Profile');

  // Auth
  String get loginTitle => _pick('تسجيل الدخول', 'Sign In');
  String get loginSubtitle => _pick(
        'اطلب أقرب ونش إنقاذ لسيارتك في دقائق',
        'Request the nearest tow truck in minutes',
      );
  String get signupTitle => _pick('إنشاء حساب عميل', 'Customer Sign Up');
  String get signupSubtitle => _pick(
        'سجل حسابك لطلب خدمات السحب والإنقاذ بسهولة',
        'Create your account for fast roadside towing',
      );
  String get emailLabel => _pick('البريد الإلكتروني', 'Email');
  String get passwordLabel => _pick('كلمة المرور', 'Password');
  String get fullNameLabel => _pick('الاسم الكامل', 'Full Name');
  String get phoneLabel => _pick('رقم الهاتف', 'Phone Number');
  String get invalidEmail =>
      _pick('أدخل بريداً إلكترونياً صحيحاً', 'Enter a valid email address');
  String get weakPassword =>
      _pick('كلمة المرور يجب أن تكون 6 أحرف على الأقل', 'Password must be at least 6 characters');
  String get noAccountPrompt => _pick('ليس لديك حساب؟', "Don't have an account?");
  String get createAccountBtn => _pick('إنشاء حساب جديد', 'Create Account');
  String get haveAccountPrompt => _pick('لديك حساب بالفعل؟', 'Already have an account?');
  String get signOut => _pick('تسجيل الخروج', 'Sign Out');
  String get checkEmailConfirm => _pick(
        'تم إنشاء الحساب! يرجى تأكيد بريدك الإلكتروني إذا طُلب منك ثم تسجيل الدخول.',
        'Account created! Please verify your email if required and sign in.',
      );
  String get wrongRoleWarning => _pick(
        'تنبيه: هذا الحساب مسجل كسائق أو مشرف وليس عميلاً. بعض الميزات قد تتطلب حساب عميل.',
        'Notice: This account is not registered as a customer role.',
      );
  String get emailLoginTab => _pick('البريد الإلكتروني', 'Email');
  String get phoneOtpLoginTab => _pick('رقم الهاتف (OTP)', 'Phone OTP');
  String get forgotPasswordBtn => _pick('نسيت كلمة المرور؟', 'Forgot Password?');
  String get forgotPasswordTitle =>
      _pick('استعادة كلمة المرور', 'Reset Password');
  String get forgotPasswordSubtitle => _pick(
        'أدخل بريدك الإلكتروني وسنرسل لك رابطاً لإعادة تعيين كلمة المرور.',
        'Enter your email address and we will send you a password reset link.',
      );
  String get sendResetLinkBtn => _pick('إرسال رابط الاستعادة', 'Send Reset Link');
  String get passwordResetSent => _pick(
        'تم إرسال رابط إعادة تعيين كلمة المرور إلى بريدك الإلكتروني.',
        'Password reset link sent to your email.',
      );
  String get phoneHint => _pick('مثال: +201001234567', 'e.g. +201001234567');
  String get invalidPhone => _pick(
        'أدخل رقم هاتف صحيحاً مع كود الدولة (مثال: +2010...)',
        'Enter a valid phone number with country code (e.g. +2010...)',
      );
  String get sendOtpBtn => _pick('إرسال رمز التحقق', 'Send Verification Code');
  String get otpCodeLabel => _pick('رمز التحقق (OTP)', 'Verification Code (OTP)');
  String get invalidOtpCode =>
      _pick('أدخل رمز التحقق المكون من 6 أرقام', 'Enter the 6-digit verification code');
  String get verifyOtpBtn => _pick('تحقق وتسجيل الدخول', 'Verify & Sign In');
  String get changePhoneBtn => _pick('تغيير رقم الهاتف', 'Change Phone Number');
  String get resendOtpBtn => _pick('إعادة إرسال الرمز', 'Resend Code');
  String get otpSentInfo => _pick(
        'تم إرسال رمز التحقق عبر رسالة نصية إلى هاتفك.',
        'A verification code has been sent via SMS to your phone.',
      );

  // Profile
  String get profileTitle => _pick('الملف الشخصي', 'My Profile');
  String get editProfile => _pick('تعديل البيانات', 'Edit Profile');
  String get profileUpdated => _pick('تم تحديث الملف الشخصي بنجاح', 'Profile updated successfully');
  String get languageSetting => _pick('لغة التطبيق', 'App Language');
  String get arabicName => _pick('العربية (RTL)', 'Arabic (RTL)');
  String get englishName => _pick('English (LTR)', 'English (LTR)');
  String get complaintsAndSupport => _pick('الشكاوى والدعم', 'Complaints & Support');
  String get deleteAccountBtn => _pick('حذف الحساب', 'Delete Account');
  String get deleteAccountTitle => _pick('تأكيد حذف الحساب', 'Confirm Account Deletion');
  String get deleteAccountWarning => _pick(
        'سيتم إخفاء بيانات حسابك وتعطيله نهائياً ولا يمكن التراجع عن هذا الإجراء. لا يمكن حذف الحساب أثناء وجود رحلة نشطة.',
        'Your account data will be anonymized and deactivated permanently. This cannot be undone, and is blocked while you have an active trip.',
      );
  String get deleteAccountReasonHint =>
      _pick('سبب حذف الحساب (اختياري)', 'Reason for deleting account (optional)');
  String get deleteAccountActiveTripError => _pick(
        'لا يمكنك حذف حسابك أثناء وجود رحلة إنقاذ نشطة. يرجى إنهاء الرحلة أو إلغاؤها أولاً.',
        'You cannot delete your account while you have an active rescue trip. Please complete or cancel it first.',
      );
  String get accountDeletedInfo => _pick(
        'تم حذف حسابك بنجاح.',
        'Your account has been deleted.',
      );

  // Home Map
  String get detectMyLocation => _pick('موقعي الحالي', 'My Location');
  String get pickingPickupMode => _pick('تحديد موقع العطل', 'Pick Pickup');
  String get pickingDropoffMode => _pick('تحديد الوجهة', 'Pick Dropoff');
  String get tapMapForPickup => _pick(
        'اضغط على الخريطة لتحديد موقع العطل (الاستلام)',
        'Tap the map to set breakdown pickup point',
      );
  String get tapMapForDropoff => _pick(
        'اضغط على الخريطة لتحديد وجهة التوصيل',
        'Tap the map to set dropoff destination',
      );
  String get pickupPointLabel => _pick('موقع العطل (الاستلام)', 'Pickup Location');
  String get dropoffPointLabel => _pick('وجهة التوصيل', 'Dropoff Destination');
  String get pickupAddressHint => _pick('عنوان موقع العطل أو أقرب معلم', 'Pickup address or landmark');
  String get dropoffAddressHint => _pick('عنوان الوجهة أو الورشة', 'Dropoff address or workshop');
  String get nearbyWinchesCount => _pick('الأوناش المتاحة بالقرب منك', 'Nearby Available Winches');
  String get noNearbyWinches =>
      _pick('لا توجد أوناش متصلة في هذا النطاق حالياً', 'No online winches nearby right now');
  String get selectWinchType => _pick('نوع الونش المطلوب', 'Select Winch Type');
  String get requestWinchCta => _pick('طلب ونش الآن', 'Request Winch');
  String get selectPickupAndDropoffFirst => _pick(
        'يرجى تحديد موقع العطل والوجهة على الخريطة أولاً',
        'Please select both pickup and dropoff points first',
      );
  String get activeTripBanner => _pick('لديك رحلة إنقاذ نشطة الآن', 'You have an active rescue trip');
  String get resumeTracking => _pick('متابعة التتبع', 'Track Now');
  String get locationPermissionDenied => _pick(
        'تعذر الوصول للموقع. تم استخدام موقع القاهرة الافتراضي، ويمكنك النقر على الخريطة للتحديد.',
        'Location access unavailable. Centered on Cairo; tap map to pick points.',
      );

  // Request & Quotation
  String get requestRescueTitle => _pick('تفاصيل طلب الإنقاذ', 'Rescue Request Details');
  String get routeSummary => _pick('ملخص المسار', 'Route Summary');
  String get vehicleSelection => _pick('بيانات السيارة المعطلة', 'Breakdown Vehicle');
  String get savedVehiclesLabel => _pick('سياراتك المحفوظة', 'Saved Vehicles');
  String get enterVehicleManually => _pick('إدخال سيارة أخرى', 'Other Vehicle');
  String get vehicleMake => _pick('الماركة (مثال: تويوتا)', 'Make (e.g. Toyota)');
  String get vehicleModel => _pick('الموديل (مثال: كورولا)', 'Model (e.g. Corolla)');
  String get vehicleYear => _pick('سنة الصنع', 'Year');
  String get vehicleColor => _pick('اللون', 'Color');
  String get vehiclePlate => _pick('رقم اللوحة', 'Plate Number');
  String get vehicleCategory => _pick('فئة السيارة', 'Vehicle Category');
  String get breakdownDetails => _pick('تفاصيل العطل والصور', 'Breakdown Info & Photos');
  String get breakdownReason => _pick('سبب العطل (مثال: بطارية، حادث، إطارات)', 'Breakdown Reason');
  String get breakdownNotes => _pick('ملاحظات إضافية للسائق', 'Notes for Driver');
  String get addPhotos => _pick('إضافة صور للعطل', 'Add Breakdown Photos');
  String get camera => _pick('الكاميرا', 'Camera');
  String get gallery => _pick('المعرض', 'Gallery');
  String get paymentMethodLabel => _pick('طريقة الدفع', 'Payment Method');
  String get liveQuoteTitle => _pick('التسعيرة المباشرة من الخادم', 'Live Server Quotation');
  String get calculatingQuote => _pick('جاري حساب التكلفة...', 'Calculating quote...');
  String get baseFare => _pick('فتح العداد', 'Base Fare');
  String get perKm => _pick('سعر الكيلومتر', 'Price / km');
  String get estimatedDistance => _pick('المسافة التقديرية', 'Estimated Distance');
  String get estimatedDuration => _pick('الوقت التقديري', 'Estimated Duration');
  String get priceRange => _pick('النطاق المتوقع', 'Expected Range');
  String get estimatedTotal => _pick('السعر التقديري', 'Estimated Total');
  String get confirmRequestBtn => _pick('تأكيد وإرسال الطلب', 'Confirm & Dispatch Winch');
  String get vehiclePlateRequired =>
      _pick('يرجى اختيار سيارة محفوظة أو إدخال الماركة والموديل ورقم اللوحة', 'Select a saved vehicle or enter make, model, and plate');

  // Live Trip Tracker
  String get liveTrackingTitle => _pick('تتبع رحلة الإنقاذ', 'Live Rescue Tracker');
  String get searchingDriversTitle =>
      _pick('جاري البحث عن أقرب سائق ونش...', 'Searching for nearest tow truck...');
  String currentWaveLabel(int wave) =>
      _pick('موجة البحث رقم $wave', 'Dispatch Wave #$wave');
  String driversNotifiedLabel(int count) =>
      _pick('تم إرسال الطلب إلى $count سائقين', 'Dispatched to $count nearby drivers');
  String get expandSearchWaveBtn =>
      _pick('توسيع نطاق البحث (الموجة التالية)', 'Expand Search (Next Wave)');
  String get noMoreDriversFound => _pick(
        'لم يتم العثور على سائقين إضافيين في هذا النطاق الآن، حاول مرة أخرى بعد لحظات.',
        'No additional drivers found in range right now. Please try again shortly.',
      );
  String get tripProgress => _pick('مراحل الرحلة', 'Trip Progress');
  String get driverAndWinchInfo => _pick('بيانات السائق والونش', 'Driver & Winch Info');
  String get cancelTripBtn => _pick('إلغاء الطلب', 'Cancel Request');
  String get cancelReasonHint => _pick('سبب الإلغاء (اختياري)', 'Cancellation reason (optional)');
  String get confirmCancelTitle => _pick('تأكيد إلغاء الطلب', 'Confirm Cancellation');
  String get confirmCancelBody => _pick(
        'هل أنت متأكد من إلغاء طلب الإنقاذ الحالي؟',
        'Are you sure you want to cancel this rescue request?',
      );
  String get rateTripCta => _pick('تقييم السائق', 'Rate Driver');
  String get fileComplaintCta => _pick('تقديم شكوى', 'File Complaint');
  String get newRequestCta => _pick('طلب ونش جديد', 'New Rescue Request');
  String get liveGpsActive => _pick('بث الموقع المباشر مفعل', 'Live GPS stream active');

  // Saved Vehicles
  String get myVehiclesTitle => _pick('سياراتي المحفوظة', 'My Saved Vehicles');
  String get addVehicleTitle => _pick('إضافة سيارة جديدة', 'Add New Vehicle');
  String get editVehicleTitle => _pick('تعديل بيانات السيارة', 'Edit Vehicle');
  String get noVehiclesEmpty => _pick(
        'لم تقم بحفظ أي سيارات بعد. أضف سيارتك لطلب أسرع وقت الطوارئ.',
        'No saved vehicles yet. Add your car for faster emergency requests.',
      );
  String get setAsDefault => _pick('تعيين كافتراضية', 'Set as Default');
  String get defaultBadge => _pick('الافتراضية', 'Default');
  String get confirmDeleteVehicle =>
      _pick('هل تريد حذف هذه السيارة؟', 'Delete this saved vehicle?');

  // Trips History & Details
  String get tripsHistoryTitle => _pick('سجل رحلات الإنقاذ', 'Rescue Trips History');
  String get filterAll => _pick('الكل', 'All');
  String get filterActive => _pick('نشطة', 'Active');
  String get filterCompleted => _pick('مكتملة', 'Completed');
  String get filterCancelled => _pick('ملغاة', 'Cancelled');
  String get noTripsEmpty => _pick('لا توجد رحلات إنقاذ حتى الآن.', 'No rescue trips yet.');
  String get tripDetailsTitle => _pick('تفاصيل الرحلة', 'Trip Details');
  String get statusTimelineLog => _pick('سجل تغييرات الحالة', 'Status Audit Log');
  String get breakdownPhotosTitle => _pick('صور العطل', 'Breakdown Photos');
  String get finalPriceLabel => _pick('السعر النهائي', 'Final Price');

  // Ratings
  String get rateTripTitle => _pick('تقييم رحلة الإنقاذ', 'Rate Your Rescue Trip');
  String get howWasService => _pick('كيف كانت خدمة الإنقاذ؟', 'How was the rescue service?');
  String get ratingCommentHint => _pick('اكتب تعليقك عن السائق والخدمة...', 'Share your feedback...');
  String get submitRatingBtn => _pick('إرسال التقييم', 'Submit Rating');
  String get ratingSubmitted => _pick('شكراً لك! تم حفظ تقييمك بنجاح.', 'Thank you! Rating submitted.');
  String get alreadyRatedTitle => _pick('تم تقييم هذه الرحلة مسبقاً', 'You already rated this trip');
  List<String> get ratingTags => isArabic
      ? const <String>[
          'سرعة الوصول',
          'تعامل راقي',
          'أمان في التحميل',
          'الالتزام بالسعر',
          'ونش نظيف ومجهز',
        ]
      : const <String>[
          'Fast Arrival',
          'Polite Driver',
          'Safe Loading',
          'Fair Pricing',
          'Well-Equipped Truck',
        ];

  // Complaints
  String get complaintsTitle => _pick('الشكاوى والدعم الفني', 'Complaints & Support');
  String get fileComplaintTitle => _pick('تقديم شكوى جديدة', 'File a Complaint');
  String get noComplaintsEmpty => _pick('لا توجد شكاوى مسجلة.', 'No complaints filed yet.');
  String get complaintCategoryLabel => _pick('تصنيف الشكوى', 'Category');
  String get complaintSubjectLabel => _pick('عنوان الشكوى', 'Subject');
  String get complaintDescriptionLabel => _pick('تفاصيل المشكلة', 'Description');
  String get evidencePhotosLabel => _pick('إرفاق صور أو مستندات إثبات', 'Attach Evidence Photos');
  String get submitComplaintBtn => _pick('إرسال الشكوى', 'Submit Complaint');
  String get complaintSubmitted =>
      _pick('تم إرسال الشكوى بنجاح وسيتابعها فريق الدعم.', 'Complaint submitted successfully.');
  String get adminResponseLabel => _pick('رد الإدارة', 'Admin Notes');

  // Place Search & Road Routing
  String get searchPlaceTitlePickup =>
      _pick('ابحث عن موقع العطل', 'Search Pickup Location');
  String get searchPlaceTitleDropoff =>
      _pick('ابحث عن وجهة التوصيل', 'Search Dropoff Destination');
  String get searchPlaceHint => _pick(
        'اكتب اسم الشارع أو الحي أو المعلم...',
        'Type street, district, or landmark...',
      );
  String get searchPlaceNoResults => _pick(
        'لم يتم العثور على نتائج مطابقة. جرب كلمات أخرى أو حدد على الخريطة.',
        'No matching places found. Try another query or tap the map.',
      );
  String get searchPlaceStartTyping => _pick(
        'ابدأ الكتابة للبحث عن العناوين في مصر',
        'Start typing to search places in Egypt',
      );
  String get roadRouteSummary => _pick('مسار الطريق', 'Road Route');
  String get calculatingRoute =>
      _pick('جاري حساب مسار الطريق...', 'Calculating road route...');
  String get resolvingAddress =>
      _pick('جاري تحديد العنوان...', 'Resolving address...');

  // Direct Phone Call
  String get callDriverBtn => _pick('اتصل بالسائق', 'Call Driver');
  String get callFailedError => _pick(
        'تعذر فتح تطبيق الاتصال على هذا الجهاز.',
        'Unable to launch phone dialer on this device.',
      );

  // Notifications Inbox
  String get notificationsTitle => _pick('الإشعارات', 'Notifications');
  String get markAllReadBtn => _pick('تحديد الكل كمقروء', 'Mark All Read');
  String get noNotificationsEmpty => _pick(
        'لا توجد إشعارات حالياً. ستصلك التحديثات الفورية لرحلاتك هنا.',
        'No notifications yet. Live updates about your rescue trips will appear here.',
      );
}
