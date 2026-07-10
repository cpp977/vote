import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
    Locale('en'),
    Locale('de'),
  ];

  /// Brand name of the application. Kept untranslated on purpose.
  ///
  /// In en, this message translates to:
  /// **'Vote'**
  String get appName;

  /// Login screen greeting; {appName} is the brand and stays 'Vote'.
  ///
  /// In en, this message translates to:
  /// **'Welcome to {appName}'**
  String welcomeToApp(String appName);

  /// Register screen heading; {appName} is the brand and stays 'Vote'.
  ///
  /// In en, this message translates to:
  /// **'Join {appName}'**
  String joinApp(String appName);

  /// Subtitle on the login screen.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue'**
  String get signInToContinue;

  /// Prompt inviting the user to register (followed by a Sign Up button).
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? '**
  String get noAccountPrompt;

  /// Button/link to navigate to the registration screen.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// Button/link to sign in or go to the login screen.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// Label for the username input field.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get usernameLabel;

  /// Label for the password input field.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// Validation error when the login username is empty.
  ///
  /// In en, this message translates to:
  /// **'Please enter your username'**
  String get usernameRequired;

  /// Validation error when the login password is empty.
  ///
  /// In en, this message translates to:
  /// **'Please enter your password'**
  String get passwordRequired;

  /// App bar title and submit button on the registration screen.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// Subtitle on the registration screen.
  ///
  /// In en, this message translates to:
  /// **'Create an account to get started'**
  String get createAccountSubtitle;

  /// Validation error when the registration username is empty.
  ///
  /// In en, this message translates to:
  /// **'Please enter a username'**
  String get usernameRequiredAlt;

  /// Validation error when the username is too short.
  ///
  /// In en, this message translates to:
  /// **'Username must be at least 3 characters'**
  String get usernameMinLength;

  /// Label for the email input field.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// Validation error when the email is empty.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email'**
  String get emailRequired;

  /// Validation error when the email format is invalid.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email'**
  String get emailInvalid;

  /// Label for the birth year selector.
  ///
  /// In en, this message translates to:
  /// **'Birth Year'**
  String get birthYearLabel;

  /// Label for the gender selector.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get genderLabel;

  /// Gender option label (value sent to backend: 'm').
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get genderMale;

  /// Gender option label (value sent to backend: 'w').
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get genderFemale;

  /// Gender option label (value sent to backend: 'd').
  ///
  /// In en, this message translates to:
  /// **'Diverse'**
  String get genderDiverse;

  /// Label for the nationality selector.
  ///
  /// In en, this message translates to:
  /// **'Nationality'**
  String get nationalityLabel;

  /// Label for the free-text field shown when 'Other' nationality is selected.
  ///
  /// In en, this message translates to:
  /// **'Please specify'**
  String get nationalityOtherLabel;

  /// Validation error when the registration password is empty.
  ///
  /// In en, this message translates to:
  /// **'Please enter a password'**
  String get passwordRequiredAlt;

  /// Validation error when the password is too short.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get passwordMinLength;

  /// Label for the confirm-password input field.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPasswordLabel;

  /// Validation error when the confirm-password field is empty.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your password'**
  String get confirmPasswordRequired;

  /// Validation error when the two password fields differ.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDoNotMatch;

  /// Success snack bar shown after a successful registration.
  ///
  /// In en, this message translates to:
  /// **'Registration successful! Please sign in.'**
  String get registrationSuccess;

  /// Prompt inviting the user to sign in (followed by a Sign In button).
  ///
  /// In en, this message translates to:
  /// **'Already have an account? '**
  String get haveAccountPrompt;

  /// Title of the category filter dialog.
  ///
  /// In en, this message translates to:
  /// **'Filter by Category'**
  String get filterDialogTitle;

  /// Message shown when there are no categories to filter by.
  ///
  /// In en, this message translates to:
  /// **'No categories available'**
  String get noCategoriesAvailable;

  /// Generic clear action (category filter dialog and active search indicator).
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// Generic cancel action.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Apply action in the category filter dialog.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// Title of the search dialog.
  ///
  /// In en, this message translates to:
  /// **'Search Questions'**
  String get searchDialogTitle;

  /// Hint text inside the search dialog input.
  ///
  /// In en, this message translates to:
  /// **'Enter search term...'**
  String get searchHint;

  /// Generic confirm action in the search dialog.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// Hint text of the inline search field on the home screen.
  ///
  /// In en, this message translates to:
  /// **'Search questions...'**
  String get searchFieldHint;

  /// Tooltip for the search button.
  ///
  /// In en, this message translates to:
  /// **'Search questions'**
  String get searchTooltip;

  /// Tooltip for the category filter button.
  ///
  /// In en, this message translates to:
  /// **'Filter by category'**
  String get filterTooltip;

  /// Tooltip for the reload button.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get reload;

  /// Header shown above search results; {query} is the user's search term.
  ///
  /// In en, this message translates to:
  /// **'Search results for \"{query}\"'**
  String searchResultsFor(String query);

  /// Hint shown when the search term is shorter than 3 characters.
  ///
  /// In en, this message translates to:
  /// **'Type at least three characters'**
  String get searchMinChars;

  /// Fallback label for a category chip when the name is unknown; {id} is the numeric category id.
  ///
  /// In en, this message translates to:
  /// **'Category {id}'**
  String categoryFallback(int id);

  /// Footer shown when every question has been loaded.
  ///
  /// In en, this message translates to:
  /// **'All questions loaded'**
  String get allQuestionsLoaded;

  /// Empty-state message when no questions match.
  ///
  /// In en, this message translates to:
  /// **'No questions found'**
  String get noQuestionsFound;

  /// Button to retry loading after an error.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Generic error when the server responds with an unexpected status.
  ///
  /// In en, this message translates to:
  /// **'Server returned an error'**
  String get serverError;

  /// Error shown when the network request fails; {error} is the underlying exception message.
  ///
  /// In en, this message translates to:
  /// **'Failed to connect: {error}'**
  String connectionError(String error);

  /// App bar title of the question details screen.
  ///
  /// In en, this message translates to:
  /// **'Question Details'**
  String get questionDetailsTitle;

  /// Section label for the question text.
  ///
  /// In en, this message translates to:
  /// **'Question'**
  String get questionLabel;

  /// Section label for the list of answer options.
  ///
  /// In en, this message translates to:
  /// **'Possible Answers'**
  String get possibleAnswers;

  /// Empty-state message when a question has no answer options.
  ///
  /// In en, this message translates to:
  /// **'No answers available for this question.'**
  String get noAnswersAvailable;

  /// Section label for the voting statistics.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statistics;

  /// Error shown when the question could not be found (404).
  ///
  /// In en, this message translates to:
  /// **'Question not found'**
  String get questionNotFound;

  /// Error shown when statistics could not be loaded (404).
  ///
  /// In en, this message translates to:
  /// **'Statistics not available'**
  String get statsNotAvailable;

  /// Error shown when loading statistics fails for another reason.
  ///
  /// In en, this message translates to:
  /// **'Failed to load statistics'**
  String get statsLoadFailed;

  /// Success snack bar after voting; {answer} is the answer option text returned by the server.
  ///
  /// In en, this message translates to:
  /// **'Vote for \"{answer}\" submitted!'**
  String voteSubmitted(String answer);

  /// Error snack bar with a server-provided message; {message} is the raw server response.
  ///
  /// In en, this message translates to:
  /// **'Error: {message}'**
  String errorWithMessage(String message);

  /// Error snack bar when submitting a vote fails; {error} is the underlying exception message.
  ///
  /// In en, this message translates to:
  /// **'Failed to submit vote: {error}'**
  String voteSubmitFailed(String error);

  /// Noun label shown in the center of the donut chart.
  ///
  /// In en, this message translates to:
  /// **'votes'**
  String get votesNoun;

  /// Empty-state message in the statistics widget before any votes exist.
  ///
  /// In en, this message translates to:
  /// **'No votes yet'**
  String get noVotesYet;

  /// Total-votes badge; {count} is the number of votes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No votes} =1{{count} vote total}other{{count} votes total}}'**
  String totalVotes(num count);

  /// Per-gender vote count; {count} is the number of votes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No votes} =1{{count} vote}other{{count} votes}}'**
  String votesCount(num count);

  /// Tooltip for the bar-chart view toggle.
  ///
  /// In en, this message translates to:
  /// **'Bars'**
  String get viewBars;

  /// Tooltip for the donut-chart view toggle.
  ///
  /// In en, this message translates to:
  /// **'Donut'**
  String get viewDonut;

  /// Tooltip for the gender-comparison view toggle.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get viewGender;

  /// Fallback category name when the backend returns none.
  ///
  /// In en, this message translates to:
  /// **'Uncategorized'**
  String get uncategorized;

  /// Single-letter fallback shown in the user avatar when no username is available.
  ///
  /// In en, this message translates to:
  /// **'U'**
  String get userInitialFallback;

  /// Fallback name shown in the user menu when no username is available.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get userMenuName;

  /// Menu item to log out.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// Login error wrapper; {error} is the underlying detail (server message or exception).
  ///
  /// In en, this message translates to:
  /// **'Login failed: {error}'**
  String loginFailed(String error);

  /// Registration error wrapper; {error} is the underlying detail (server message or exception).
  ///
  /// In en, this message translates to:
  /// **'Registration failed: {error}'**
  String registrationFailed(String error);

  /// Low-level error when the server returns an empty/unparsable body; {status} is the HTTP status code.
  ///
  /// In en, this message translates to:
  /// **'Request failed with status {status}'**
  String requestFailedStatus(String status);

  /// Menu item that opens the account details dialog.
  ///
  /// In en, this message translates to:
  /// **'My Details'**
  String get userDetails;

  /// Title of the account details dialog.
  ///
  /// In en, this message translates to:
  /// **'Account Details'**
  String get userDetailsTitle;

  /// Button label that closes the account details dialog.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// Fallback value shown for a user detail that is missing.
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get notAvailable;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
