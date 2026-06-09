/// All user-facing strings in one place.
/// Swap values for i18n without touching widgets.
abstract final class AppStrings {
  // ── App ───────────────────────────────────────────────────────────────────
  static const String appName       = 'ETC Rides';
  static const String appTagline    = 'Fast. Reliable. ETC.';

  // ── Onboarding ────────────────────────────────────────────────────────────
  static const String ob1Title      = 'Earn on Your Schedule';
  static const String ob1Subtitle   = 'Set your own hours and drive whenever you want — full control, every single day.';
  static const String ob2Title      = 'Get Jobs Near You';
  static const String ob2Subtitle   = 'Accept trip requests close to where you are and maximize every minute on the road.';
  static const String ob3Title      = 'Get Paid Fast';
  static const String ob3Subtitle   = 'Receive your earnings quickly, securely, and on time — every single time, guaranteed.';
  static const String getStarted    = 'GET STARTED';
  static const String skip          = 'Skip';

  // ── Auth ──────────────────────────────────────────────────────────────────
  static const String startJourney  = 'Start driving with\nETCRide.';
  static const String continueBtn   = 'CONTINUE';
  static const String loginTitle    = 'Log in to continue';
  static const String emailOrPhone  = 'Email or Phone';
  static const String password      = 'Password';
  static const String loginBtn      = 'LOG IN';
  static const String alreadyHaveAccount = 'Already have an account?';
  static const String loginLink = 'Log in';
  static const String forgotPassword = 'Forgot password?';
  static const String resetPassword  = 'Reset password';
  static const String sendResetCode  = 'Send reset code';
  static const String resetCode      = 'Reset code';
  static const String newPassword    = 'New password';
  static const String confirmNewPassword = 'Confirm new password';
  static const String saveNewPassword = 'Save new password';
  static const String createAccount = 'Create account';
  static const String enterOtp      = 'Enter the 6-digit code sent to your number';
  static const String verifyOtp     = 'VERIFY & CONTINUE';
  static const String resendCode    = 'Resend code in';
  static const String resendNow     = 'Resend now';
  static const String completeProfile = 'Complete your profile';
  static const String completeProfileSub = 'This helps drivers identify you and makes your rides smoother.';
  static const String fullName      = 'Full Name';
  static const String emailAddress  = 'Email Address';
  static const String phoneNumber   = 'Phone Number';
  static const String updateProfile = 'UPDATE PROFILE';
  static const String skipForNow    = 'Skip';
  static const String startJourneySub   = 'Enter your phone number or email to get started.';
  static const String otpSentNote       = 'A one-time code will be sent to verify your identity.';
  static const String otpSentEmail      = 'Enter the 6-digit code sent to your email';
  static const String otpSentPhone      = 'Enter the 6-digit code sent via SMS';
  static const String saveProfile       = 'SAVE & CONTINUE';
  static const String confirmPassword   = 'Confirm Password';

  // ── Location permission ───────────────────────────────────────────────────
  static const String enableLocation     = 'Enable your location';
  static const String enableLocationSub  = 'We use your location to find nearby drivers and get you moving faster.';
  static const String locationPrivacy    = 'Your location is used only to improve your ride experience, you can change this anytime in settings.';
  static const String allowLocation      = 'ALLOW LOCATION';

  // ── Home ──────────────────────────────────────────────────────────────────
  static const String goodMorning   = 'Good morning';
  static const String goodAfternoon = 'Good afternoon';
  static const String goodEvening   = 'Good evening';
  static const String whereTo       = 'Where to?';
  static const String scheduleDelivery = 'Schedule delivery';
  static const String rideTab       = 'Ride';
  static const String couriersTab   = 'Couriers';
  static const String savedPlaces   = 'Saved places';
  static const String chooseOnMap   = 'Choose location on map';
  static const String refreshMap    = 'Refresh map';
  static const String completeYourProfile = 'Complete your profile';

  // ── Drawer ────────────────────────────────────────────────────────────────
  static const String hello         = 'Hello';
  static const String bookATrip     = 'Book a trip';
  static const String sendAPackage  = 'Send a package';
  static const String myTripHistory = 'My Trip History';
  static const String settings      = 'Settings';
  static const String help          = 'Help';
  static const String support       = 'Support';

  // ── Booking ───────────────────────────────────────────────────────────────
  static const String whereAreYouGoing  = 'Where are you going?';
  static const String useCurrentLoc     = 'Use my current location';
  static const String searchInDiffCity  = 'Search in a different city';
  static const String confirmPickup     = 'Confirm pick up location';
  static const String confirmPickupBtn  = 'CONFIRM PICK-UP';
  static const String chooseYourRide    = 'Choose your ride';
  static const String confirmRideBtn    = 'CONFIRM RIDE';
  static const String addPaymentMethods = 'Add Payment Methods';
  static const String bankTransfer      = 'Bank Transfer';
  static const String cash              = 'Cash';
  static const String payWithFlutterwave = 'Pay with Flutterwave';
  static const String findingDriver     = 'Finding your driver...';
  static const String findingDriverSub  = 'This usually takes a few seconds';
  static const String cancelRequest     = 'CANCEL REQUEST';
  static const String arrivingIn        = 'Arriving in';
  static const String meetAtPickup      = 'Meet your driver at the pickup spot.';
  static const String addNote           = 'Add note for driver (optional)';
  static const String shareTripStatus   = 'Share trip status';
  static const String share             = 'Share';
  static const String cancel            = 'CANCEL';
  static const String needHelp          = 'NEED HELP?';
  static const String cancelRide        = 'Cancel ride?';
  static const String cancelRideConfirm = 'Are you sure you want to cancel?';
  static const String keepSearching     = 'KEEP SEARCHING';

  // ── Trip ──────────────────────────────────────────────────────────────────
  static const String headingToDestination = 'Heading to destination';
  static const String tripCompleted    = 'Trip completed 🎉';
  static const String howWasYourTrip   = 'How was your trip with';
  static const String payForTrip       = 'PAY FOR THE TRIP';
  static const String rebook           = 'Rebook';
  static const String tripHistory      = 'Trip History';
  static const String recentRides      = 'Your recent rides and deliveries';
  static const String allTab           = 'ALL';
  static const String ridesTab         = 'RIDES';
  static const String couriersHistTab  = 'COURIERS';
  static const String noTripsYet       = 'No Trips Yet';
  static const String noTripsSub       = 'Book your first ride or send a package';
  static const String bookARide        = 'BOOK A RIDE';
  static const String viewReceipt      = 'View Receipt';
  static const String removeTrip       = 'REMOVE TRIP';
  static const String reportIssue      = 'REPORT ISSUE';
  static const String fareBreakdown    = 'Fare Breakdown';
  static const String thanksForRiding  = 'Thanks for riding with ETC';

  // ── Payment ───────────────────────────────────────────────────────────────
  static const String payViaBankTransfer = 'Pay via Bank Transfer';
  static const String transferExact    = 'Transfer the exact amount\nto the account below';
  static const String madePyament      = "I'VE MADE PAYMENT";

  // ── Courier ───────────────────────────────────────────────────────────────
  static const String sendPackage      = 'Send a package';
  static const String fastDelivery     = 'Fast and reliable delivery';
  static const String receiveDetails   = 'Receive Details';
  static const String senderPhone      = "Sender's Phone Number";
  static const String receiverPhone    = "Receiver's Phone Number";
  static const String packageDesc      = 'Package description';
  static const String describeParcel   = 'Describe the parcel';
  static const String confirmDelivery  = 'CONFIRM DELIVERY';
  static const String deliveryRules    = 'Delivery Rules';
  static const String deliveryRulesSub = 'Make sure before sending a parcel';
  static const String gotIt            = 'GOT IT';
  static const String driverHeading    = 'Driver heading to pickup';

  // ── Notifications ─────────────────────────────────────────────────────────
  static const String notifications    = 'Notifications';
  static const String noNotifYet       = 'No notifications yet';
  static const String noNotifSub       = "We'll notify you when something happens";
  static const String startFirstRide   = 'START YOUR FIRST RIDE';
  static const String today            = 'Today';
  static const String yesterday        = 'Yesterday';

  // ── Profile & Settings ────────────────────────────────────────────────────
  static const String profile          = 'Profile';
  static const String phoneLocked      = 'Cannot change phone number till after 30 days.';
  static const String settingsTitle    = 'Settings';
  static const String walletPayments   = 'Wallet & Payments';
  static const String comingSoon       = 'COMING SOON!';
  static const String legalDocuments   = 'Legal Documents';
  static const String appVersion       = 'App Version';
  static const String logout           = 'Log out';
  static const String deleteAccount    = 'Delete my account';
  static const String termsOfUse       = 'Terms of Use';
  static const String privacyPolicy    = 'Privacy Policy';

  // ── Help ──────────────────────────────────────────────────────────────────
  static const String helpSupport      = 'Help & Support';
  static const String getHelpFast      = 'Get Help Fast';
  static const String reportAnIssue    = 'Report an Issue';
  static const String contactSupport   = 'Contact Support';
  static const String commonTopics     = 'Common Topics';
  static const String faqs             = 'FAQs';
  static const String viewAllFaqs      = 'VIEW ALL FAQS';
  static const String allMessages      = 'All Messages';
  static const String active           = 'Active';
  static const String closed           = 'Closed';

  // ── Chat ──────────────────────────────────────────────────────────────────
  static const String typeMessage      = 'Type your message';
  static const String chatOnlyDuring   = 'Messages are only available during this trip';

  // ── Errors ────────────────────────────────────────────────────────────────
  static const String somethingWrong   = 'Something went wrong. Please try again.';
  static const String noInternet       = 'No internet connection.';
  static const String sessionExpired   = 'Session expired. Please log in again.';
  static const String profileIncomplete   = 'Please complete your profile before booking';
  static const String comingSoonMsg       = 'This feature is coming soon!';
}
