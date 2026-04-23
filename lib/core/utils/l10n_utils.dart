import 'package:quiz_time/l10n/app_localizations.dart';

class L10nUtils {
  static String getLocalizedSubject(String? subject, AppLocalizations l10n) {
    if (subject == null) return '';
    switch (subject.toLowerCase()) {
      case 'maths':
        return l10n.maths;
      case 'science':
        return l10n.science;
      case 'computing':
        return l10n.computing;
      case 'history':
        return l10n.historySubject;
      case 'art':
        return l10n.art;
      case 'geography':
        return l10n.geography;
      case 'other':
        return l10n.other;
      default:
        return subject;
    }
  }

  static String getLocalizedGrade(String? grade, AppLocalizations l10n) {
    if (grade == null) return '';
    final g = grade.toLowerCase();
    if (g == 'kindergarten') return l10n.kindergarten;
    if (g == 'university') return l10n.university;
    
    final match = RegExp(r'Grade\s+(\d+)', caseSensitive: false).firstMatch(grade);
    if (match != null) {
      return l10n.grade(match.group(1)!);
    }
    
    return grade;
  }
}
