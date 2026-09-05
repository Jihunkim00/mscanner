import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_bn.dart';
import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_id.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_mr.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_te.dart';
import 'app_localizations_th.dart';
import 'app_localizations_tr.dart';
import 'app_localizations_ur.dart';
import 'app_localizations_vi.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('bn'),
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('hi'),
    Locale('id'),
    Locale('ja'),
    Locale('ko'),
    Locale('mr'),
    Locale('pt'),
    Locale('pt', 'BR'),
    Locale('ru'),
    Locale('te'),
    Locale('th'),
    Locale('tr'),
    Locale('ur'),
    Locale('vi'),
    Locale('zh'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')
  ];

  /// No description provided for @accountDeleted.
  ///
  /// In en, this message translates to:
  /// **'Account deleted successfully.'**
  String get accountDeleted;

  /// No description provided for @addToStatus.
  ///
  /// In en, this message translates to:
  /// **'Add to my status'**
  String get addToStatus;

  /// No description provided for @aiSetting.
  ///
  /// In en, this message translates to:
  /// **'AI Setting'**
  String get aiSetting;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? '**
  String get alreadyHaveAccount;

  /// No description provided for @areYouSureDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete your account? This action cannot be undone.'**
  String get areYouSureDeleteAccount;

  /// No description provided for @camera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get camera;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changePassword;

  /// No description provided for @cloudSave.
  ///
  /// In en, this message translates to:
  /// **'Cloud Save'**
  String get cloudSave;

  /// No description provided for @confirmDelete.
  ///
  /// In en, this message translates to:
  /// **'Confirm Delete'**
  String get confirmDelete;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// No description provided for @continueWithApple.
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get continueWithApple;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// No description provided for @dietMenu.
  ///
  /// In en, this message translates to:
  /// **'Diet Menu'**
  String get dietMenu;

  /// No description provided for @display.
  ///
  /// In en, this message translates to:
  /// **'Display'**
  String get display;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @engine.
  ///
  /// In en, this message translates to:
  /// **'Engine'**
  String get engine;

  /// No description provided for @enterYourEmailtoResetPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter your email to reset your password'**
  String get enterYourEmailtoResetPassword;

  /// No description provided for @failedChangePassword.
  ///
  /// In en, this message translates to:
  /// **'Failed to change password'**
  String get failedChangePassword;

  /// No description provided for @failedDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete account'**
  String get failedDeleteAccount;

  /// No description provided for @foodMenuMaxNumber.
  ///
  /// In en, this message translates to:
  /// **'Food Menu Max Number'**
  String get foodMenuMaxNumber;

  /// No description provided for @foodStyle.
  ///
  /// In en, this message translates to:
  /// **'Food Style'**
  String get foodStyle;

  /// No description provided for @foodStyleAIRecommend.
  ///
  /// In en, this message translates to:
  /// **'AI recommend'**
  String get foodStyleAIRecommend;

  /// No description provided for @foodStyleLowFat.
  ///
  /// In en, this message translates to:
  /// **'Low Fat'**
  String get foodStyleLowFat;

  /// No description provided for @foodStyleLowSalt.
  ///
  /// In en, this message translates to:
  /// **'Low salt'**
  String get foodStyleLowSalt;

  /// No description provided for @foodStyleMeat.
  ///
  /// In en, this message translates to:
  /// **'Meat'**
  String get foodStyleMeat;

  /// No description provided for @foodStyleMuslim.
  ///
  /// In en, this message translates to:
  /// **'Muslim'**
  String get foodStyleMuslim;

  /// No description provided for @foodStyleNutFree.
  ///
  /// In en, this message translates to:
  /// **'Nut-free'**
  String get foodStyleNutFree;

  /// No description provided for @foodStyleSeafood.
  ///
  /// In en, this message translates to:
  /// **'Seafood'**
  String get foodStyleSeafood;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password'**
  String get forgotPassword;

  /// No description provided for @hello.
  ///
  /// In en, this message translates to:
  /// **'Hello'**
  String get hello;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @languageArabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get languageArabic;

  /// No description provided for @languageBengali.
  ///
  /// In en, this message translates to:
  /// **'Bengali'**
  String get languageBengali;

  /// No description provided for @languageChinese.
  ///
  /// In en, this message translates to:
  /// **'Chinese'**
  String get languageChinese;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageFrench.
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get languageFrench;

  /// No description provided for @languageGerman.
  ///
  /// In en, this message translates to:
  /// **'German'**
  String get languageGerman;

  /// No description provided for @languageHindi.
  ///
  /// In en, this message translates to:
  /// **'Hindi'**
  String get languageHindi;

  /// No description provided for @languageIndonesian.
  ///
  /// In en, this message translates to:
  /// **'Indonesian'**
  String get languageIndonesian;

  /// No description provided for @languageJapanese.
  ///
  /// In en, this message translates to:
  /// **'Japanese'**
  String get languageJapanese;

  /// No description provided for @languageKorean.
  ///
  /// In en, this message translates to:
  /// **'Korean'**
  String get languageKorean;

  /// No description provided for @languageMarathi.
  ///
  /// In en, this message translates to:
  /// **'Marathi'**
  String get languageMarathi;

  /// No description provided for @languagePortuguese.
  ///
  /// In en, this message translates to:
  /// **'Portuguese'**
  String get languagePortuguese;

  /// No description provided for @languagePortugueseBrazil.
  ///
  /// In en, this message translates to:
  /// **'Portuguese(Brazil)'**
  String get languagePortugueseBrazil;

  /// No description provided for @languageRussian.
  ///
  /// In en, this message translates to:
  /// **'Russian'**
  String get languageRussian;

  /// No description provided for @languageSimplifiedChinese.
  ///
  /// In en, this message translates to:
  /// **'Simplified Chinese'**
  String get languageSimplifiedChinese;

  /// No description provided for @languageSpanish.
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get languageSpanish;

  /// No description provided for @languageTelugu.
  ///
  /// In en, this message translates to:
  /// **'Telugu'**
  String get languageTelugu;

  /// No description provided for @languageThai.
  ///
  /// In en, this message translates to:
  /// **'Thai'**
  String get languageThai;

  /// No description provided for @languageTraditionalChinese.
  ///
  /// In en, this message translates to:
  /// **'Traditional Chinese'**
  String get languageTraditionalChinese;

  /// No description provided for @languageTurkish.
  ///
  /// In en, this message translates to:
  /// **'Turkish'**
  String get languageTurkish;

  /// No description provided for @languageUrdu.
  ///
  /// In en, this message translates to:
  /// **'Urdu'**
  String get languageUrdu;

  /// No description provided for @languageVietnamese.
  ///
  /// In en, this message translates to:
  /// **'Vietnamese'**
  String get languageVietnamese;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get login;

  /// No description provided for @logIn.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get logIn;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logout;

  /// No description provided for @menuNumber1.
  ///
  /// In en, this message translates to:
  /// **'1'**
  String get menuNumber1;

  /// No description provided for @menuNumber1to3.
  ///
  /// In en, this message translates to:
  /// **'1-3'**
  String get menuNumber1to3;

  /// No description provided for @menuNumber1to5.
  ///
  /// In en, this message translates to:
  /// **'1-5'**
  String get menuNumber1to5;

  /// No description provided for @menuNumberAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get menuNumberAll;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get newPassword;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @passwordChangedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Password changed successfully.'**
  String get passwordChangedSuccess;

  /// No description provided for @passwordResetEmailSent.
  ///
  /// In en, this message translates to:
  /// **'Password reset email sent. Please check your inbox'**
  String get passwordResetEmailSent;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDoNotMatch;

  /// No description provided for @pleaseEnterPassword.
  ///
  /// In en, this message translates to:
  /// **'Please enter your password'**
  String get pleaseEnterPassword;

  /// No description provided for @pleaseEnterValidEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email'**
  String get pleaseEnterValidEmail;

  /// No description provided for @presetSelected.
  ///
  /// In en, this message translates to:
  /// **'Preset {presetId} selected'**
  String presetSelected(Object presetId);

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @requiresRecentLogin.
  ///
  /// In en, this message translates to:
  /// **'Please log in again and try deleting the account.'**
  String get requiresRecentLogin;

  /// No description provided for @resetPassword.
  ///
  /// In en, this message translates to:
  /// **'Reset Passwoprd'**
  String get resetPassword;

  /// No description provided for @resetPreset.
  ///
  /// In en, this message translates to:
  /// **'Reset Preset'**
  String get resetPreset;

  /// No description provided for @saveAndContinue.
  ///
  /// In en, this message translates to:
  /// **'Save and Continue'**
  String get saveAndContinue;

  /// No description provided for @security.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get security;

  /// No description provided for @selectYourPreset.
  ///
  /// In en, this message translates to:
  /// **'Select Your Preset'**
  String get selectYourPreset;

  /// No description provided for @sendResetLink.
  ///
  /// In en, this message translates to:
  /// **'Send Reset Link'**
  String get sendResetLink;

  /// No description provided for @server.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get server;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// No description provided for @signUpNewAccount.
  ///
  /// In en, this message translates to:
  /// **'Sign up new Account'**
  String get signUpNewAccount;

  /// No description provided for @targetLanguage.
  ///
  /// In en, this message translates to:
  /// **'Target Language'**
  String get targetLanguage;

  /// No description provided for @termsAndConditions.
  ///
  /// In en, this message translates to:
  /// **'Terms & Conditions'**
  String get termsAndConditions;

  /// No description provided for @yourFoodMenu.
  ///
  /// In en, this message translates to:
  /// **'Your Food Menu'**
  String get yourFoodMenu;

  /// No description provided for @passwordResetError.
  ///
  /// In en, this message translates to:
  /// **'An error occurred while sending the password reset email.'**
  String get passwordResetError;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @aiAnswer.
  ///
  /// In en, this message translates to:
  /// **'AI Answer'**
  String get aiAnswer;

  /// No description provided for @liked.
  ///
  /// In en, this message translates to:
  /// **'Liked'**
  String get liked;

  /// No description provided for @unliked.
  ///
  /// In en, this message translates to:
  /// **'Unliked'**
  String get unliked;

  /// No description provided for @textCopied.
  ///
  /// In en, this message translates to:
  /// **'Text copied to clipboard'**
  String get textCopied;

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get title;

  /// No description provided for @noFavoriteData.
  ///
  /// In en, this message translates to:
  /// **'No Favorite Data'**
  String get noFavoriteData;

  /// No description provided for @enterRestaurantName.
  ///
  /// In en, this message translates to:
  /// **'Enter restaurant name'**
  String get enterRestaurantName;

  /// No description provided for @pleaseEnterRestaurantAndRating.
  ///
  /// In en, this message translates to:
  /// **'Please enter a restaurant name and rating'**
  String get pleaseEnterRestaurantAndRating;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @favorite.
  ///
  /// In en, this message translates to:
  /// **'Favorite'**
  String get favorite;

  /// No description provided for @noHistoryFound.
  ///
  /// In en, this message translates to:
  /// **'No History Found'**
  String get noHistoryFound;

  /// No description provided for @historyFreeLimitNotice.
  ///
  /// In en, this message translates to:
  /// **'Free and guest accounts keep the 20 most recent history entries.'**
  String get historyFreeLimitNotice;

  /// No description provided for @historyUnlimitedNotice.
  ///
  /// In en, this message translates to:
  /// **'Premium accounts can keep unlimited history.'**
  String get historyUnlimitedNotice;

  /// No description provided for @aiScanning.
  ///
  /// In en, this message translates to:
  /// **'AI Scanning...'**
  String get aiScanning;

  /// No description provided for @aiLoadingMessage.
  ///
  /// In en, this message translates to:
  /// **'AI can make mistakes. The loading time typically takes around 5-10 seconds, but it may vary depending on your internet connection and smartphone device.'**
  String get aiLoadingMessage;

  /// No description provided for @introductionTitle1.
  ///
  /// In en, this message translates to:
  /// **'Mscanner'**
  String get introductionTitle1;

  /// No description provided for @introductionSubtitle1.
  ///
  /// In en, this message translates to:
  /// **'by THJ'**
  String get introductionSubtitle1;

  /// No description provided for @introductionBody1.
  ///
  /// In en, this message translates to:
  /// **'Feel comfortable choosing food at restaurants worldwide'**
  String get introductionBody1;

  /// No description provided for @introductionTitle2.
  ///
  /// In en, this message translates to:
  /// **'How would you like to scan the menu?'**
  String get introductionTitle2;

  /// No description provided for @introductionBody2_1.
  ///
  /// In en, this message translates to:
  /// **'1. Select your language (English or native)'**
  String get introductionBody2_1;

  /// No description provided for @introductionBody2_2.
  ///
  /// In en, this message translates to:
  /// **'2. Choose your food style (dietary, beef lover, etc.)'**
  String get introductionBody2_2;

  /// No description provided for @introductionBody2_3.
  ///
  /// In en, this message translates to:
  /// **'3. Set the number of menus you want to scan. (more menus, less detail)'**
  String get introductionBody2_3;

  /// No description provided for @introductionTitle3.
  ///
  /// In en, this message translates to:
  /// **'Optimize Your settings'**
  String get introductionTitle3;

  /// No description provided for @introductionBody3_1.
  ///
  /// In en, this message translates to:
  /// **'1. Activate dark mode'**
  String get introductionBody3_1;

  /// No description provided for @introductionBody3_2.
  ///
  /// In en, this message translates to:
  /// **'2. Change your account password'**
  String get introductionBody3_2;

  /// No description provided for @introductionBody3_3.
  ///
  /// In en, this message translates to:
  /// **'3. Reset your menu scan settings'**
  String get introductionBody3_3;

  /// No description provided for @introductionBody3_4.
  ///
  /// In en, this message translates to:
  /// **'4. Save your data online to enable more features'**
  String get introductionBody3_4;

  /// No description provided for @introductionTitle4.
  ///
  /// In en, this message translates to:
  /// **'Share your Result'**
  String get introductionTitle4;

  /// No description provided for @introductionBody4_1.
  ///
  /// In en, this message translates to:
  /// **'1. Leave a note on each result'**
  String get introductionBody4_1;

  /// No description provided for @introductionBody4_2.
  ///
  /// In en, this message translates to:
  /// **'2. Save the results on your smartphone'**
  String get introductionBody4_2;

  /// No description provided for @introductionBody4_3.
  ///
  /// In en, this message translates to:
  /// **'3. Favorite button and copy result'**
  String get introductionBody4_3;

  /// No description provided for @introductionTitle5.
  ///
  /// In en, this message translates to:
  /// **'Save your experiences'**
  String get introductionTitle5;

  /// No description provided for @introductionBody5_1.
  ///
  /// In en, this message translates to:
  /// **'1. Active points(shows your activity in Mscanner)'**
  String get introductionBody5_1;

  /// No description provided for @introductionBody5_2.
  ///
  /// In en, this message translates to:
  /// **'2. Enter the name of the restaurant you visited'**
  String get introductionBody5_2;

  /// No description provided for @introductionBody5_3.
  ///
  /// In en, this message translates to:
  /// **'3. Rate Restaurant'**
  String get introductionBody5_3;

  /// No description provided for @introductionBody5_4.
  ///
  /// In en, this message translates to:
  /// **'4. View the places you visited on a map'**
  String get introductionBody5_4;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @checkOutRestaurant.
  ///
  /// In en, this message translates to:
  /// **'Check out this restaurant!'**
  String get checkOutRestaurant;

  /// No description provided for @loadingError.
  ///
  /// In en, this message translates to:
  /// **'loading Error'**
  String get loadingError;

  /// No description provided for @confirmMessageTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm message'**
  String get confirmMessageTitle;

  /// No description provided for @confirmMessageContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete?'**
  String get confirmMessageContent;

  /// No description provided for @shareLocation.
  ///
  /// In en, this message translates to:
  /// **'Share location'**
  String get shareLocation;

  /// No description provided for @checkOutContent.
  ///
  /// In en, this message translates to:
  /// **'Check out this content!'**
  String get checkOutContent;

  /// No description provided for @shareVia.
  ///
  /// In en, this message translates to:
  /// **'Share via'**
  String get shareVia;

  /// No description provided for @cloudsavingError.
  ///
  /// In en, this message translates to:
  /// **'Cloud Saving Error'**
  String get cloudsavingError;

  /// No description provided for @languagesdescprition.
  ///
  /// In en, this message translates to:
  /// **'Take a photo of a food item or menu and select the language for the output'**
  String get languagesdescprition;

  /// No description provided for @fooddescprition.
  ///
  /// In en, this message translates to:
  /// **'Please select a diet or meal plan. The AI will provide recommendations and explanations based on your selection'**
  String get fooddescprition;

  /// No description provided for @menudescribe.
  ///
  /// In en, this message translates to:
  /// **'Please select the number of food menu items to display. The fewer items you select, the more detailed the descriptions will be'**
  String get menudescribe;

  /// No description provided for @darkdescp.
  ///
  /// In en, this message translates to:
  /// **'Enable dark mode for a more comfortable viewing experience'**
  String get darkdescp;

  /// No description provided for @changepassdescp.
  ///
  /// In en, this message translates to:
  /// **'For security, regularly change your password and use a strong password that is easy to remember'**
  String get changepassdescp;

  /// No description provided for @aIresetdescp.
  ///
  /// In en, this message translates to:
  /// **'You can reset the AI scan settings'**
  String get aIresetdescp;

  /// No description provided for @savedescp.
  ///
  /// In en, this message translates to:
  /// **'Save the output data to the server. Saving is required to enable additional features'**
  String get savedescp;

  /// No description provided for @scanFoodPhotoDescription.
  ///
  /// In en, this message translates to:
  /// **'Take a photo of a food item or menu and find out what it is! Check it out now'**
  String get scanFoodPhotoDescription;

  /// No description provided for @activepoint.
  ///
  /// In en, this message translates to:
  /// **'The points display the user activity index, and various rewards will be provided in the future.'**
  String get activepoint;

  /// No description provided for @todayrecommand.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Recommendation'**
  String get todayrecommand;

  /// No description provided for @cityrecommand.
  ///
  /// In en, this message translates to:
  /// **'Recommendations by Region'**
  String get cityrecommand;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @bookmark.
  ///
  /// In en, this message translates to:
  /// **'Bookmark'**
  String get bookmark;

  /// No description provided for @map.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get map;

  /// No description provided for @locationPermissionNeeded.
  ///
  /// In en, this message translates to:
  /// **'Location Permission Required'**
  String get locationPermissionNeeded;

  /// No description provided for @locationPermissionContent.
  ///
  /// In en, this message translates to:
  /// **'This app requires location permissions to function properly. Please allow location access in the app settings.'**
  String get locationPermissionContent;

  /// No description provided for @locationServiceDisabled.
  ///
  /// In en, this message translates to:
  /// **'Location Services Disabled'**
  String get locationServiceDisabled;

  /// No description provided for @locationServiceDisabledContent.
  ///
  /// In en, this message translates to:
  /// **'Location services are disabled. Please enable location services in the settings.'**
  String get locationServiceDisabledContent;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get openSettings;

  /// No description provided for @languagesdescprition1.
  ///
  /// In en, this message translates to:
  /// **'Unlock a world of culinary delights with one scan.'**
  String get languagesdescprition1;

  /// No description provided for @continueAsGuest.
  ///
  /// In en, this message translates to:
  /// **'Continue as Guest'**
  String get continueAsGuest;

  /// No description provided for @guestLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'Guest login'**
  String get guestLoginTitle;

  /// No description provided for @guestLoginContent.
  ///
  /// In en, this message translates to:
  /// **'You are logged in as a guest. All data will be deleted upon logout.'**
  String get guestLoginContent;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @guestLoginFailed.
  ///
  /// In en, this message translates to:
  /// **'Guest login failed. Please try again.'**
  String get guestLoginFailed;

  /// No description provided for @logoutConfirmationTitle.
  ///
  /// In en, this message translates to:
  /// **'Logout Confirmation'**
  String get logoutConfirmationTitle;

  /// No description provided for @logoutConfirmationContent.
  ///
  /// In en, this message translates to:
  /// **'Logging out as a guest will delete all your data. Do you want to proceed?'**
  String get logoutConfirmationContent;

  /// No description provided for @convertAccount.
  ///
  /// In en, this message translates to:
  /// **'Convert Account'**
  String get convertAccount;

  /// No description provided for @accountConversionDescription.
  ///
  /// In en, this message translates to:
  /// **'Convert your guest account to a permanent account to save your data.'**
  String get accountConversionDescription;

  /// No description provided for @accountConversionSuccess.
  ///
  /// In en, this message translates to:
  /// **'Account successfully converted.'**
  String get accountConversionSuccess;

  /// No description provided for @accountConversionFailed.
  ///
  /// In en, this message translates to:
  /// **'Account conversion failed'**
  String get accountConversionFailed;

  /// No description provided for @browse.
  ///
  /// In en, this message translates to:
  /// **'Explore as a Guest'**
  String get browse;

  /// No description provided for @changepreset.
  ///
  /// In en, this message translates to:
  /// **'Change preset'**
  String get changepreset;

  /// No description provided for @viewbylatest.
  ///
  /// In en, this message translates to:
  /// **'View by latest'**
  String get viewbylatest;

  /// No description provided for @viewbycountry.
  ///
  /// In en, this message translates to:
  /// **'View by country'**
  String get viewbycountry;

  /// No description provided for @cameraHint.
  ///
  /// In en, this message translates to:
  /// **'Tap the camera to scan the food menu.'**
  String get cameraHint;

  /// No description provided for @manualTitle.
  ///
  /// In en, this message translates to:
  /// **'Manual page'**
  String get manualTitle;

  /// No description provided for @manualSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Read our documentation'**
  String get manualSubtitle;

  /// No description provided for @loadingScanning.
  ///
  /// In en, this message translates to:
  /// **'Scanning the image...'**
  String get loadingScanning;

  /// No description provided for @loadingAnalyzing.
  ///
  /// In en, this message translates to:
  /// **'Analyzing the menu with AI...'**
  String get loadingAnalyzing;

  /// No description provided for @loadingAlmostDone.
  ///
  /// In en, this message translates to:
  /// **'Almost done preparing your result...'**
  String get loadingAlmostDone;

  /// No description provided for @loadingFinalizing.
  ///
  /// In en, this message translates to:
  /// **'Finalizing the details...'**
  String get loadingFinalizing;

  /// No description provided for @loadingWaiting.
  ///
  /// In en, this message translates to:
  /// **'Just a bit more... Thank you for your patience!'**
  String get loadingWaiting;

  /// No description provided for @emergencyTitle.
  ///
  /// In en, this message translates to:
  /// **'Emergency Notice'**
  String get emergencyTitle;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @dismissToday.
  ///
  /// In en, this message translates to:
  /// **'Don\'t show again today'**
  String get dismissToday;

  /// No description provided for @gptErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Sorry.\\nA AI Server communication error occurred.\\n Please try again later.'**
  String get gptErrorMessage;

  /// No description provided for @restaurantName.
  ///
  /// In en, this message translates to:
  /// **'Restaurant name'**
  String get restaurantName;

  /// No description provided for @tutorialMode.
  ///
  /// In en, this message translates to:
  /// **'Tutorial Mode'**
  String get tutorialMode;

  /// No description provided for @reviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Comment'**
  String get reviewTitle;

  /// No description provided for @reviewHint.
  ///
  /// In en, this message translates to:
  /// **'Please enter a brief review of the restaurant.'**
  String get reviewHint;

  /// No description provided for @commentSection_title.
  ///
  /// In en, this message translates to:
  /// **'🗨 Nearby User Reviews'**
  String get commentSection_title;

  /// No description provided for @commentSection_seeMore.
  ///
  /// In en, this message translates to:
  /// **'Show more reviews ▼'**
  String get commentSection_seeMore;

  /// No description provided for @commentSection_seeLess.
  ///
  /// In en, this message translates to:
  /// **'Hide reviews ▲'**
  String get commentSection_seeLess;

  /// No description provided for @commentSection_anonymous.
  ///
  /// In en, this message translates to:
  /// **'Anonymous'**
  String get commentSection_anonymous;

  /// No description provided for @commentSection_noContent.
  ///
  /// In en, this message translates to:
  /// **'There is no content to translate.'**
  String get commentSection_noContent;

  /// No description provided for @timeAgo_minutes.
  ///
  /// In en, this message translates to:
  /// **' minutes ago'**
  String get timeAgo_minutes;

  /// No description provided for @timeAgo_hours.
  ///
  /// In en, this message translates to:
  /// **' hours ago'**
  String get timeAgo_hours;

  /// No description provided for @timeAgo_days.
  ///
  /// In en, this message translates to:
  /// **' days ago'**
  String get timeAgo_days;

  /// No description provided for @timeAgo_months.
  ///
  /// In en, this message translates to:
  /// **' months ago'**
  String get timeAgo_months;

  /// No description provided for @timeAgo_years.
  ///
  /// In en, this message translates to:
  /// **' years ago'**
  String get timeAgo_years;

  /// No description provided for @commentSection_translate.
  ///
  /// In en, this message translates to:
  /// **'Translate'**
  String get commentSection_translate;

  /// No description provided for @commentSection_original.
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get commentSection_original;

  /// No description provided for @iapUnavailable.
  ///
  /// In en, this message translates to:
  /// **'In-app purchases unavailable'**
  String get iapUnavailable;

  /// No description provided for @noAvailableProducts.
  ///
  /// In en, this message translates to:
  /// **'No products available'**
  String get noAvailableProducts;

  /// No description provided for @premiumUserTitle.
  ///
  /// In en, this message translates to:
  /// **'Premium user'**
  String get premiumUserTitle;

  /// No description provided for @premiumUserSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Ads removed'**
  String get premiumUserSubtitle;

  /// No description provided for @buy.
  ///
  /// In en, this message translates to:
  /// **'Buy'**
  String get buy;

  /// No description provided for @guestPurchaseMessage.
  ///
  /// In en, this message translates to:
  /// **'Guest users can\'t purchase'**
  String get guestPurchaseMessage;

  /// No description provided for @premiumFunctionMessage.
  ///
  /// In en, this message translates to:
  /// **'Premium service only'**
  String get premiumFunctionMessage;

  /// No description provided for @multiScan.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get multiScan;

  /// Snackbar message shown when user selects more images than the max allowed
  ///
  /// In en, this message translates to:
  /// **'Only the first {maxCount} images will be scanned.'**
  String maxScanImages(int maxCount);

  /// No description provided for @restorePurchases.
  ///
  /// In en, this message translates to:
  /// **'Restore Purchases'**
  String get restorePurchases;

  /// SnackBar message shown while image merge is in progress
  ///
  /// In en, this message translates to:
  /// **'Merging images…\nPlease wait.'**
  String get mergeInProgress;

  /// No description provided for @fx_title.
  ///
  /// In en, this message translates to:
  /// **'Currency Converter'**
  String get fx_title;

  /// No description provided for @fx_tooltip.
  ///
  /// In en, this message translates to:
  /// **'Convert currency'**
  String get fx_tooltip;

  /// No description provided for @fx_currency_btn.
  ///
  /// In en, this message translates to:
  /// **'Currency: {code}'**
  String fx_currency_btn(Object code);

  /// No description provided for @fx_base_date.
  ///
  /// In en, this message translates to:
  /// **'Base date: {date}'**
  String fx_base_date(Object date);

  /// No description provided for @fx_unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get fx_unknown;

  /// No description provided for @fx_amount_label.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get fx_amount_label;

  /// No description provided for @fx_amount_hint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 100'**
  String get fx_amount_hint;

  /// No description provided for @fx_enter_amount_to_convert.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount to convert to {target}.'**
  String fx_enter_amount_to_convert(Object target);

  /// No description provided for @fx_error_no_rate.
  ///
  /// In en, this message translates to:
  /// **'No exchange rate data available.'**
  String get fx_error_no_rate;

  /// No description provided for @fx_search_currency_hint.
  ///
  /// In en, this message translates to:
  /// **'Search currency code (e.g., USD, JPY)'**
  String get fx_search_currency_hint;

  /// No description provided for @sub_disclaimer_title.
  ///
  /// In en, this message translates to:
  /// **'Subscription Information'**
  String get sub_disclaimer_title;

  /// No description provided for @sub_trial_free.
  ///
  /// In en, this message translates to:
  /// **'First-time subscribers are not charged during the trial period.'**
  String get sub_trial_free;

  /// No description provided for @sub_auto_renew.
  ///
  /// In en, this message translates to:
  /// **'After the trial ends, the subscription automatically renews unless canceled at least 24 hours before the end of the current period.'**
  String get sub_auto_renew;

  /// No description provided for @sub_renew_charge.
  ///
  /// In en, this message translates to:
  /// **'Renewal charges may occur within 24 hours before the end of the current period.'**
  String get sub_renew_charge;

  /// No description provided for @sub_period_price.
  ///
  /// In en, this message translates to:
  /// **'This subscription is {period} (Price: {price}).'**
  String sub_period_price(Object period, Object price);

  /// No description provided for @sub_restore.
  ///
  /// In en, this message translates to:
  /// **'Previously purchased items can be restored using \"Restore Purchases\".'**
  String get sub_restore;

  /// No description provided for @terms.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get terms;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacy;

  /// No description provided for @sub_manage_ios.
  ///
  /// In en, this message translates to:
  /// **'Payments are charged to your Apple ID and subscriptions can be managed or canceled in Settings > [your name] > Subscriptions.'**
  String get sub_manage_ios;

  /// No description provided for @sub_manage_android.
  ///
  /// In en, this message translates to:
  /// **'Payments are charged to your Google account and subscriptions can be managed or canceled in the Play Store app > Profile icon > Payments & subscriptions > Subscriptions.'**
  String get sub_manage_android;

  /// No description provided for @sub_badge_trial_1m.
  ///
  /// In en, this message translates to:
  /// **'🎁 1‑month free for first‑time subscribers'**
  String get sub_badge_trial_1m;

  /// No description provided for @iapRestoreError.
  ///
  /// In en, this message translates to:
  /// **'An error occurred during restoration.'**
  String get iapRestoreError;

  /// No description provided for @iapRestoreDone.
  ///
  /// In en, this message translates to:
  /// **'Purchases have been restored.'**
  String get iapRestoreDone;

  /// No description provided for @iapRestoreEmpty.
  ///
  /// In en, this message translates to:
  /// **'No purchases to restore.'**
  String get iapRestoreEmpty;

  /// No description provided for @iapRestoreTrying.
  ///
  /// In en, this message translates to:
  /// **'Trying to restore purchases...'**
  String get iapRestoreTrying;

  /// No description provided for @viewOnMap.
  ///
  /// In en, this message translates to:
  /// **'View on map'**
  String get viewOnMap;

  /// No description provided for @login_welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get login_welcomeBack;

  /// No description provided for @login_subtitle.
  ///
  /// In en, this message translates to:
  /// **'A smarter, easier way to explore food with AI—let’s get started.'**
  String get login_subtitle;

  /// No description provided for @login_emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get login_emailLabel;

  /// No description provided for @login_emailHint.
  ///
  /// In en, this message translates to:
  /// **'name@example.com'**
  String get login_emailHint;

  /// No description provided for @login_orContinueWith.
  ///
  /// In en, this message translates to:
  /// **'OR CONTINUE WITH'**
  String get login_orContinueWith;

  /// No description provided for @login_google.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get login_google;

  /// No description provided for @login_apple.
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get login_apple;

  /// No description provided for @login_noAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get login_noAccount;

  /// No description provided for @login_signUpFree.
  ///
  /// In en, this message translates to:
  /// **'Sign up for free'**
  String get login_signUpFree;

  /// No description provided for @signup_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Create an account to save scans, manage presets, and unlock premium features.'**
  String get signup_subtitle;

  /// No description provided for @signup_emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get signup_emailLabel;

  /// No description provided for @signup_emailHint.
  ///
  /// In en, this message translates to:
  /// **'name@example.com'**
  String get signup_emailHint;

  /// No description provided for @signup_logIn.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get signup_logIn;

  /// No description provided for @map_noTitle.
  ///
  /// In en, this message translates to:
  /// **'No Title'**
  String get map_noTitle;

  /// No description provided for @map_cuisine.
  ///
  /// In en, this message translates to:
  /// **'Cuisine'**
  String get map_cuisine;

  /// No description provided for @map_location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get map_location;

  /// No description provided for @map_searchHistory.
  ///
  /// In en, this message translates to:
  /// **'Search History'**
  String get map_searchHistory;

  /// No description provided for @map_recent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get map_recent;

  /// No description provided for @map_topRated.
  ///
  /// In en, this message translates to:
  /// **'Top Rated'**
  String get map_topRated;

  /// No description provided for @map_date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get map_date;

  /// No description provided for @map_clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get map_clear;

  /// No description provided for @map_noResults.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get map_noResults;

  /// No description provided for @map_unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get map_unknown;

  /// No description provided for @howto_title.
  ///
  /// In en, this message translates to:
  /// **'How to use Mscanner'**
  String get howto_title;

  /// No description provided for @howto_step1.
  ///
  /// In en, this message translates to:
  /// **'1. SCAN'**
  String get howto_step1;

  /// No description provided for @howto_desc1.
  ///
  /// In en, this message translates to:
  /// **'Menu or Dish'**
  String get howto_desc1;

  /// No description provided for @howto_step2.
  ///
  /// In en, this message translates to:
  /// **'2. ANALYZE'**
  String get howto_step2;

  /// No description provided for @howto_desc2.
  ///
  /// In en, this message translates to:
  /// **'AI analyzes\nyour photo'**
  String get howto_desc2;

  /// No description provided for @howto_step3.
  ///
  /// In en, this message translates to:
  /// **'3. ENJOY'**
  String get howto_step3;

  /// No description provided for @howto_desc3.
  ///
  /// In en, this message translates to:
  /// **'Get recommendations\nthat fit you'**
  String get howto_desc3;

  /// No description provided for @home_searchAiFoodImage.
  ///
  /// In en, this message translates to:
  /// **'Search AI food image...'**
  String get home_searchAiFoodImage;

  /// No description provided for @home_adLabel.
  ///
  /// In en, this message translates to:
  /// **'AD'**
  String get home_adLabel;

  /// No description provided for @home_trendingNearYou.
  ///
  /// In en, this message translates to:
  /// **'Trending Near You'**
  String get home_trendingNearYou;

  /// No description provided for @home_mscannerPicks.
  ///
  /// In en, this message translates to:
  /// **'Mscanner Picks'**
  String get home_mscannerPicks;

  /// No description provided for @home_viewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get home_viewAll;

  /// No description provided for @home_errorLoadingCards.
  ///
  /// In en, this message translates to:
  /// **'Error loading cards'**
  String get home_errorLoadingCards;

  /// No description provided for @home_noDataAvailable.
  ///
  /// In en, this message translates to:
  /// **'No data available'**
  String get home_noDataAvailable;

  /// No description provided for @home_errorSavingData.
  ///
  /// In en, this message translates to:
  /// **'Error saving data'**
  String get home_errorSavingData;

  /// No description provided for @favoriteList_searchHistory.
  ///
  /// In en, this message translates to:
  /// **'Search History'**
  String get favoriteList_searchHistory;

  /// No description provided for @favoriteList_all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get favoriteList_all;

  /// No description provided for @favoriteList_recent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get favoriteList_recent;

  /// No description provided for @favoriteList_topRated.
  ///
  /// In en, this message translates to:
  /// **'Top Rated'**
  String get favoriteList_topRated;

  /// No description provided for @favoriteList_date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get favoriteList_date;

  /// No description provided for @favoriteList_country.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get favoriteList_country;

  /// No description provided for @favoriteList_noDate.
  ///
  /// In en, this message translates to:
  /// **'No date'**
  String get favoriteList_noDate;

  /// No description provided for @favoriteList_noHistoryFound.
  ///
  /// In en, this message translates to:
  /// **'No history found'**
  String get favoriteList_noHistoryFound;

  /// No description provided for @favoriteList_thisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get favoriteList_thisWeek;

  /// No description provided for @favoriteList_entries.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String favoriteList_entries(Object count);

  /// No description provided for @favorite_fullMenu.
  ///
  /// In en, this message translates to:
  /// **'Full Menu'**
  String get favorite_fullMenu;

  /// No description provided for @favorite_menuMain.
  ///
  /// In en, this message translates to:
  /// **'Main'**
  String get favorite_menuMain;

  /// No description provided for @favorite_menuSide.
  ///
  /// In en, this message translates to:
  /// **'Sides'**
  String get favorite_menuSide;

  /// No description provided for @favorite_menuMeal.
  ///
  /// In en, this message translates to:
  /// **'Meals'**
  String get favorite_menuMeal;

  /// No description provided for @favorite_menuDrink.
  ///
  /// In en, this message translates to:
  /// **'Drinks'**
  String get favorite_menuDrink;

  /// No description provided for @favorite_menuBeverage.
  ///
  /// In en, this message translates to:
  /// **'Beverages'**
  String get favorite_menuBeverage;

  /// No description provided for @favorite_menuOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get favorite_menuOther;

  /// No description provided for @favorite_summaryTruncated.
  ///
  /// In en, this message translates to:
  /// **'Summary (short)'**
  String get favorite_summaryTruncated;

  /// No description provided for @favorite_summary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get favorite_summary;

  /// No description provided for @favorite_noResponses.
  ///
  /// In en, this message translates to:
  /// **'No responses available'**
  String get favorite_noResponses;

  /// No description provided for @favorite_viewFullMenu.
  ///
  /// In en, this message translates to:
  /// **'View Full Menu'**
  String get favorite_viewFullMenu;

  /// No description provided for @favorite_unknownRestaurant.
  ///
  /// In en, this message translates to:
  /// **'Unknown Restaurant'**
  String get favorite_unknownRestaurant;

  /// No description provided for @favorite_failedSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save changes'**
  String get favorite_failedSaveChanges;

  /// No description provided for @favorite_renderNotReady.
  ///
  /// In en, this message translates to:
  /// **'Error: Screen is not ready.'**
  String get favorite_renderNotReady;

  /// No description provided for @favorite_restaurantNameHint.
  ///
  /// In en, this message translates to:
  /// **'Restaurant name'**
  String get favorite_restaurantNameHint;

  /// No description provided for @result_fxRateLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load exchange rates. Please check your connection.'**
  String get result_fxRateLoadFailed;

  /// No description provided for @result_fxConvertFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t convert this amount.'**
  String get result_fxConvertFailed;

  /// No description provided for @result_restoreOriginalCurrency.
  ///
  /// In en, this message translates to:
  /// **'Restore original currency'**
  String get result_restoreOriginalCurrency;

  /// No description provided for @result_convertToSystemCurrency.
  ///
  /// In en, this message translates to:
  /// **'Convert to system currency ({currency})'**
  String result_convertToSystemCurrency(Object currency);

  /// No description provided for @result_auto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get result_auto;

  /// No description provided for @result_viewFullMenu.
  ///
  /// In en, this message translates to:
  /// **'View Full Menu'**
  String get result_viewFullMenu;

  /// No description provided for @result_preparingMenu.
  ///
  /// In en, this message translates to:
  /// **'Preparing detailed menu…'**
  String get result_preparingMenu;

  /// No description provided for @result_failedLoadSettings.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load settings. Cloud save is enabled by default.'**
  String get result_failedLoadSettings;

  /// No description provided for @result_imageUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Image upload failed. Please try again.'**
  String get result_imageUploadFailed;

  /// No description provided for @result_analyzing.
  ///
  /// In en, this message translates to:
  /// **'Analyzing food details'**
  String get result_analyzing;

  /// No description provided for @result_loadingFullMenu.
  ///
  /// In en, this message translates to:
  /// **'Loading full menu…'**
  String get result_loadingFullMenu;

  /// No description provided for @howto_detail_link.
  ///
  /// In en, this message translates to:
  /// **'See more details'**
  String get howto_detail_link;

  /// No description provided for @guestLoginTitle2.
  ///
  /// In en, this message translates to:
  /// **'Welcome, Explorer!'**
  String get guestLoginTitle2;

  /// No description provided for @guestLoginContent2.
  ///
  /// In en, this message translates to:
  /// **'In Guest Mode, you can scan food menus to get personalized recommendations, but you won’t be able to save your favorites or view history across devices.'**
  String get guestLoginContent2;

  /// No description provided for @confirm2.
  ///
  /// In en, this message translates to:
  /// **'Continue as Guest'**
  String get confirm2;

  /// No description provided for @login2.
  ///
  /// In en, this message translates to:
  /// **'Member Login'**
  String get login2;

  /// No description provided for @result_orderButton.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get result_orderButton;

  /// No description provided for @result_fullMenuUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Full menu is not available yet.'**
  String get result_fullMenuUnavailable;

  /// No description provided for @result_noMenuItemsFound.
  ///
  /// In en, this message translates to:
  /// **'No menu items found.'**
  String get result_noMenuItemsFound;

  /// No description provided for @result_notMenuMessage.
  ///
  /// In en, this message translates to:
  /// **'This image does not appear to be a food menu. Please retake the photo so menu names or food names are clearly visible.'**
  String get result_notMenuMessage;

  /// No description provided for @result_uncertainMenuMessage.
  ///
  /// In en, this message translates to:
  /// **'Not sure this is a food menu. Please retake the photo so menu names and prices are clearly visible.'**
  String get result_uncertainMenuMessage;

  /// No description provided for @result_aiTimeoutMoreResponse.
  ///
  /// In en, this message translates to:
  /// **'Timed out while waiting for more AI response.'**
  String get result_aiTimeoutMoreResponse;

  /// No description provided for @result_aiTimeoutFirstChunk.
  ///
  /// In en, this message translates to:
  /// **'Timed out before first AI chunk arrived.'**
  String get result_aiTimeoutFirstChunk;

  /// No description provided for @result_aiTimeoutFullMenu.
  ///
  /// In en, this message translates to:
  /// **'Timed out while waiting for full menu.'**
  String get result_aiTimeoutFullMenu;

  /// No description provided for @result_aiTimeoutFullMenuStream.
  ///
  /// In en, this message translates to:
  /// **'Timed out while waiting for full menu stream.'**
  String get result_aiTimeoutFullMenuStream;

  /// No description provided for @result_aiReceiveFailedFullMenuStream.
  ///
  /// In en, this message translates to:
  /// **'Failed while receiving full menu stream.'**
  String get result_aiReceiveFailedFullMenuStream;

  /// No description provided for @result_aiEmptyStreamResponse.
  ///
  /// In en, this message translates to:
  /// **'AI returned an empty stream response.'**
  String get result_aiEmptyStreamResponse;

  /// No description provided for @tts_orderPhraseTitle.
  ///
  /// In en, this message translates to:
  /// **'Create ordering phrase'**
  String get tts_orderPhraseTitle;

  /// No description provided for @tts_scenarioSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose situation'**
  String get tts_scenarioSectionTitle;

  /// No description provided for @tts_modifierSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose options'**
  String get tts_modifierSectionTitle;

  /// No description provided for @tts_allergySectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose allergies'**
  String get tts_allergySectionTitle;

  /// No description provided for @tts_generatePhraseButton.
  ///
  /// In en, this message translates to:
  /// **'Generate phrase'**
  String get tts_generatePhraseButton;

  /// No description provided for @tts_generationFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to generate phrase. Please try again in a moment.'**
  String get tts_generationFailed;

  /// No description provided for @tts_resultSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Generated phrase'**
  String get tts_resultSectionTitle;

  /// No description provided for @tts_stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get tts_stop;

  /// No description provided for @tts_listen.
  ///
  /// In en, this message translates to:
  /// **'Listen'**
  String get tts_listen;

  /// No description provided for @tts_regenerate.
  ///
  /// In en, this message translates to:
  /// **'Regenerate'**
  String get tts_regenerate;

  /// No description provided for @tts_scenarioBasicOrder.
  ///
  /// In en, this message translates to:
  /// **'Basic order'**
  String get tts_scenarioBasicOrder;

  /// No description provided for @tts_scenarioCustomizeOrder.
  ///
  /// In en, this message translates to:
  /// **'Request options'**
  String get tts_scenarioCustomizeOrder;

  /// No description provided for @tts_scenarioAllergyCheck.
  ///
  /// In en, this message translates to:
  /// **'Check allergies'**
  String get tts_scenarioAllergyCheck;

  /// No description provided for @tts_scenarioRecommendationAsk.
  ///
  /// In en, this message translates to:
  /// **'Ask for recommendation'**
  String get tts_scenarioRecommendationAsk;

  /// No description provided for @tts_modifierNoCilantro.
  ///
  /// In en, this message translates to:
  /// **'No cilantro'**
  String get tts_modifierNoCilantro;

  /// No description provided for @tts_modifierNoOnion.
  ///
  /// In en, this message translates to:
  /// **'No onion'**
  String get tts_modifierNoOnion;

  /// No description provided for @tts_modifierLessSpicy.
  ///
  /// In en, this message translates to:
  /// **'Less spicy'**
  String get tts_modifierLessSpicy;

  /// No description provided for @tts_modifierLessSalty.
  ///
  /// In en, this message translates to:
  /// **'Less salty'**
  String get tts_modifierLessSalty;

  /// No description provided for @tts_allergyPeanut.
  ///
  /// In en, this message translates to:
  /// **'Peanut'**
  String get tts_allergyPeanut;

  /// No description provided for @tts_allergyMilk.
  ///
  /// In en, this message translates to:
  /// **'Milk'**
  String get tts_allergyMilk;

  /// No description provided for @tts_allergyShrimp.
  ///
  /// In en, this message translates to:
  /// **'Shrimp'**
  String get tts_allergyShrimp;

  /// No description provided for @tts_allergyEgg.
  ///
  /// In en, this message translates to:
  /// **'Egg'**
  String get tts_allergyEgg;

  /// No description provided for @premiumLoginRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to start Premium'**
  String get premiumLoginRequiredTitle;

  /// No description provided for @premiumLoginRequiredMessage.
  ///
  /// In en, this message translates to:
  /// **'Sign in to restore purchases, keep your subscription, and access Premium across devices.'**
  String get premiumLoginRequiredMessage;

  /// No description provided for @premiumLoginRequiredAction.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue'**
  String get premiumLoginRequiredAction;

  /// No description provided for @premiumGuestCta.
  ///
  /// In en, this message translates to:
  /// **'Sign in for Premium'**
  String get premiumGuestCta;

  /// No description provided for @premiumStartCta.
  ///
  /// In en, this message translates to:
  /// **'Start Premium'**
  String get premiumStartCta;

  /// No description provided for @premiumGuestSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect your account before purchasing Premium in guest mode'**
  String get premiumGuestSectionTitle;

  /// No description provided for @premiumGuestSectionMessage.
  ///
  /// In en, this message translates to:
  /// **'Premium subscriptions are linked to your account so purchases can be restored and used across devices.'**
  String get premiumGuestSectionMessage;

  /// No description provided for @premiumGuestConvertButton.
  ///
  /// In en, this message translates to:
  /// **'Convert account to continue'**
  String get premiumGuestConvertButton;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
        'ar',
        'bn',
        'de',
        'en',
        'es',
        'fr',
        'hi',
        'id',
        'ja',
        'ko',
        'mr',
        'pt',
        'ru',
        'te',
        'th',
        'tr',
        'ur',
        'vi',
        'zh'
      ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.scriptCode) {
          case 'Hans':
            return AppLocalizationsZhHans();
          case 'Hant':
            return AppLocalizationsZhHant();
        }
        break;
      }
  }

  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'pt':
      {
        switch (locale.countryCode) {
          case 'BR':
            return AppLocalizationsPtBr();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'bn':
      return AppLocalizationsBn();
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'hi':
      return AppLocalizationsHi();
    case 'id':
      return AppLocalizationsId();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'mr':
      return AppLocalizationsMr();
    case 'pt':
      return AppLocalizationsPt();
    case 'ru':
      return AppLocalizationsRu();
    case 'te':
      return AppLocalizationsTe();
    case 'th':
      return AppLocalizationsTh();
    case 'tr':
      return AppLocalizationsTr();
    case 'ur':
      return AppLocalizationsUr();
    case 'vi':
      return AppLocalizationsVi();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
