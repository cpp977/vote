// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appName => 'Vote';

  @override
  String welcomeToApp(String appName) {
    return 'Willkommen bei $appName';
  }

  @override
  String joinApp(String appName) {
    return 'Tritt $appName bei';
  }

  @override
  String get signInToContinue => 'Anmelden, um fortzufahren';

  @override
  String get noAccountPrompt => 'Noch kein Konto? ';

  @override
  String get signUp => 'Registrieren';

  @override
  String get signIn => 'Anmelden';

  @override
  String get forgotPassword => 'Passwort vergessen?';

  @override
  String get forgotPasswordTitle => 'Passwort zurücksetzen';

  @override
  String get forgotPasswordPrompt =>
      'Gib deine E-Mail-Adresse ein, und wir senden dir einen Link zum Zurücksetzen des Passworts.';

  @override
  String get forgotPasswordInfo =>
      'Wenn ein Konto mit dieser E-Mail-Adresse existiert, wurde ein Link zum Zurücksetzen des Passworts gesendet.';

  @override
  String get sendResetLink => 'Reset-Link senden';

  @override
  String get backToLogin => 'Zurück zur Anmeldung';

  @override
  String get resetPasswordTitle => 'Neues Passwort festlegen';

  @override
  String get resetPasswordPrompt =>
      'Gib ein neues Passwort ein. Es muss mindestens 8 Zeichen lang sein.';

  @override
  String get resetPasswordSuccess =>
      'Dein Passwort wurde zurückgesetzt. Du kannst dich nun mit deinem neuen Passwort anmelden.';

  @override
  String get resetPasswordTokenMissing =>
      'Es wurde kein Reset-Token in dem Link gefunden. Bitte fordere einen neuen Link zum Zurücksetzen des Passworts an.';

  @override
  String get resetPasswordTokenInvalid =>
      'Dieser Link zum Zurücksetzen des Passworts ist ungültig, abgelaufen oder wurde bereits verwendet. Bitte fordere einen neuen an.';

  @override
  String get passwordMinLengthReset =>
      'Das Passwort muss mindestens 8 Zeichen lang sein';

  @override
  String get confirmNewPasswordLabel => 'Neues Passwort bestätigen';

  @override
  String get passwordsDoNotMatchReset => 'Passwörter stimmen nicht überein';

  @override
  String forgotPasswordFailed(String error) {
    return 'Reset-Link konnte nicht gesendet werden: $error';
  }

  @override
  String passwordResetFailed(String error) {
    return 'Passwort zurücksetzen fehlgeschlagen: $error';
  }

  @override
  String get passwordResetTokenExpired =>
      'Der Link zum Zurücksetzen des Passworts ist abgelaufen. Bitte fordere einen neuen an.';

  @override
  String get usernameLabel => 'Benutzername';

  @override
  String get passwordLabel => 'Passwort';

  @override
  String get usernameRequired => 'Bitte gib deinen Benutzernamen ein';

  @override
  String get passwordRequired => 'Bitte gib dein Passwort ein';

  @override
  String get createAccount => 'Konto erstellen';

  @override
  String get createAccountSubtitle => 'Erstelle ein Konto, um loszulegen';

  @override
  String get usernameRequiredAlt => 'Bitte gib einen Benutzernamen ein';

  @override
  String get usernameMinLength =>
      'Der Benutzername muss mindestens 3 Zeichen lang sein';

  @override
  String get emailLabel => 'E-Mail';

  @override
  String get emailRequired => 'Bitte gib deine E-Mail-Adresse ein';

  @override
  String get emailInvalid => 'Bitte gib eine gültige E-Mail-Adresse ein';

  @override
  String get birthYearLabel => 'Geburtsjahr';

  @override
  String get genderLabel => 'Geschlecht';

  @override
  String get genderMale => 'Männlich';

  @override
  String get genderFemale => 'Weiblich';

  @override
  String get genderDiverse => 'Divers';

  @override
  String get nationalityLabel => 'Staatsangehörigkeit';

  @override
  String get nationalityOtherLabel => 'Bitte näher angeben';

  @override
  String get regionLabel => 'Region';

  @override
  String get loadingLabel => 'Wird geladen...';

  @override
  String get selectNationalityFirst =>
      'Bitte zuerst eine Staatsangehörigkeit wählen';

  @override
  String get noRegionsAvailable =>
      'Keine Regionen für diese Staatsangehörigkeit verfügbar';

  @override
  String get passwordRequiredAlt => 'Bitte gib ein Passwort ein';

  @override
  String get passwordMinLength =>
      'Das Passwort muss mindestens 6 Zeichen lang sein';

  @override
  String get confirmPasswordLabel => 'Passwort bestätigen';

  @override
  String get confirmPasswordRequired => 'Bitte bestätige dein Passwort';

  @override
  String get passwordsDoNotMatch => 'Passwörter stimmen nicht überein';

  @override
  String get registrationSuccess =>
      'Registrierung erfolgreich! Bitte melde dich an.';

  @override
  String get haveAccountPrompt => 'Bereits ein Konto? ';

  @override
  String get filterDialogTitle => 'Nach Kategorie filtern';

  @override
  String get noCategoriesAvailable => 'Keine Kategorien verfügbar';

  @override
  String get clear => 'Zurücksetzen';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get apply => 'Übernehmen';

  @override
  String get searchDialogTitle => 'Fragen suchen';

  @override
  String get searchHint => 'Suchbegriff eingeben...';

  @override
  String get ok => 'OK';

  @override
  String get searchFieldHint => 'Fragen suchen...';

  @override
  String get searchTooltip => 'Fragen suchen';

  @override
  String get filterTooltip => 'Nach Kategorie filtern';

  @override
  String get reload => 'Neu laden';

  @override
  String searchResultsFor(String query) {
    return 'Suchergebnisse für \"$query\"';
  }

  @override
  String get searchMinChars => 'Gib mindestens drei Zeichen ein';

  @override
  String categoryFallback(int id) {
    return 'Kategorie $id';
  }

  @override
  String get allQuestionsLoaded => 'Alle Fragen geladen';

  @override
  String get noQuestionsFound => 'Keine Fragen gefunden';

  @override
  String get retry => 'Erneut versuchen';

  @override
  String get serverError => 'Server hat einen Fehler zurückgegeben';

  @override
  String connectionError(String error) {
    return 'Verbindung fehlgeschlagen: $error';
  }

  @override
  String get questionDetailsTitle => 'Fragendetails';

  @override
  String get questionLabel => 'Frage';

  @override
  String get possibleAnswers => 'Mögliche Antworten';

  @override
  String get noAnswersAvailable => 'Keine Antworten für diese Frage verfügbar.';

  @override
  String get statistics => 'Statistik';

  @override
  String get questionNotFound => 'Frage nicht gefunden';

  @override
  String get statsNotAvailable => 'Statistik nicht verfügbar';

  @override
  String get statsInsufficientData =>
      'Noch nicht genug Antworten für eine Statistik';

  @override
  String get specialCategoryConsentTitle => 'Sensitive question';

  @override
  String specialCategoryConsentBody(String category) {
    return 'Diese Frage gehört zur sensiblen Kategorie „$category“. Zum Beantworten ist deine ausdrückliche Einwilligung erforderlich; sie wird anonym zusammen mit deiner Antwort gespeichert.';
  }

  @override
  String get specialCategoryConsentAccept =>
      'Ich willige ein und möchte antworten';

  @override
  String get specialCategoryRacialOrEthnicOrigin => 'Ethnische Herkunft';

  @override
  String get specialCategoryPoliticalOpinion => 'Politische Meinung';

  @override
  String get specialCategoryReligiousOrPhilosophicalBelief =>
      'Religiöse oder philosophische Überzeugung';

  @override
  String get specialCategoryTradeUnionMembership =>
      'Gewerkschaftszugehörigkeit';

  @override
  String get specialCategoryGeneticData => 'Genetische Daten';

  @override
  String get specialCategoryBiometricData => 'Biometrische Daten';

  @override
  String get specialCategoryHealth => 'Gesundheit';

  @override
  String get specialCategorySexLifeOrOrientation =>
      'Sexualleben oder sexuelle Orientierung';

  @override
  String get specialCategoryCriminalConvictions =>
      'Straftaten oder Strafverfolgung';

  @override
  String get approvalSettingsTitle => 'Freigabe-Einstellungen';

  @override
  String get approvalMinAgeLabel => 'Mindestalter';

  @override
  String get specialCategoryLabel => 'Besondere Kategorie';

  @override
  String get specialCategoryNone => 'Keine besondere Kategorie';

  @override
  String get statsLoadFailed => 'Statistik konnte nicht geladen werden';

  @override
  String voteSubmitted(String answer) {
    return 'Stimme für \"$answer\" abgegeben!';
  }

  @override
  String errorWithMessage(String message) {
    return 'Fehler: $message';
  }

  @override
  String voteSubmitFailed(String error) {
    return 'Stimme konnte nicht abgegeben werden: $error';
  }

  @override
  String get alreadyAnswered => 'Du hast diese Frage bereits beantwortet';

  @override
  String get votesNoun => 'Stimmen';

  @override
  String get noVotesYet => 'Noch keine Stimmen';

  @override
  String totalVotes(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Stimmen gesamt',
      one: '$count Stimme gesamt',
      zero: 'Keine Stimmen',
    );
    return '$_temp0';
  }

  @override
  String votesCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Stimmen',
      one: '$count Stimme',
      zero: 'Keine Stimmen',
    );
    return '$_temp0';
  }

  @override
  String get viewBars => 'Balken';

  @override
  String get viewDonut => 'Donut';

  @override
  String get breakdownLabel => 'Aufschlüsselung';

  @override
  String get filterEveryone => 'Alle';

  @override
  String get addFilter => 'Filter hinzufügen';

  @override
  String get statsFilterSheetTitle => 'Ergebnisse aufschlüsseln';

  @override
  String get statsFilterSheetHint =>
      'Beliebig viele Merkmale kombinieren. Segmente mit zu wenigen Antworten bleiben ausgeblendet.';

  @override
  String get removeFilterTooltip => 'Filter entfernen';

  @override
  String get dimensionAge => 'Alter';

  @override
  String get dimensionNationality => 'Nationalität';

  @override
  String get dimensionRegion => 'Region';

  @override
  String get ageUnder18 => 'Unter 18';

  @override
  String get age18To29 => '18–29';

  @override
  String get age30To39 => '30–39';

  @override
  String get age40To49 => '40–49';

  @override
  String get age50To59 => '50–59';

  @override
  String get age60Plus => '60 oder älter';

  @override
  String get nationalityGermany => 'Deutschland';

  @override
  String get nationalityAustria => 'Österreich';

  @override
  String get nationalitySwitzerland => 'Schweiz';

  @override
  String get nationalityFrance => 'Frankreich';

  @override
  String get nationalityItaly => 'Italien';

  @override
  String get nationalityNetherlands => 'Niederlande';

  @override
  String get nationalityPoland => 'Polen';

  @override
  String get nationalitySpain => 'Spanien';

  @override
  String get nationalityTurkey => 'Türkei';

  @override
  String get nationalityUkraine => 'Ukraine';

  @override
  String get uncategorized => 'Ohne Kategorie';

  @override
  String get userInitialFallback => 'B';

  @override
  String get userMenuName => 'Benutzer';

  @override
  String get logout => 'Abmelden';

  @override
  String loginFailed(String error) {
    return 'Anmeldung fehlgeschlagen: $error';
  }

  @override
  String registrationFailed(String error) {
    return 'Registrierung fehlgeschlagen: $error';
  }

  @override
  String requestFailedStatus(String status) {
    return 'Anfrage fehlgeschlagen mit Status $status';
  }

  @override
  String get login => 'Anmelden';

  @override
  String get changeUser => 'Benutzer wechseln';

  @override
  String get changeUserConfirm =>
      'Möchten Sie zu einem anderen Benutzerkonto wechseln?';

  @override
  String get no => 'Nein';

  @override
  String get deleteAccount => 'Konto löschen';

  @override
  String get deleteAccountConfirm =>
      'Möchten Sie wirklich Ihr Konto löschen? Diese Aktion kann nicht rückgängig gemacht werden.';

  @override
  String get deleteAccountCancel => 'Abbrechen';

  @override
  String get deleteAccountPositive => 'Löschen';

  @override
  String get userDetails => 'Meine Daten';

  @override
  String get userDetailsTitle => 'Kontodetails';

  @override
  String get close => 'Schließen';

  @override
  String get notAvailable => 'Nicht verfügbar';

  @override
  String get edit => 'Bearbeiten';

  @override
  String get save => 'Speichern';

  @override
  String get editUserDetailsTitle => 'Kontodetails bearbeiten';

  @override
  String get newPasswordLabel => 'Neues Passwort';

  @override
  String get newPasswordConfirmLabel => 'Neues Passwort bestätigen';

  @override
  String get passwordChangeMinLength =>
      'Das Passwort muss mindestens 8 Zeichen lang sein';

  @override
  String get profileUpdateSuccess => 'Profil erfolgreich aktualisiert';

  @override
  String profileUpdateFailed(String error) {
    return 'Profil konnte nicht aktualisiert werden: $error';
  }

  @override
  String deleteAccountFailed(String error) {
    return 'Konto konnte nicht gelöscht werden: $error';
  }

  @override
  String get isAdminLabel => 'Administrator';

  @override
  String get yes => 'Ja';

  @override
  String get questions => 'Fragen';

  @override
  String get mySubmissions => 'Meine Einreichungen';

  @override
  String get mySubmissionsEmpty => 'Du hast noch keine Fragen eingereicht.';

  @override
  String get createQuestion => 'Neue Frage';

  @override
  String get newQuestionTitle => 'Frage einreichen';

  @override
  String get questionTextLabel => 'Frage';

  @override
  String get questionTextHint => 'Gib deine Frage ein...';

  @override
  String get categoryLabel => 'Kategorie';

  @override
  String get languageLabel => 'Sprache';

  @override
  String get minAgeLabel => 'Mindestalter (optional)';

  @override
  String get minAgeHint => '0 = alle';

  @override
  String get submit => 'Einreichen';

  @override
  String get submissionCreated => 'Frage zur Prüfung eingereicht';

  @override
  String get submissionFailed => 'Frage konnte nicht eingereicht werden';

  @override
  String get submissionLoadFailed =>
      'Deine Einreichungen konnten nicht geladen werden';

  @override
  String get submissionPending => 'Ausstehend';

  @override
  String get submissionApproved => 'Freigegeben';

  @override
  String get submissionRejected => 'Abgelehnt';

  @override
  String get requiredField => 'Dieses Feld ist erforderlich';

  @override
  String submittedOn(String date) {
    return 'Eingereicht am $date';
  }

  @override
  String get answerOptionsLabel => 'Antwortmöglichkeiten';

  @override
  String answerOptionLabel(int number) {
    return 'Antwortmöglichkeit $number';
  }

  @override
  String get answerOptionHint => 'Antwortmöglichkeit eingeben';

  @override
  String get addAnswerOption => 'Antwortmöglichkeit hinzufügen';

  @override
  String get removeAnswerOption => 'Antwortmöglichkeit entfernen';

  @override
  String get atLeastOneAnswerOption =>
      'Bitte gib mindestens eine Antwortmöglichkeit an';

  @override
  String maxAnswerOptionsReached(int max) {
    return 'Du kannst höchstens $max Antwortmöglichkeiten hinzufügen';
  }

  @override
  String get adminReviewQueue => 'Freigabewarteschlange';

  @override
  String get adminSubmissionsEmpty => 'Es gibt keine Einreichungen zu prüfen.';

  @override
  String get adminSubmissionsLoadFailed =>
      'Einreichungen konnten nicht geladen werden';

  @override
  String get approve => 'Freigeben';

  @override
  String get reject => 'Ablehnen';

  @override
  String submittedBy(String id) {
    return 'Eingereicht von Benutzer $id';
  }

  @override
  String reviewedBy(String id) {
    return 'Geprüft von Benutzer $id';
  }

  @override
  String get submissionDetailsTitle => 'Details der Einreichung';

  @override
  String get submissionApprovedMessage => 'Frage freigegeben';

  @override
  String get submissionRejectedMessage => 'Frage abgelehnt';

  @override
  String get approveFailed => 'Frage konnte nicht freigegeben werden';

  @override
  String get rejectFailed => 'Frage konnte nicht abgelehnt werden';

  @override
  String get deleteQuestion => 'Frage löschen';

  @override
  String get deleteQuestionConfirm =>
      'Möchten Sie diese Frage wirklich löschen? Diese Aktion kann nicht rückgängig gemacht werden.';

  @override
  String get deleteQuestionSuccess => 'Frage erfolgreich gelöscht';

  @override
  String get deleteQuestionFailed => 'Frage konnte nicht gelöscht werden';

  @override
  String get changeQuestion => 'Frage ändern';

  @override
  String get changeQuestionTitle => 'Frage-Text ändern';

  @override
  String get currentQuestionText => 'Aktueller Frage-Text';

  @override
  String get newQuestionText => 'Neuer Frage-Text';

  @override
  String get changeQuestionSuccess => 'Frage-Text erfolgreich geändert';

  @override
  String get changeQuestionFailed => 'Frage-Text konnte nicht geändert werden';

  @override
  String get submissionAlreadyReviewed =>
      'Diese Einreichung wurde bereits geprüft.';

  @override
  String get answersNotVisible =>
      'Die eingereichten Antworten sind für die Prüfung nicht verfügbar.';

  @override
  String get adminUsers => 'Benutzer';

  @override
  String get adminUsersEmpty => 'Es gibt keine Benutzer anzuzeigen.';

  @override
  String get adminUsersLoadFailed => 'Benutzer konnten nicht geladen werden';

  @override
  String adminUserId(String id) {
    return 'Benutzer $id';
  }

  @override
  String get adminUserDetailsTitle => 'Benutzerdetails';

  @override
  String get adminUserDetailsLoadFailed =>
      'Benutzerdetails konnten nicht geladen werden';

  @override
  String get adminUserActiveStatus => 'Aktiv';

  @override
  String get adminUserInactiveStatus => 'Inaktiv';

  @override
  String get activateUser => 'Aktivieren';

  @override
  String get deactivateUser => 'Deaktivieren';

  @override
  String get activateUserSuccess => 'Benutzer aktiviert';

  @override
  String get deactivateUserSuccess => 'Benutzer deaktiviert';

  @override
  String get activateUserFailed => 'Aktivieren fehlgeschlagen';

  @override
  String get deactivateUserFailed => 'Deaktivieren fehlgeschlagen';

  @override
  String get configuration => 'Konfiguration';

  @override
  String get appearance => 'Erscheinungsbild';

  @override
  String get themeColor => 'Themenfarbe';

  @override
  String get darkView => 'Dunkle Ansicht';

  @override
  String get themeModeSystem => 'System';

  @override
  String get themeModeLight => 'Hell';

  @override
  String get themeModeDark => 'Dunkel';

  @override
  String get language => 'Sprache';

  @override
  String get languageSystem => 'Systemsprache';

  @override
  String get languageEnglish => 'Englisch';

  @override
  String get languageGerman => 'Deutsch';

  @override
  String get colorDeepPurple => 'Tiefes Lila';

  @override
  String get colorBlue => 'Blau';

  @override
  String get colorTeal => 'Blaugrün';

  @override
  String get colorGreen => 'Grün';

  @override
  String get colorOrange => 'Orange';

  @override
  String get colorRed => 'Rot';

  @override
  String get colorPink => 'Pink';

  @override
  String get colorCyan => 'Cyan';

  @override
  String get colorIndigo => 'Indigo';

  @override
  String get colorAmber => 'Bernstein';
}
