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

  /// Link on the login page that opens the forgot-password form.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// App bar title of the forgot-password page.
  ///
  /// In en, this message translates to:
  /// **'Reset Your Password'**
  String get forgotPasswordTitle;

  /// Subtitle on the forgot-password page explaining the flow.
  ///
  /// In en, this message translates to:
  /// **'Enter your email address and we\'ll send you a link to reset your password.'**
  String get forgotPasswordPrompt;

  /// Info message shown after the user submits the forgot-password form. Identical regardless of whether the email belongs to an account, preventing user enumeration.
  ///
  /// In en, this message translates to:
  /// **'If an account with that email exists, a password reset link has been sent.'**
  String get forgotPasswordInfo;

  /// Submit button on the forgot-password page.
  ///
  /// In en, this message translates to:
  /// **'Send Reset Link'**
  String get sendResetLink;

  /// Link/button that returns to the login page after the forgot-password info message.
  ///
  /// In en, this message translates to:
  /// **'Back to Login'**
  String get backToLogin;

  /// App bar title of the reset-password page (reached via deep link).
  ///
  /// In en, this message translates to:
  /// **'Set New Password'**
  String get resetPasswordTitle;

  /// Subtitle on the reset-password page.
  ///
  /// In en, this message translates to:
  /// **'Enter a new password below. Your password must be at least 8 characters.'**
  String get resetPasswordPrompt;

  /// Success message shown after a successful password reset.
  ///
  /// In en, this message translates to:
  /// **'Your password has been reset. You can now sign in with your new password.'**
  String get resetPasswordSuccess;

  /// Error shown when the reset page is opened without a token in the URL.
  ///
  /// In en, this message translates to:
  /// **'No reset token was found in the link. Please request a new password reset link.'**
  String get resetPasswordTokenMissing;

  /// Error shown when the backend rejects the reset token.
  ///
  /// In en, this message translates to:
  /// **'This password reset link is invalid, expired, or has already been used. Please request a new one.'**
  String get resetPasswordTokenInvalid;

  /// Validation error when the new password is too short (minimum 8 characters enforced by the backend).
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters'**
  String get passwordMinLengthReset;

  /// Label for the confirm-new-password field on the reset page.
  ///
  /// In en, this message translates to:
  /// **'Confirm New Password'**
  String get confirmNewPasswordLabel;

  /// Validation error when the two password fields on the reset page differ.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDoNotMatchReset;

  /// Error shown when the forgot-password API call fails; {error} is the underlying detail (server message or exception).
  ///
  /// In en, this message translates to:
  /// **'Failed to send reset link: {error}'**
  String forgotPasswordFailed(String error);

  /// Error shown when the reset-password API call fails; {error} is the underlying detail (server message or exception).
  ///
  /// In en, this message translates to:
  /// **'Password reset failed: {error}'**
  String passwordResetFailed(String error);

  /// Error shown when the backend reports the token is expired.
  ///
  /// In en, this message translates to:
  /// **'This password reset link has expired. Please request a new one.'**
  String get passwordResetTokenExpired;

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

  /// Neutral hint shown when statistics are withheld because fewer than the privacy threshold of matching answers exist.
  ///
  /// In en, this message translates to:
  /// **'Not enough responses yet to show statistics'**
  String get statsInsufficientData;

  /// Title of the consent dialog for questions with a special category.
  ///
  /// In en, this message translates to:
  /// **'Sensitive question'**
  String get specialCategoryConsentTitle;

  /// Body of the consent dialog for special-category questions; {category} is the localized name of the GDPR Art. 9 category.
  ///
  /// In en, this message translates to:
  /// **'This question deals with the sensitive category \"{category}\". Your explicit consent is required to answer it; it will be recorded anonymously together with your answer.'**
  String specialCategoryConsentBody(String category);

  /// Confirmation button of the consent dialog for special-category questions.
  ///
  /// In en, this message translates to:
  /// **'I consent and want to answer'**
  String get specialCategoryConsentAccept;

  /// No description provided for @specialCategoryRacialOrEthnicOrigin.
  ///
  /// In en, this message translates to:
  /// **'Racial or ethnic origin'**
  String get specialCategoryRacialOrEthnicOrigin;

  /// No description provided for @specialCategoryPoliticalOpinion.
  ///
  /// In en, this message translates to:
  /// **'Political opinion'**
  String get specialCategoryPoliticalOpinion;

  /// No description provided for @specialCategoryReligiousOrPhilosophicalBelief.
  ///
  /// In en, this message translates to:
  /// **'Religious or philosophical belief'**
  String get specialCategoryReligiousOrPhilosophicalBelief;

  /// No description provided for @specialCategoryTradeUnionMembership.
  ///
  /// In en, this message translates to:
  /// **'Trade union membership'**
  String get specialCategoryTradeUnionMembership;

  /// No description provided for @specialCategoryGeneticData.
  ///
  /// In en, this message translates to:
  /// **'Genetic data'**
  String get specialCategoryGeneticData;

  /// No description provided for @specialCategoryBiometricData.
  ///
  /// In en, this message translates to:
  /// **'Biometric data'**
  String get specialCategoryBiometricData;

  /// No description provided for @specialCategoryHealth.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get specialCategoryHealth;

  /// No description provided for @specialCategorySexLifeOrOrientation.
  ///
  /// In en, this message translates to:
  /// **'Sex life or sexual orientation'**
  String get specialCategorySexLifeOrOrientation;

  /// No description provided for @specialCategoryCriminalConvictions.
  ///
  /// In en, this message translates to:
  /// **'Criminal convictions'**
  String get specialCategoryCriminalConvictions;

  /// Section title for the min-age/special-category inputs shown to admins when approving a submission.
  ///
  /// In en, this message translates to:
  /// **'Approval settings'**
  String get approvalSettingsTitle;

  /// Label of the minimum-age input an admin sets when approving a submission.
  ///
  /// In en, this message translates to:
  /// **'Minimum age'**
  String get approvalMinAgeLabel;

  /// Label of the special-category selector an admin sets when approving a submission.
  ///
  /// In en, this message translates to:
  /// **'Special category'**
  String get specialCategoryLabel;

  /// Selector entry marking a question as not carrying a GDPR Art. 9 category.
  ///
  /// In en, this message translates to:
  /// **'No special category'**
  String get specialCategoryNone;

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

  /// Error snack bar shown when submitting a vote fails because the question was already answered (HTTP 409).
  ///
  /// In en, this message translates to:
  /// **'You have already answered this question'**
  String get alreadyAnswered;

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

  /// Menu item to navigate to the login screen when no user is authenticated.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// Menu item that prompts the user to confirm switching to a different account.
  ///
  /// In en, this message translates to:
  /// **'Change User'**
  String get changeUser;

  /// Confirmation dialog message when the user selects Change User.
  ///
  /// In en, this message translates to:
  /// **'Do you want to switch to a different user account?'**
  String get changeUserConfirm;

  /// Negative button label for the change-user confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// Menu item to delete the user's account.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// Confirmation dialog message when the user selects delete account.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete your account? This action cannot be undone.'**
  String get deleteAccountConfirm;

  /// Negative button label for the delete-account confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get deleteAccountCancel;

  /// Positive button label for the delete-account confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteAccountPositive;

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

  /// Button that switches the account details dialog to edit mode.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// Button that saves the edited account details.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Title of the account details dialog while editing.
  ///
  /// In en, this message translates to:
  /// **'Edit Account Details'**
  String get editUserDetailsTitle;

  /// Label for the optional new-password field in the edit form.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get newPasswordLabel;

  /// Label for the confirm-new-password field in the edit form.
  ///
  /// In en, this message translates to:
  /// **'Confirm New Password'**
  String get newPasswordConfirmLabel;

  /// Validation error when the new password is too short (minimum 8 characters enforced by the backend).
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters'**
  String get passwordChangeMinLength;

  /// Success message shown after the profile was updated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated successfully'**
  String get profileUpdateSuccess;

  /// Error shown when updating the profile fails; {error} is the underlying detail (server message or exception).
  ///
  /// In en, this message translates to:
  /// **'Failed to update profile: {error}'**
  String profileUpdateFailed(String error);

  /// Error shown when deleting the account fails; {error} is the underlying detail (server message or exception).
  ///
  /// In en, this message translates to:
  /// **'Failed to delete account: {error}'**
  String deleteAccountFailed(String error);

  /// Label for the read-only administrator status shown to admin users.
  ///
  /// In en, this message translates to:
  /// **'Administrator'**
  String get isAdminLabel;

  /// Value shown for the administrator status when the user is an admin.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// Drawer / navigation label for the public list of questions.
  ///
  /// In en, this message translates to:
  /// **'Questions'**
  String get questions;

  /// Drawer / page title for the current user's own question submissions.
  ///
  /// In en, this message translates to:
  /// **'My Submissions'**
  String get mySubmissions;

  /// Empty-state message on the submissions page when the user has no submissions.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t submitted any questions yet.'**
  String get mySubmissionsEmpty;

  /// Label of the floating action button that opens the submit-question dialog.
  ///
  /// In en, this message translates to:
  /// **'New Question'**
  String get createQuestion;

  /// Title of the dialog used to submit a new question.
  ///
  /// In en, this message translates to:
  /// **'Submit a Question'**
  String get newQuestionTitle;

  /// Label for the question text field in the submit dialog.
  ///
  /// In en, this message translates to:
  /// **'Question'**
  String get questionTextLabel;

  /// Hint for the question text field in the submit dialog.
  ///
  /// In en, this message translates to:
  /// **'Enter your question...'**
  String get questionTextHint;

  /// Label for the category selector in the submit dialog.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get categoryLabel;

  /// Label for the language selector in the submit dialog.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageLabel;

  /// Label for the optional minimum-age field in the submit dialog.
  ///
  /// In en, this message translates to:
  /// **'Minimum age (optional)'**
  String get minAgeLabel;

  /// Hint for the optional minimum-age field in the submit dialog.
  ///
  /// In en, this message translates to:
  /// **'0 = everyone'**
  String get minAgeHint;

  /// Button that submits a new question from the dialog.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// Success message shown after a question was submitted.
  ///
  /// In en, this message translates to:
  /// **'Question submitted for review'**
  String get submissionCreated;

  /// Error message shown when submitting a question fails.
  ///
  /// In en, this message translates to:
  /// **'Failed to submit the question'**
  String get submissionFailed;

  /// Error message shown when loading the user's submissions fails.
  ///
  /// In en, this message translates to:
  /// **'Failed to load your submissions'**
  String get submissionLoadFailed;

  /// Status chip label for a submission awaiting review.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get submissionPending;

  /// Status chip label for an approved submission.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get submissionApproved;

  /// Status chip label for a rejected submission.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get submissionRejected;

  /// Validation error shown when a required field is empty.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get requiredField;

  /// Label showing when a submission was created; {date} is the formatted date.
  ///
  /// In en, this message translates to:
  /// **'Submitted on {date}'**
  String submittedOn(String date);

  /// Section label for the answer-option fields in the submit-question dialog.
  ///
  /// In en, this message translates to:
  /// **'Answer options'**
  String get answerOptionsLabel;

  /// Label for a single answer-option input; {number} is its 1-based position.
  ///
  /// In en, this message translates to:
  /// **'Answer option {number}'**
  String answerOptionLabel(int number);

  /// Hint text for an answer-option input in the submit-question dialog.
  ///
  /// In en, this message translates to:
  /// **'Enter an answer option'**
  String get answerOptionHint;

  /// Button that appends another answer-option field in the submit-question dialog.
  ///
  /// In en, this message translates to:
  /// **'Add answer option'**
  String get addAnswerOption;

  /// Tooltip for the button that removes an answer-option field in the submit-question dialog.
  ///
  /// In en, this message translates to:
  /// **'Remove answer option'**
  String get removeAnswerOption;

  /// Error shown when the submit-question dialog has no answer options filled in.
  ///
  /// In en, this message translates to:
  /// **'Please provide at least one answer option'**
  String get atLeastOneAnswerOption;

  /// Error shown when the user tries to add more than the allowed number of answer options; {max} is the limit.
  ///
  /// In en, this message translates to:
  /// **'You can add at most {max} answer options'**
  String maxAnswerOptionsReached(int max);

  /// Drawer / page title for the administrator review queue of submitted questions.
  ///
  /// In en, this message translates to:
  /// **'Review Queue'**
  String get adminReviewQueue;

  /// Empty-state message on the admin review-queue page when there are no pending submissions.
  ///
  /// In en, this message translates to:
  /// **'There are no submissions to review.'**
  String get adminSubmissionsEmpty;

  /// Error message shown when loading the admin review queue fails.
  ///
  /// In en, this message translates to:
  /// **'Failed to load submissions'**
  String get adminSubmissionsLoadFailed;

  /// Button label that approves a submitted question (makes it publicly visible).
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get approve;

  /// Button label that rejects a submitted question.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get reject;

  /// Label showing the user id of the submitter; {id} is the user id.
  ///
  /// In en, this message translates to:
  /// **'Submitted by user {id}'**
  String submittedBy(String id);

  /// Label showing the user id of the reviewer; {id} is the user id.
  ///
  /// In en, this message translates to:
  /// **'Reviewed by user {id}'**
  String reviewedBy(String id);

  /// App bar title of the admin submission detail screen.
  ///
  /// In en, this message translates to:
  /// **'Submission Details'**
  String get submissionDetailsTitle;

  /// Success snack bar shown after a question was approved.
  ///
  /// In en, this message translates to:
  /// **'Question approved'**
  String get submissionApprovedMessage;

  /// Success snack bar shown after a question was rejected.
  ///
  /// In en, this message translates to:
  /// **'Question rejected'**
  String get submissionRejectedMessage;

  /// Error message shown when approving a question fails.
  ///
  /// In en, this message translates to:
  /// **'Failed to approve the question'**
  String get approveFailed;

  /// Error message shown when rejecting a question fails.
  ///
  /// In en, this message translates to:
  /// **'Failed to reject the question'**
  String get rejectFailed;

  /// Button label to delete a question (admin only).
  ///
  /// In en, this message translates to:
  /// **'Delete Question'**
  String get deleteQuestion;

  /// Confirmation dialog message when deleting a question.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this question? This action cannot be undone.'**
  String get deleteQuestionConfirm;

  /// Success message shown after a question was deleted.
  ///
  /// In en, this message translates to:
  /// **'Question deleted successfully'**
  String get deleteQuestionSuccess;

  /// Error message shown when deleting a question fails.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete the question'**
  String get deleteQuestionFailed;

  /// Button label to change a question text (admin only).
  ///
  /// In en, this message translates to:
  /// **'Change Question'**
  String get changeQuestion;

  /// Title of the dialog to change question text.
  ///
  /// In en, this message translates to:
  /// **'Change Question Text'**
  String get changeQuestionTitle;

  /// Label for the current question text display.
  ///
  /// In en, this message translates to:
  /// **'Current question text'**
  String get currentQuestionText;

  /// Label for the new question text input field.
  ///
  /// In en, this message translates to:
  /// **'New question text'**
  String get newQuestionText;

  /// Success message shown after a question text was changed.
  ///
  /// In en, this message translates to:
  /// **'Question text changed successfully'**
  String get changeQuestionSuccess;

  /// Error message shown when changing a question text fails.
  ///
  /// In en, this message translates to:
  /// **'Failed to change the question text'**
  String get changeQuestionFailed;

  /// Note shown on a submission that has already been approved or rejected.
  ///
  /// In en, this message translates to:
  /// **'This submission has already been reviewed.'**
  String get submissionAlreadyReviewed;

  /// Note shown when the submitted answer options cannot be loaded for an admin review (e.g. the backend does not expose them for unapproved submissions).
  ///
  /// In en, this message translates to:
  /// **'The submitted answers are not available for review.'**
  String get answersNotVisible;

  /// Drawer / page title for the administrator user management page.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get adminUsers;

  /// Empty-state message on the admin user management page when there are no users.
  ///
  /// In en, this message translates to:
  /// **'There are no users to display.'**
  String get adminUsersEmpty;

  /// Error message shown when loading the admin user list fails.
  ///
  /// In en, this message translates to:
  /// **'Failed to load users'**
  String get adminUsersLoadFailed;

  /// Label showing the user id; {id} is the user id.
  ///
  /// In en, this message translates to:
  /// **'User {id}'**
  String adminUserId(String id);

  /// App bar title of the admin user detail screen.
  ///
  /// In en, this message translates to:
  /// **'User Details'**
  String get adminUserDetailsTitle;

  /// Error message shown when loading a user's details fails.
  ///
  /// In en, this message translates to:
  /// **'Failed to load user details'**
  String get adminUserDetailsLoadFailed;

  /// Status label shown when a user account is active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get adminUserActiveStatus;

  /// Status label shown when a user account is inactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get adminUserInactiveStatus;

  /// Button label that activates a user account.
  ///
  /// In en, this message translates to:
  /// **'Activate'**
  String get activateUser;

  /// Button label that deactivates a user account.
  ///
  /// In en, this message translates to:
  /// **'Deactivate'**
  String get deactivateUser;

  /// Success snack bar shown after a user was activated.
  ///
  /// In en, this message translates to:
  /// **'User activated'**
  String get activateUserSuccess;

  /// Success snack bar shown after a user was deactivated.
  ///
  /// In en, this message translates to:
  /// **'User deactivated'**
  String get deactivateUserSuccess;

  /// Error message shown when activating a user fails.
  ///
  /// In en, this message translates to:
  /// **'Failed to activate user'**
  String get activateUserFailed;

  /// Error message shown when deactivating a user fails.
  ///
  /// In en, this message translates to:
  /// **'Failed to deactivate user'**
  String get deactivateUserFailed;

  /// Top-level menu label for the app configuration menu in the AppBar.
  ///
  /// In en, this message translates to:
  /// **'Configuration'**
  String get configuration;

  /// Submenu label under Configuration for appearance-related settings.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// Label for the theme color setting under the Appearance submenu.
  ///
  /// In en, this message translates to:
  /// **'Theme Color'**
  String get themeColor;

  /// Label for the dark view setting under the Appearance submenu.
  ///
  /// In en, this message translates to:
  /// **'Dark View'**
  String get darkView;

  /// Option to follow the system-wide light or dark appearance.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeModeSystem;

  /// Option to always use the light appearance.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeModeLight;

  /// Option to always use the dark appearance.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeModeDark;

  /// Name of the Deep Purple theme color option.
  ///
  /// In en, this message translates to:
  /// **'Deep Purple'**
  String get colorDeepPurple;

  /// Name of the Blue theme color option.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get colorBlue;

  /// Name of the Teal theme color option.
  ///
  /// In en, this message translates to:
  /// **'Teal'**
  String get colorTeal;

  /// Name of the Green theme color option.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get colorGreen;

  /// Name of the Orange theme color option.
  ///
  /// In en, this message translates to:
  /// **'Orange'**
  String get colorOrange;

  /// Name of the Red theme color option.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get colorRed;

  /// Name of the Pink theme color option.
  ///
  /// In en, this message translates to:
  /// **'Pink'**
  String get colorPink;

  /// Name of the Cyan theme color option.
  ///
  /// In en, this message translates to:
  /// **'Cyan'**
  String get colorCyan;

  /// Name of the Indigo theme color option.
  ///
  /// In en, this message translates to:
  /// **'Indigo'**
  String get colorIndigo;

  /// Name of the Amber theme color option.
  ///
  /// In en, this message translates to:
  /// **'Amber'**
  String get colorAmber;
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
