// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get me => 'Me';

  @override
  String get noOfQuizPlayed => 'No of Quiz Played';

  @override
  String get noOfQuizCreated => 'No of Quiz Created';

  @override
  String get changeLanguage => 'Change Language';

  @override
  String get performanceAnalysis => 'Performance Analysis';

  @override
  String get accuracyBasedOnSubject => 'Accuracy Based On Subject';

  @override
  String get logout => 'Logout';

  @override
  String get discover => 'Discover';

  @override
  String get myQuizzes => 'My Quizzes';

  @override
  String get history => 'History';

  @override
  String get allSubjects => 'All Subjects';

  @override
  String get allGrades => 'All Grades';

  @override
  String get searchQuizzes => 'Search quizzes...';

  @override
  String get noQuizzesFound => 'No quizzes found.';

  @override
  String get createQuiz => 'Create Quiz';

  @override
  String get youHaventCreatedAnyQuizzesYet =>
      'You haven\'t created any quizzes yet.';

  @override
  String get public => 'Public';

  @override
  String get private => 'Private';

  @override
  String get edit => 'Edit';

  @override
  String get delete => 'Delete';

  @override
  String get deleteQuiz => 'Delete Quiz';

  @override
  String get areYouSureYouWantToDeleteThisQuiz =>
      'Are you sure you want to delete this quiz?';

  @override
  String get cancel => 'Cancel';

  @override
  String get editQuiz => 'Edit Quiz';

  @override
  String get quizTitle => 'Quiz Title';

  @override
  String get quizDescription => 'Quiz Description';

  @override
  String get makeThisQuizPublic => 'Make this quiz public';

  @override
  String get questions => 'Questions';

  @override
  String get addQuestion => 'Add Question';

  @override
  String get saveQuiz => 'Save Quiz';

  @override
  String get pleaseEnterATitle => 'Please enter a title';

  @override
  String get pleaseEnterADescription => 'Please enter a description';

  @override
  String get createQuestion => 'Create Question';

  @override
  String get editQuestion => 'Edit Question';

  @override
  String get questionTitle => 'Question Title';

  @override
  String get pleaseEnterAQuestion => 'Please enter a question';

  @override
  String get options => 'Options';

  @override
  String optionNumber(Object number) {
    return 'Option $number';
  }

  @override
  String get correctAnswer => 'Correct Answer';

  @override
  String get pleaseSelectACorrectAnswer => 'Please select a correct answer';

  @override
  String get saveQuestion => 'Save Question';

  @override
  String get noQuizHistoryFound => 'No quiz history found.';

  @override
  String get score => 'Score';

  @override
  String get date => 'Date';

  @override
  String get quizDetails => 'Quiz Details';

  @override
  String get startQuiz => 'Start Quiz';

  @override
  String questionXofY(Object current, Object total) {
    return 'Question $current of $total';
  }

  @override
  String get next => 'Next';

  @override
  String get submit => 'Submit';

  @override
  String get review => 'Review';

  @override
  String get yourScore => 'Your Score';

  @override
  String get correctAnswerLabel => 'Correct Answer';

  @override
  String get yourAnswerLabel => 'Your Answer';

  @override
  String get lastAttemptSummary => 'Last Attempt Summary';

  @override
  String get playAgain => 'Play Again!';

  @override
  String get detailedAnalysis => 'Detailed Analysis';

  @override
  String get reviewAnswers => 'Review Answers';

  @override
  String get maths => 'Maths';

  @override
  String get science => 'Science';

  @override
  String get computing => 'Computing';

  @override
  String get historySubject => 'History';

  @override
  String get art => 'Art';

  @override
  String get geography => 'Geography';

  @override
  String get other => 'Other';

  @override
  String get kindergarten => 'Kindergarten';

  @override
  String get university => 'University';

  @override
  String grade(Object number) {
    return 'Grade $number';
  }

  @override
  String get searchQuizzesLabel => 'Search quizzes';

  @override
  String get gradeLabel => 'Grade';

  @override
  String get subjectLabel => 'Subject';

  @override
  String get noOfQuestionsLabel => 'No. of Questions';

  @override
  String get any => 'Any';

  @override
  String get reset => 'Reset';

  @override
  String get clickToAddQuizPicture => 'Click to\nAdd Quiz\nPicture';

  @override
  String get saveAndContinueToQuestions => 'Save & Continue to Questions';

  @override
  String get editQuestions => 'Edit Questions';

  @override
  String get addOption => 'Add Option';

  @override
  String get selectRadioButtonToMarkCorrect =>
      'Select the radio button to mark the correct answer.';

  @override
  String get durationSeconds => 'Duration (seconds)';

  @override
  String get required => 'Required';

  @override
  String get mustBeANumber => 'Must be a number';

  @override
  String get questionCannotBeEmpty => 'Question cannot be empty';

  @override
  String get optionCannotBeEmpty => 'Option cannot be empty';

  @override
  String get performanceGrowth => 'Performance Growth';

  @override
  String get unattemptedTimeout => 'Unattempted (Timeout)';

  @override
  String get correct => 'Correct';

  @override
  String get wrong => 'Wrong';

  @override
  String get avgTime => 'Avg Time';

  @override
  String get timeout => 'Timeout!';

  @override
  String get tryAgain => 'Try Again!';

  @override
  String get goodJob => 'Good Job!';

  @override
  String get outstanding => 'Outstanding!';

  @override
  String get attemptNotFound => 'Attempt not found';

  @override
  String get pausedTitle => 'Paused';

  @override
  String get resume => 'Resume';

  @override
  String get exitQuizConfirmTitle => 'Exit Quiz?';

  @override
  String get exitQuizConfirmDesc =>
      'Are you sure you want to exit? Your progress will be lost.';

  @override
  String get discardChangesConfirmTitle => 'Discard Changes?';

  @override
  String get discardChangesConfirmDesc =>
      'Are you sure you want to discard your changes?';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get discard => 'Discard';

  @override
  String errorOccurred(Object error) {
    return 'Error: $error';
  }

  @override
  String failedToSave(Object error) {
    return 'Failed to save: $error';
  }

  @override
  String errorPickingImage(Object error) {
    return 'Error picking image: $error';
  }

  @override
  String unexpectedError(Object error) {
    return 'Unexpected error: $error';
  }

  @override
  String get atLeastTwoOptions =>
      'At least two options are required per question';

  @override
  String get atLeastTwoNonEmptyOptions =>
      'At least two non-empty options are required per question';

  @override
  String get cannotDeleteLastQuestion =>
      'Cannot delete the last question. Modify it instead.';

  @override
  String fixErrorsInQuestion(Object index) {
    return 'Please fix errors in Question $index';
  }

  @override
  String get addAtLeastOneQuestion => 'Please add at least one question';

  @override
  String get quizSavedSuccessfully => 'Quiz saved successfully!';

  @override
  String get pleaseEnterEmailAndPassword =>
      'Please enter an email and password';

  @override
  String get generateWithAI => 'Generate with AI';

  @override
  String get advancedOptions => 'Advanced Options';

  @override
  String get numberOfQuestions => 'Number of Questions';

  @override
  String get generating => 'Generating...';

  @override
  String get quizCreatedSuccessfully => 'Quiz created successfully!';

  @override
  String get apiKeyRequired => 'API Key Required';

  @override
  String get enterApiKey => 'Please enter your Gemini API Key';

  @override
  String get apiKeySaved => 'API Key saved successfully!';

  @override
  String get autoGenerateDescription =>
      'Let Gemini AI build your quiz in seconds!';

  @override
  String get generate => 'Generate';

  @override
  String get quizGeneratedSuccessfully => 'Quiz generated successfully!';

  @override
  String get editProfile => 'Edit Profile';

  @override
  String get displayName => 'Display Name';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get changePassword => 'Change Password (optional)';

  @override
  String get save => 'Save';

  @override
  String get updateSuccessful => 'Update successful!';

  @override
  String get all => 'All';

  @override
  String get endQuiz => 'End Quiz';

  @override
  String get deleteAccount => 'Delete Account';

  @override
  String get deleteAccountConfirmTitle => 'Delete Account?';

  @override
  String get deleteAccountConfirmDesc =>
      'This action is permanent. All your quizzes and history will be deleted.';

  @override
  String get notification => 'Notification';

  @override
  String get verificationRequired => 'Verification Required';

  @override
  String verificationSentDesc(Object email) {
    return 'A confirmation link has been sent to $email. Your email will be updated once you click the link.';
  }

  @override
  String get leaveBlankToKeepCurrent => 'Leave blank to keep current password';

  @override
  String correctCount(Object count) {
    return '$count Correct';
  }

  @override
  String get gallery => 'Gallery';

  @override
  String get camera => 'Camera';
}
