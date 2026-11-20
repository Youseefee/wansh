import 'package:wenshy_core/wenshy_core.dart';

/// Bilingual (Arabic primary / English) UI copy for the Wenshy Driver app.
/// Domain enum labels are delegated to [WenshyLabels] from `wenshy_core`.
abstract final class DriverStrings {
  static bool _ar(String locale) => WenshyLabels.isArabic(locale);

  static String t(String locale, String ar, String en) => _ar(locale) ? ar : en;

  static String appTitle(String locale) =>
      t(locale, 'ونشي - السائق', 'Wenshy Driver');

  static String toggleLanguageLabel(String locale) =>
      _ar(locale) ? 'EN' : 'عربي';

  // Auth
  static String loginTitle(String locale) =>
      t(locale, 'تسجيل دخول السائق', 'Driver Sign In');
  static String loginSubtitle(String locale) => t(
        locale,
        'ابدأ استقبال طلبات إنقاذ السيارات ومتابعة رحلاتك',
        'Start accepting roadside rescue jobs and track your trips',
      );
  static String registerTitle(String locale) =>
      t(locale, 'إنشاء حساب سائق ونش', 'Register as Tow Driver');
  static String registerSubtitle(String locale) => t(
        locale,
        'أدخل بياناتك ورخصة القيادة للانضمام إلى أسطول ونشي',
        'Enter your details and driving license to join the Wenshy fleet',
      );
  static String email(String locale) => t(locale, 'البريد الإلكتروني', 'Email');
  static String password(String locale) => t(locale, 'كلمة المرور', 'Password');
  static String fullName(String locale) => t(locale, 'الاسم الكامل', 'Full Name');
  static String phone(String locale) => t(locale, 'رقم الهاتف', 'Phone Number');
  static String nationalId(String locale) =>
      t(locale, 'الرقم القومي (14 رقم)', 'National ID Number');
  static String driverLicense(String locale) =>
      t(locale, 'رقم رخصة القيادة', 'Driver License Number');
  static String signIn(String locale) => t(locale, 'دخول', 'Sign In');
  static String createAccount(String locale) =>
      t(locale, 'إنشاء الحساب', 'Create Account');
  static String noAccountRegister(String locale) =>
      t(locale, 'سائق جديد؟ سجل الآن', 'New driver? Register now');
  static String haveAccountLogin(String locale) =>
      t(locale, 'لديك حساب بالفعل؟ تسجيل الدخول', 'Already registered? Sign in');
  static String signOut(String locale) => t(locale, 'تسجيل الخروج', 'Sign Out');
  static String forgotPassword(String locale) =>
      t(locale, 'نسيت كلمة المرور؟', 'Forgot Password?');
  static String resetPasswordTitle(String locale) =>
      t(locale, 'إعادة تعيين كلمة المرور', 'Reset Password');
  static String resetPasswordHint(String locale) => t(
        locale,
        'أدخل بريدك الإلكتروني وسنرسل لك رابطاً لإعادة تعيين كلمة المرور.',
        'Enter your email address and we will send you a password reset link.',
      );
  static String sendResetLink(String locale) =>
      t(locale, 'إرسال الرابط', 'Send Reset Link');
  static String passwordResetSent(String locale) => t(
        locale,
        'تم إرسال رابط إعادة تعيين كلمة المرور إلى بريدك الإلكتروني.',
        'A password reset link has been sent to your email.',
      );
  static String emailLoginTab(String locale) =>
      t(locale, 'البريد الإلكتروني', 'Email');
  static String phoneOtpLoginTab(String locale) =>
      t(locale, 'رمز الهاتف (OTP)', 'Phone OTP');
  static String sendOtpCode(String locale) =>
      t(locale, 'إرسال رمز التحقق', 'Send OTP Code');
  static String otpCodeLabel(String locale) =>
      t(locale, 'رمز التحقق (6 أرقام)', 'Verification Code (OTP)');
  static String verifyAndSignIn(String locale) =>
      t(locale, 'تأكيد وتسجيل الدخول', 'Verify & Sign In');
  static String otpSentSuccess(String locale) => t(
        locale,
        'تم إرسال رمز التحقق في رسالة نصية إلى هاتفك.',
        'Verification code sent via SMS to your phone.',
      );
  static String changePhoneNumber(String locale) =>
      t(locale, 'تغيير رقم الهاتف', 'Change Phone Number');

  // Navigation
  static String navHome(String locale) => t(locale, 'الرئيسية', 'Home');
  static String navHistory(String locale) =>
      t(locale, 'الرحلات والأرباح', 'Trips & Earnings');
  static String navComplaints(String locale) => t(locale, 'الشكاوى', 'Support');
  static String navProfile(String locale) => t(locale, 'حسابي', 'Profile');
  static String notificationsTitle(String locale) =>
      t(locale, 'الإشعارات', 'Notifications');
  static String markAllRead(String locale) =>
      t(locale, 'تحديد الكل كمقروء', 'Mark All Read');
  static String noNotificationsYet(String locale) =>
      t(locale, 'لا توجد إشعارات حالياً', 'No notifications yet');

  // Profile Editing & Account Deletion
  static String editProfile(String locale) =>
      t(locale, 'تعديل البيانات', 'Edit Profile');
  static String saveChanges(String locale) =>
      t(locale, 'حفظ التغييرات', 'Save Changes');
  static String profileUpdated(String locale) => t(
        locale,
        'تم تحديث بيانات حسابك بنجاح.',
        'Your profile has been updated.',
      );
  static String deleteAccount(String locale) =>
      t(locale, 'حذف الحساب', 'Delete Account');
  static String deleteAccountTitle(String locale) =>
      t(locale, 'تأكيد حذف الحساب', 'Confirm Account Deletion');
  static String deleteAccountWarning(String locale) => t(
        locale,
        'سيتم إيقاف حسابك وإخفاء بياناتك الشخصية بشكل نهائي ولا يمكن التراجع عن هذا الإجراء. لا يمكن حذف الحساب أثناء وجود رحلة جارية.',
        'Your account will be permanently deactivated and your personal data anonymized. This action cannot be undone and is blocked while you have an active trip.',
      );
  static String deleteReasonOptional(String locale) =>
      t(locale, 'سبب الحذف (اختياري)', 'Reason for leaving (optional)');
  static String deleteAccountActiveTripError(String locale) => t(
        locale,
        'لا يمكنك حذف الحساب أثناء وجود رحلة إنقاذ جارية. أكمل الرحلة أو ألغها أولاً.',
        'You cannot delete your account while you have an active rescue trip. Complete or cancel it first.',
      );

  // Onboarding & Approval Gate
  static String approvalGateTitle(String locale) =>
      t(locale, 'حالة اعتماد الحساب', 'Account Verification');
  static String rejectionReasonLabel(String locale) =>
      t(locale, 'سبب الرفض:', 'Rejection Reason:');
  static String setupWinchStep(String locale) =>
      t(locale, 'بيانات الونش وصوره', 'Tow Truck Details & Photos');
  static String uploadKycStep(String locale) =>
      t(locale, 'المستندات الرسمية (KYC)', 'KYC Compliance Documents');
  static String refreshStatus(String locale) =>
      t(locale, 'تحديث الحالة', 'Refresh Status');
  static String winchSetupTitle(String locale) =>
      t(locale, 'تسجيل بيانات الونش', 'Tow Truck Setup');
  static String kycUploadTitle(String locale) =>
      t(locale, 'رفع المستندات المطلوبة', 'KYC Documents');
  static String reuploadDoc(String locale) =>
      t(locale, 'إعادة الرفع', 'Re-upload');
  static String uploadDoc(String locale) => t(locale, 'رفع المستند', 'Upload');
  static String pickFromCamera(String locale) => t(locale, 'الكاميرا', 'Camera');
  static String pickFromGallery(String locale) =>
      t(locale, 'معرض الصور', 'Gallery');

  // Dispatch & Home
  static String onlineLabel(String locale) =>
      t(locale, 'متصل وجاهز للطلبات', 'Online & Available');
  static String offlineLabel(String locale) =>
      t(locale, 'غير متصل حالياً', 'Currently Offline');
  static String waitingForOffers(String locale) => t(
        locale,
        'جاري انتظار طلبات الإنقاذ القريبة منك...',
        'Listening for nearby rescue offers...',
      );
  static String goOnlinePrompt(String locale) => t(
        locale,
        'فعّل حالة الاتصال لبدء استقبال طلبات الإنقاذ الفورية',
        'Go online to start receiving real-time rescue offers',
      );
  static String incomingOfferTitle(String locale) =>
      t(locale, 'طلب إنقاذ جديد!', 'New Rescue Offer!');
  static String acceptOffer(String locale) => t(locale, 'قبول الطلب', 'Accept');
  static String rejectOffer(String locale) => t(locale, 'رفض', 'Reject');
  static String activeTripBanner(String locale) =>
      t(locale, 'لديك رحلة إنقاذ جارية الآن', 'You have an active rescue trip');
  static String resumeTrip(String locale) =>
      t(locale, 'متابعة الرحلة', 'Resume Trip');

  // Active Trip
  static String activeTripTitle(String locale) =>
      t(locale, 'تفاصيل الرحلة الجارية', 'Active Rescue Trip');
  static String pickupPoint(String locale) =>
      t(locale, 'موقع العطل (الاستلام)', 'Pickup Location');
  static String dropoffPoint(String locale) =>
      t(locale, 'وجهة التوصيل', 'Dropoff Destination');
  static String customerDetails(String locale) =>
      t(locale, 'بيانات العميل والسيارة', 'Customer & Vehicle');
  static String cancelTrip(String locale) =>
      t(locale, 'إلغاء الرحلة', 'Cancel Trip');
  static String liveGpsActive(String locale) =>
      t(locale, 'بث الموقع المباشر نشط', 'Live GPS Broadcasting');
  static String breakdownPhotos(String locale) =>
      t(locale, 'صور العطل', 'Breakdown Photos');
  static String callCustomer(String locale) =>
      t(locale, 'اتصال بالعميل', 'Call Customer');
  static String navigateToPickup(String locale) =>
      t(locale, 'التوجيه لموقع العطل', 'Navigate to Pickup');
  static String navigateToDropoff(String locale) =>
      t(locale, 'التوجيه لوجهة التوصيل', 'Navigate to Dropoff');
  static String openInGoogleMaps(String locale) =>
      t(locale, 'خرائط جوجل', 'Google Maps');
  static String openInWaze(String locale) => t(locale, 'ويز (Waze)', 'Waze');
  static String externalLaunchFailed(String locale) => t(
        locale,
        'تعذر فتح التطبيق الخارجي على هذا الجهاز.',
        'Unable to open external app on this device.',
      );

  // History & Earnings
  static String totalTripsLabel(String locale) =>
      t(locale, 'إجمالي الرحلات', 'Total Trips');
  static String totalEarningsLabel(String locale) =>
      t(locale, 'إجمالي الأرباح', 'Total Earnings');
  static String avgRatingLabel(String locale) =>
      t(locale, 'متوسط التقييم', 'Avg Rating');
  static String noTripsYet(String locale) =>
      t(locale, 'لا توجد رحلات مسجلة بعد', 'No trips recorded yet');

  // Complaints
  static String newComplaint(String locale) =>
      t(locale, 'تقديم شكوى جديدة', 'Submit Complaint');
  static String complaintSubject(String locale) =>
      t(locale, 'عنوان الشكوى', 'Subject');
  static String complaintDescription(String locale) =>
      t(locale, 'تفاصيل المشكلة', 'Description');
  static String attachEvidence(String locale) =>
      t(locale, 'إرفاق صور / مستندات', 'Attach Evidence');
  static String submitComplaintBtn(String locale) =>
      t(locale, 'إرسال الشكوى', 'Submit Complaint');
  static String noComplaintsYet(String locale) =>
      t(locale, 'لا توجد شكاوى مقدمة', 'No complaints submitted');

  // Common errors
  static String acceptFailureMessage(String? reason, String locale) {
    return switch (reason) {
      'offer_expired' => t(
          locale,
          'انتهت مهلة هذا العرض قبل القبول.',
          'This offer expired before it could be accepted.',
        ),
      'offer_already_processed' => t(
          locale,
          'تمت معالجة هذا العرض مسبقاً.',
          'This offer has already been processed.',
        ),
      'driver_not_available' => t(
          locale,
          'أنت غير متاح أو غير متصل حالياً.',
          'You are currently offline or unavailable.',
        ),
      'request_already_assigned_or_cancelled' => t(
          locale,
          'تم قبول الطلب من سائق آخر أو ألغاه العميل.',
          'The request was claimed by another driver or cancelled.',
        ),
      _ => t(
          locale,
          'تعذر قبول الطلب. حاول مرة أخرى.',
          'Could not accept this offer. Please try again.',
        ),
    };
  }
}
