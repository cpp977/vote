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
  String get viewGender => 'Geschlecht';

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
  String get isAdminLabel => 'Administrator';

  @override
  String get yes => 'Ja';
}
