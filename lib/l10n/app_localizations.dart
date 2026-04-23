import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ms.dart';
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
    Locale('en'),
    Locale('ms'),
    Locale('zh'),
  ];

  /// No description provided for @me.
  ///
  /// In en, this message translates to:
  /// **'Me'**
  String get me;

  /// No description provided for @noOfQuizPlayed.
  ///
  /// In en, this message translates to:
  /// **'No of Quiz Played'**
  String get noOfQuizPlayed;

  /// No description provided for @noOfQuizCreated.
  ///
  /// In en, this message translates to:
  /// **'No of Quiz Created'**
  String get noOfQuizCreated;

  /// No description provided for @changeLanguage.
  ///
  /// In en, this message translates to:
  /// **'Change Language'**
  String get changeLanguage;

  /// No description provided for @performanceAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Performance Analysis'**
  String get performanceAnalysis;

  /// No description provided for @accuracyBasedOnSubject.
  ///
  /// In en, this message translates to:
  /// **'Accuracy Based On Subject'**
  String get accuracyBasedOnSubject;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @discover.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get discover;

  /// No description provided for @myQuizzes.
  ///
  /// In en, this message translates to:
  /// **'My Quizzes'**
  String get myQuizzes;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @allSubjects.
  ///
  /// In en, this message translates to:
  /// **'All Subjects'**
  String get allSubjects;

  /// No description provided for @allGrades.
  ///
  /// In en, this message translates to:
  /// **'All Grades'**
  String get allGrades;

  /// No description provided for @searchQuizzes.
  ///
  /// In en, this message translates to:
  /// **'Search quizzes...'**
  String get searchQuizzes;

  /// No description provided for @noQuizzesFound.
  ///
  /// In en, this message translates to:
  /// **'No quizzes found.'**
  String get noQuizzesFound;

  /// No description provided for @createQuiz.
  ///
  /// In en, this message translates to:
  /// **'Create Quiz'**
  String get createQuiz;

  /// No description provided for @youHaventCreatedAnyQuizzesYet.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t created any quizzes yet.'**
  String get youHaventCreatedAnyQuizzesYet;

  /// No description provided for @public.
  ///
  /// In en, this message translates to:
  /// **'Public'**
  String get public;

  /// No description provided for @private.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get private;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deleteQuiz.
  ///
  /// In en, this message translates to:
  /// **'Delete Quiz'**
  String get deleteQuiz;

  /// No description provided for @areYouSureYouWantToDeleteThisQuiz.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this quiz?'**
  String get areYouSureYouWantToDeleteThisQuiz;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @editQuiz.
  ///
  /// In en, this message translates to:
  /// **'Edit Quiz'**
  String get editQuiz;

  /// No description provided for @quizTitle.
  ///
  /// In en, this message translates to:
  /// **'Quiz Title'**
  String get quizTitle;

  /// No description provided for @quizDescription.
  ///
  /// In en, this message translates to:
  /// **'Quiz Description'**
  String get quizDescription;

  /// No description provided for @makeThisQuizPublic.
  ///
  /// In en, this message translates to:
  /// **'Make this quiz public'**
  String get makeThisQuizPublic;

  /// No description provided for @questions.
  ///
  /// In en, this message translates to:
  /// **'Questions'**
  String get questions;

  /// No description provided for @addQuestion.
  ///
  /// In en, this message translates to:
  /// **'Add Question'**
  String get addQuestion;

  /// No description provided for @saveQuiz.
  ///
  /// In en, this message translates to:
  /// **'Save Quiz'**
  String get saveQuiz;

  /// No description provided for @pleaseEnterATitle.
  ///
  /// In en, this message translates to:
  /// **'Please enter a title'**
  String get pleaseEnterATitle;

  /// No description provided for @pleaseEnterADescription.
  ///
  /// In en, this message translates to:
  /// **'Please enter a description'**
  String get pleaseEnterADescription;

  /// No description provided for @createQuestion.
  ///
  /// In en, this message translates to:
  /// **'Create Question'**
  String get createQuestion;

  /// No description provided for @editQuestion.
  ///
  /// In en, this message translates to:
  /// **'Edit Question'**
  String get editQuestion;

  /// No description provided for @questionTitle.
  ///
  /// In en, this message translates to:
  /// **'Question Title'**
  String get questionTitle;

  /// No description provided for @pleaseEnterAQuestion.
  ///
  /// In en, this message translates to:
  /// **'Please enter a question'**
  String get pleaseEnterAQuestion;

  /// No description provided for @options.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get options;

  /// No description provided for @optionNumber.
  ///
  /// In en, this message translates to:
  /// **'Option {number}'**
  String optionNumber(Object number);

  /// No description provided for @correctAnswer.
  ///
  /// In en, this message translates to:
  /// **'Correct Answer'**
  String get correctAnswer;

  /// No description provided for @pleaseSelectACorrectAnswer.
  ///
  /// In en, this message translates to:
  /// **'Please select a correct answer'**
  String get pleaseSelectACorrectAnswer;

  /// No description provided for @saveQuestion.
  ///
  /// In en, this message translates to:
  /// **'Save Question'**
  String get saveQuestion;

  /// No description provided for @noQuizHistoryFound.
  ///
  /// In en, this message translates to:
  /// **'No quiz history found.'**
  String get noQuizHistoryFound;

  /// No description provided for @score.
  ///
  /// In en, this message translates to:
  /// **'Score'**
  String get score;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @quizDetails.
  ///
  /// In en, this message translates to:
  /// **'Quiz Details'**
  String get quizDetails;

  /// No description provided for @startQuiz.
  ///
  /// In en, this message translates to:
  /// **'Start Quiz'**
  String get startQuiz;

  /// No description provided for @questionXofY.
  ///
  /// In en, this message translates to:
  /// **'Question {current} of {total}'**
  String questionXofY(Object current, Object total);

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @review.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get review;

  /// No description provided for @yourScore.
  ///
  /// In en, this message translates to:
  /// **'Your Score'**
  String get yourScore;

  /// No description provided for @correctAnswerLabel.
  ///
  /// In en, this message translates to:
  /// **'Correct Answer'**
  String get correctAnswerLabel;

  /// No description provided for @yourAnswerLabel.
  ///
  /// In en, this message translates to:
  /// **'Your Answer'**
  String get yourAnswerLabel;

  /// No description provided for @lastAttemptSummary.
  ///
  /// In en, this message translates to:
  /// **'Last Attempt Summary'**
  String get lastAttemptSummary;

  /// No description provided for @playAgain.
  ///
  /// In en, this message translates to:
  /// **'Play Again!'**
  String get playAgain;

  /// No description provided for @detailedAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Detailed Analysis'**
  String get detailedAnalysis;

  /// No description provided for @reviewAnswers.
  ///
  /// In en, this message translates to:
  /// **'Review Answers'**
  String get reviewAnswers;

  /// No description provided for @maths.
  ///
  /// In en, this message translates to:
  /// **'Maths'**
  String get maths;

  /// No description provided for @science.
  ///
  /// In en, this message translates to:
  /// **'Science'**
  String get science;

  /// No description provided for @computing.
  ///
  /// In en, this message translates to:
  /// **'Computing'**
  String get computing;

  /// No description provided for @historySubject.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get historySubject;

  /// No description provided for @art.
  ///
  /// In en, this message translates to:
  /// **'Art'**
  String get art;

  /// No description provided for @geography.
  ///
  /// In en, this message translates to:
  /// **'Geography'**
  String get geography;

  /// No description provided for @other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get other;

  /// No description provided for @kindergarten.
  ///
  /// In en, this message translates to:
  /// **'Kindergarten'**
  String get kindergarten;

  /// No description provided for @university.
  ///
  /// In en, this message translates to:
  /// **'University'**
  String get university;

  /// No description provided for @grade.
  ///
  /// In en, this message translates to:
  /// **'Grade {number}'**
  String grade(Object number);

  /// No description provided for @searchQuizzesLabel.
  ///
  /// In en, this message translates to:
  /// **'Search quizzes'**
  String get searchQuizzesLabel;

  /// No description provided for @gradeLabel.
  ///
  /// In en, this message translates to:
  /// **'Grade'**
  String get gradeLabel;

  /// No description provided for @subjectLabel.
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get subjectLabel;

  /// No description provided for @noOfQuestionsLabel.
  ///
  /// In en, this message translates to:
  /// **'No. of Questions'**
  String get noOfQuestionsLabel;

  /// No description provided for @any.
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get any;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @clickToAddQuizPicture.
  ///
  /// In en, this message translates to:
  /// **'Click to\nAdd Quiz\nPicture'**
  String get clickToAddQuizPicture;

  /// No description provided for @saveAndContinueToQuestions.
  ///
  /// In en, this message translates to:
  /// **'Save & Continue to Questions'**
  String get saveAndContinueToQuestions;

  /// No description provided for @editQuestions.
  ///
  /// In en, this message translates to:
  /// **'Edit Questions'**
  String get editQuestions;

  /// No description provided for @addOption.
  ///
  /// In en, this message translates to:
  /// **'Add Option'**
  String get addOption;

  /// No description provided for @selectRadioButtonToMarkCorrect.
  ///
  /// In en, this message translates to:
  /// **'Select the radio button to mark the correct answer.'**
  String get selectRadioButtonToMarkCorrect;

  /// No description provided for @durationSeconds.
  ///
  /// In en, this message translates to:
  /// **'Duration (seconds)'**
  String get durationSeconds;

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// No description provided for @mustBeANumber.
  ///
  /// In en, this message translates to:
  /// **'Must be a number'**
  String get mustBeANumber;

  /// No description provided for @questionCannotBeEmpty.
  ///
  /// In en, this message translates to:
  /// **'Question cannot be empty'**
  String get questionCannotBeEmpty;

  /// No description provided for @optionCannotBeEmpty.
  ///
  /// In en, this message translates to:
  /// **'Option cannot be empty'**
  String get optionCannotBeEmpty;

  /// No description provided for @performanceGrowth.
  ///
  /// In en, this message translates to:
  /// **'Performance Growth'**
  String get performanceGrowth;

  /// No description provided for @unattemptedTimeout.
  ///
  /// In en, this message translates to:
  /// **'Unattempted (Timeout)'**
  String get unattemptedTimeout;

  /// No description provided for @correct.
  ///
  /// In en, this message translates to:
  /// **'Correct'**
  String get correct;

  /// No description provided for @wrong.
  ///
  /// In en, this message translates to:
  /// **'Wrong'**
  String get wrong;

  /// No description provided for @avgTime.
  ///
  /// In en, this message translates to:
  /// **'Avg Time'**
  String get avgTime;

  /// No description provided for @timeout.
  ///
  /// In en, this message translates to:
  /// **'Timeout!'**
  String get timeout;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again!'**
  String get tryAgain;

  /// No description provided for @goodJob.
  ///
  /// In en, this message translates to:
  /// **'Good Job!'**
  String get goodJob;

  /// No description provided for @outstanding.
  ///
  /// In en, this message translates to:
  /// **'Outstanding!'**
  String get outstanding;

  /// No description provided for @attemptNotFound.
  ///
  /// In en, this message translates to:
  /// **'Attempt not found'**
  String get attemptNotFound;

  /// No description provided for @pausedTitle.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get pausedTitle;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @exitQuizConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Exit Quiz?'**
  String get exitQuizConfirmTitle;

  /// No description provided for @exitQuizConfirmDesc.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to exit? Your progress will be lost.'**
  String get exitQuizConfirmDesc;

  /// No description provided for @discardChangesConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard Changes?'**
  String get discardChangesConfirmTitle;

  /// No description provided for @discardChangesConfirmDesc.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to discard your changes?'**
  String get discardChangesConfirmDesc;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @errorOccurred.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String errorOccurred(Object error);

  /// No description provided for @failedToSave.
  ///
  /// In en, this message translates to:
  /// **'Failed to save: {error}'**
  String failedToSave(Object error);

  /// No description provided for @errorPickingImage.
  ///
  /// In en, this message translates to:
  /// **'Error picking image: {error}'**
  String errorPickingImage(Object error);

  /// No description provided for @unexpectedError.
  ///
  /// In en, this message translates to:
  /// **'Unexpected error: {error}'**
  String unexpectedError(Object error);

  /// No description provided for @atLeastTwoOptions.
  ///
  /// In en, this message translates to:
  /// **'At least two options are required per question'**
  String get atLeastTwoOptions;

  /// No description provided for @atLeastTwoNonEmptyOptions.
  ///
  /// In en, this message translates to:
  /// **'At least two non-empty options are required per question'**
  String get atLeastTwoNonEmptyOptions;

  /// No description provided for @cannotDeleteLastQuestion.
  ///
  /// In en, this message translates to:
  /// **'Cannot delete the last question. Modify it instead.'**
  String get cannotDeleteLastQuestion;

  /// No description provided for @fixErrorsInQuestion.
  ///
  /// In en, this message translates to:
  /// **'Please fix errors in Question {index}'**
  String fixErrorsInQuestion(Object index);

  /// No description provided for @addAtLeastOneQuestion.
  ///
  /// In en, this message translates to:
  /// **'Please add at least one question'**
  String get addAtLeastOneQuestion;

  /// No description provided for @quizSavedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Quiz saved successfully!'**
  String get quizSavedSuccessfully;

  /// No description provided for @pleaseEnterEmailAndPassword.
  ///
  /// In en, this message translates to:
  /// **'Please enter an email and password'**
  String get pleaseEnterEmailAndPassword;

  /// No description provided for @generateWithAI.
  ///
  /// In en, this message translates to:
  /// **'Generate with AI'**
  String get generateWithAI;

  /// No description provided for @advancedOptions.
  ///
  /// In en, this message translates to:
  /// **'Advanced Options'**
  String get advancedOptions;

  /// No description provided for @numberOfQuestions.
  ///
  /// In en, this message translates to:
  /// **'Number of Questions'**
  String get numberOfQuestions;

  /// No description provided for @generating.
  ///
  /// In en, this message translates to:
  /// **'Generating...'**
  String get generating;

  /// No description provided for @quizCreatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Quiz created successfully!'**
  String get quizCreatedSuccessfully;

  /// No description provided for @apiKeyRequired.
  ///
  /// In en, this message translates to:
  /// **'API Key Required'**
  String get apiKeyRequired;

  /// No description provided for @enterApiKey.
  ///
  /// In en, this message translates to:
  /// **'Please enter your Gemini API Key'**
  String get enterApiKey;

  /// No description provided for @apiKeySaved.
  ///
  /// In en, this message translates to:
  /// **'API Key saved successfully!'**
  String get apiKeySaved;

  /// No description provided for @autoGenerateDescription.
  ///
  /// In en, this message translates to:
  /// **'Let Gemini AI build your quiz in seconds!'**
  String get autoGenerateDescription;

  /// No description provided for @generate.
  ///
  /// In en, this message translates to:
  /// **'Generate'**
  String get generate;

  /// No description provided for @quizGeneratedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Quiz generated successfully!'**
  String get quizGeneratedSuccessfully;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// No description provided for @displayName.
  ///
  /// In en, this message translates to:
  /// **'Display Name'**
  String get displayName;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change Password (optional)'**
  String get changePassword;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @updateSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Update successful!'**
  String get updateSuccessful;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @endQuiz.
  ///
  /// In en, this message translates to:
  /// **'End Quiz'**
  String get endQuiz;
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
      <String>['en', 'ms', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ms':
      return AppLocalizationsMs();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
