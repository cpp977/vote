// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Vote';

  @override
  String welcomeToApp(String appName) {
    return 'Welcome to $appName';
  }

  @override
  String joinApp(String appName) {
    return 'Join $appName';
  }

  @override
  String get signInToContinue => 'Sign in to continue';

  @override
  String get noAccountPrompt => 'Don\'t have an account? ';

  @override
  String get signUp => 'Sign Up';

  @override
  String get signIn => 'Sign In';

  @override
  String get forgotPassword => 'Forgot Password?';

  @override
  String get forgotPasswordTitle => 'Reset Your Password';

  @override
  String get forgotPasswordPrompt =>
      'Enter your email address and we\'ll send you a link to reset your password.';

  @override
  String get forgotPasswordInfo =>
      'If an account with that email exists, a password reset link has been sent.';

  @override
  String get sendResetLink => 'Send Reset Link';

  @override
  String get backToLogin => 'Back to Login';

  @override
  String get resetPasswordTitle => 'Set New Password';

  @override
  String get resetPasswordPrompt =>
      'Enter a new password below. Your password must be at least 8 characters.';

  @override
  String get resetPasswordSuccess =>
      'Your password has been reset. You can now sign in with your new password.';

  @override
  String get resetPasswordTokenMissing =>
      'No reset token was found in the link. Please request a new password reset link.';

  @override
  String get resetPasswordTokenInvalid =>
      'This password reset link is invalid, expired, or has already been used. Please request a new one.';

  @override
  String get passwordMinLengthReset => 'Password must be at least 8 characters';

  @override
  String get confirmNewPasswordLabel => 'Confirm New Password';

  @override
  String get passwordsDoNotMatchReset => 'Passwords do not match';

  @override
  String forgotPasswordFailed(String error) {
    return 'Failed to send reset link: $error';
  }

  @override
  String passwordResetFailed(String error) {
    return 'Password reset failed: $error';
  }

  @override
  String get passwordResetTokenExpired =>
      'This password reset link has expired. Please request a new one.';

  @override
  String get usernameLabel => 'Username';

  @override
  String get passwordLabel => 'Password';

  @override
  String get usernameRequired => 'Please enter your username';

  @override
  String get passwordRequired => 'Please enter your password';

  @override
  String get createAccount => 'Create Account';

  @override
  String get createAccountSubtitle => 'Create an account to get started';

  @override
  String get usernameRequiredAlt => 'Please enter a username';

  @override
  String get usernameMinLength => 'Username must be at least 3 characters';

  @override
  String get emailLabel => 'Email';

  @override
  String get emailRequired => 'Please enter your email';

  @override
  String get emailInvalid => 'Please enter a valid email';

  @override
  String get birthYearLabel => 'Birth Year';

  @override
  String get genderLabel => 'Gender';

  @override
  String get genderMale => 'Male';

  @override
  String get genderFemale => 'Female';

  @override
  String get genderDiverse => 'Diverse';

  @override
  String get nationalityLabel => 'Nationality';

  @override
  String get nationalityOtherLabel => 'Please specify';

  @override
  String get regionLabel => 'Region';

  @override
  String get loadingLabel => 'Loading...';

  @override
  String get selectNationalityFirst => 'Select a nationality first';

  @override
  String get noRegionsAvailable => 'No regions available for this nationality';

  @override
  String get passwordRequiredAlt => 'Please enter a password';

  @override
  String get passwordMinLength => 'Password must be at least 6 characters';

  @override
  String get confirmPasswordLabel => 'Confirm Password';

  @override
  String get confirmPasswordRequired => 'Please confirm your password';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  @override
  String get registrationSuccess => 'Registration successful! Please sign in.';

  @override
  String get haveAccountPrompt => 'Already have an account? ';

  @override
  String get filterDialogTitle => 'Filter by Category';

  @override
  String get noCategoriesAvailable => 'No categories available';

  @override
  String get clear => 'Clear';

  @override
  String get cancel => 'Cancel';

  @override
  String get apply => 'Apply';

  @override
  String get searchDialogTitle => 'Search Questions';

  @override
  String get searchHint => 'Enter search term...';

  @override
  String get ok => 'OK';

  @override
  String get searchFieldHint => 'Search questions...';

  @override
  String get searchTooltip => 'Search questions';

  @override
  String get filterTooltip => 'Filter by category';

  @override
  String get reload => 'Reload';

  @override
  String searchResultsFor(String query) {
    return 'Search results for \"$query\"';
  }

  @override
  String get searchMinChars => 'Type at least three characters';

  @override
  String categoryFallback(int id) {
    return 'Category $id';
  }

  @override
  String get allQuestionsLoaded => 'All questions loaded';

  @override
  String get noQuestionsFound => 'No questions found';

  @override
  String get retry => 'Retry';

  @override
  String get serverError => 'Server returned an error';

  @override
  String connectionError(String error) {
    return 'Failed to connect: $error';
  }

  @override
  String get questionDetailsTitle => 'Question Details';

  @override
  String get questionLabel => 'Question';

  @override
  String get possibleAnswers => 'Possible Answers';

  @override
  String get noAnswersAvailable => 'No answers available for this question.';

  @override
  String get statistics => 'Statistics';

  @override
  String get questionNotFound => 'Question not found';

  @override
  String get statsNotAvailable => 'Statistics not available';

  @override
  String get statsInsufficientData =>
      'Not enough responses yet to show statistics';

  @override
  String get specialCategoryConsentTitle => 'Sensitive question';

  @override
  String specialCategoryConsentBody(String category) {
    return 'This question deals with the sensitive category \"$category\". Your explicit consent is required to answer it; it will be recorded anonymously together with your answer.';
  }

  @override
  String get specialCategoryConsentAccept => 'I consent and want to answer';

  @override
  String get specialCategoryRacialOrEthnicOrigin => 'Racial or ethnic origin';

  @override
  String get specialCategoryPoliticalOpinion => 'Political opinion';

  @override
  String get specialCategoryReligiousOrPhilosophicalBelief =>
      'Religious or philosophical belief';

  @override
  String get specialCategoryTradeUnionMembership => 'Trade union membership';

  @override
  String get specialCategoryGeneticData => 'Genetic data';

  @override
  String get specialCategoryBiometricData => 'Biometric data';

  @override
  String get specialCategoryHealth => 'Health';

  @override
  String get specialCategorySexLifeOrOrientation =>
      'Sex life or sexual orientation';

  @override
  String get specialCategoryCriminalConvictions => 'Criminal convictions';

  @override
  String get approvalSettingsTitle => 'Approval settings';

  @override
  String get approvalMinAgeLabel => 'Minimum age';

  @override
  String get specialCategoryLabel => 'Special category';

  @override
  String get specialCategoryNone => 'No special category';

  @override
  String get statsLoadFailed => 'Failed to load statistics';

  @override
  String voteSubmitted(String answer) {
    return 'Vote for \"$answer\" submitted!';
  }

  @override
  String errorWithMessage(String message) {
    return 'Error: $message';
  }

  @override
  String voteSubmitFailed(String error) {
    return 'Failed to submit vote: $error';
  }

  @override
  String get alreadyAnswered => 'You have already answered this question';

  @override
  String get votesNoun => 'votes';

  @override
  String get noVotesYet => 'No votes yet';

  @override
  String totalVotes(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count votes total',
      one: '$count vote total',
      zero: 'No votes',
    );
    return '$_temp0';
  }

  @override
  String votesCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count votes',
      one: '$count vote',
      zero: 'No votes',
    );
    return '$_temp0';
  }

  @override
  String get viewBars => 'Bars';

  @override
  String get viewDonut => 'Donut';

  @override
  String get breakdownLabel => 'Breakdown';

  @override
  String get filterEveryone => 'Everyone';

  @override
  String get addFilter => 'Add filter';

  @override
  String get statsFilterSheetTitle => 'Break down the results';

  @override
  String get statsFilterSheetHint =>
      'Combine any number of characteristics. Segments with too few responses stay hidden.';

  @override
  String get removeFilterTooltip => 'Remove filter';

  @override
  String get dimensionAge => 'Age';

  @override
  String get dimensionNationality => 'Nationality';

  @override
  String get dimensionRegion => 'Region';

  @override
  String get ageUnder18 => 'Under 18';

  @override
  String get age18To29 => '18–29';

  @override
  String get age30To39 => '30–39';

  @override
  String get age40To49 => '40–49';

  @override
  String get age50To59 => '50–59';

  @override
  String get age60Plus => '60 or older';

  @override
  String get nationalityGermany => 'Germany';

  @override
  String get nationalityAustria => 'Austria';

  @override
  String get nationalitySwitzerland => 'Switzerland';

  @override
  String get nationalityFrance => 'France';

  @override
  String get nationalityItaly => 'Italy';

  @override
  String get nationalityNetherlands => 'Netherlands';

  @override
  String get nationalityPoland => 'Poland';

  @override
  String get nationalitySpain => 'Spain';

  @override
  String get nationalityTurkey => 'Türkiye';

  @override
  String get nationalityUkraine => 'Ukraine';

  @override
  String get uncategorized => 'Uncategorized';

  @override
  String get userInitialFallback => 'U';

  @override
  String get userMenuName => 'User';

  @override
  String get logout => 'Logout';

  @override
  String loginFailed(String error) {
    return 'Login failed: $error';
  }

  @override
  String registrationFailed(String error) {
    return 'Registration failed: $error';
  }

  @override
  String requestFailedStatus(String status) {
    return 'Request failed with status $status';
  }

  @override
  String get login => 'Login';

  @override
  String get changeUser => 'Change User';

  @override
  String get changeUserConfirm =>
      'Do you want to switch to a different user account?';

  @override
  String get no => 'No';

  @override
  String get deleteAccount => 'Delete Account';

  @override
  String get deleteAccountConfirm =>
      'Are you sure you want to delete your account? This action cannot be undone.';

  @override
  String get deleteAccountCancel => 'Cancel';

  @override
  String get deleteAccountPositive => 'Delete';

  @override
  String get userDetails => 'My Details';

  @override
  String get userDetailsTitle => 'Account Details';

  @override
  String get close => 'Close';

  @override
  String get notAvailable => 'Not available';

  @override
  String get edit => 'Edit';

  @override
  String get save => 'Save';

  @override
  String get editUserDetailsTitle => 'Edit Account Details';

  @override
  String get newPasswordLabel => 'New Password';

  @override
  String get newPasswordConfirmLabel => 'Confirm New Password';

  @override
  String get passwordChangeMinLength =>
      'Password must be at least 8 characters';

  @override
  String get profileUpdateSuccess => 'Profile updated successfully';

  @override
  String profileUpdateFailed(String error) {
    return 'Failed to update profile: $error';
  }

  @override
  String deleteAccountFailed(String error) {
    return 'Failed to delete account: $error';
  }

  @override
  String get isAdminLabel => 'Administrator';

  @override
  String get yes => 'Yes';

  @override
  String get questions => 'Questions';

  @override
  String get mySubmissions => 'My Submissions';

  @override
  String get mySubmissionsEmpty => 'You haven\'t submitted any questions yet.';

  @override
  String get createQuestion => 'New Question';

  @override
  String get newQuestionTitle => 'Submit a Question';

  @override
  String get questionTextLabel => 'Question';

  @override
  String get questionTextHint => 'Enter your question...';

  @override
  String get categoryLabel => 'Category';

  @override
  String get languageLabel => 'Language';

  @override
  String get minAgeLabel => 'Minimum age (optional)';

  @override
  String get minAgeHint => '0 = everyone';

  @override
  String get submit => 'Submit';

  @override
  String get submissionCreated => 'Question submitted for review';

  @override
  String get submissionFailed => 'Failed to submit the question';

  @override
  String get submissionLoadFailed => 'Failed to load your submissions';

  @override
  String get submissionPending => 'Pending';

  @override
  String get submissionApproved => 'Approved';

  @override
  String get submissionRejected => 'Rejected';

  @override
  String get requiredField => 'This field is required';

  @override
  String submittedOn(String date) {
    return 'Submitted on $date';
  }

  @override
  String get answerOptionsLabel => 'Answer options';

  @override
  String answerOptionLabel(int number) {
    return 'Answer option $number';
  }

  @override
  String get answerOptionHint => 'Enter an answer option';

  @override
  String get addAnswerOption => 'Add answer option';

  @override
  String get removeAnswerOption => 'Remove answer option';

  @override
  String get atLeastOneAnswerOption =>
      'Please provide at least one answer option';

  @override
  String maxAnswerOptionsReached(int max) {
    return 'You can add at most $max answer options';
  }

  @override
  String get adminReviewQueue => 'Review Queue';

  @override
  String get adminSubmissionsEmpty => 'There are no submissions to review.';

  @override
  String get adminSubmissionsLoadFailed => 'Failed to load submissions';

  @override
  String get approve => 'Approve';

  @override
  String get reject => 'Reject';

  @override
  String submittedBy(String id) {
    return 'Submitted by user $id';
  }

  @override
  String reviewedBy(String id) {
    return 'Reviewed by user $id';
  }

  @override
  String get submissionDetailsTitle => 'Submission Details';

  @override
  String get submissionApprovedMessage => 'Question approved';

  @override
  String get submissionRejectedMessage => 'Question rejected';

  @override
  String get approveFailed => 'Failed to approve the question';

  @override
  String get rejectFailed => 'Failed to reject the question';

  @override
  String get deleteQuestion => 'Delete Question';

  @override
  String get deleteQuestionConfirm =>
      'Are you sure you want to delete this question? This action cannot be undone.';

  @override
  String get deleteQuestionSuccess => 'Question deleted successfully';

  @override
  String get deleteQuestionFailed => 'Failed to delete the question';

  @override
  String get changeQuestion => 'Change Question';

  @override
  String get changeQuestionTitle => 'Change Question Text';

  @override
  String get currentQuestionText => 'Current question text';

  @override
  String get newQuestionText => 'New question text';

  @override
  String get changeQuestionSuccess => 'Question text changed successfully';

  @override
  String get changeQuestionFailed => 'Failed to change the question text';

  @override
  String get submissionAlreadyReviewed =>
      'This submission has already been reviewed.';

  @override
  String get answersNotVisible =>
      'The submitted answers are not available for review.';

  @override
  String get adminUsers => 'Users';

  @override
  String get adminUsersEmpty => 'There are no users to display.';

  @override
  String get adminUsersLoadFailed => 'Failed to load users';

  @override
  String adminUserId(String id) {
    return 'User $id';
  }

  @override
  String get adminUserDetailsTitle => 'User Details';

  @override
  String get adminUserDetailsLoadFailed => 'Failed to load user details';

  @override
  String get adminUserActiveStatus => 'Active';

  @override
  String get adminUserInactiveStatus => 'Inactive';

  @override
  String get activateUser => 'Activate';

  @override
  String get deactivateUser => 'Deactivate';

  @override
  String get activateUserSuccess => 'User activated';

  @override
  String get deactivateUserSuccess => 'User deactivated';

  @override
  String get activateUserFailed => 'Failed to activate user';

  @override
  String get deactivateUserFailed => 'Failed to deactivate user';

  @override
  String get configuration => 'Configuration';

  @override
  String get appearance => 'Appearance';

  @override
  String get themeColor => 'Theme Color';

  @override
  String get darkView => 'Dark View';

  @override
  String get themeModeSystem => 'System';

  @override
  String get themeModeLight => 'Light';

  @override
  String get themeModeDark => 'Dark';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System Language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageGerman => 'German';

  @override
  String get colorDeepPurple => 'Deep Purple';

  @override
  String get colorBlue => 'Blue';

  @override
  String get colorTeal => 'Teal';

  @override
  String get colorGreen => 'Green';

  @override
  String get colorOrange => 'Orange';

  @override
  String get colorRed => 'Red';

  @override
  String get colorPink => 'Pink';

  @override
  String get colorCyan => 'Cyan';

  @override
  String get colorIndigo => 'Indigo';

  @override
  String get colorAmber => 'Amber';
}
