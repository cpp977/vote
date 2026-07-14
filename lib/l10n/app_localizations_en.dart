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
  String get viewGender => 'Gender';

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
}
