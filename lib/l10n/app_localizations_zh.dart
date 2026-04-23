// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get me => '我';

  @override
  String get noOfQuizPlayed => '已参与测验数';

  @override
  String get noOfQuizCreated => '已创建测验数';

  @override
  String get changeLanguage => '更改语言';

  @override
  String get performanceAnalysis => '表现分析';

  @override
  String get accuracyBasedOnSubject => '各科目准确率';

  @override
  String get logout => '登出';

  @override
  String get discover => '发现';

  @override
  String get myQuizzes => '我的测验';

  @override
  String get history => '历史记录';

  @override
  String get allSubjects => '所有科目';

  @override
  String get allGrades => '所有年级';

  @override
  String get searchQuizzes => '搜索测验...';

  @override
  String get noQuizzesFound => '未找到测验。';

  @override
  String get createQuiz => '创建测验';

  @override
  String get youHaventCreatedAnyQuizzesYet => '您尚未创建任何测验。';

  @override
  String get public => '公开';

  @override
  String get private => '私密';

  @override
  String get edit => '编辑';

  @override
  String get delete => '删除';

  @override
  String get deleteQuiz => '删除测验';

  @override
  String get areYouSureYouWantToDeleteThisQuiz => '您确定要删除此测验吗？';

  @override
  String get cancel => '取消';

  @override
  String get editQuiz => '编辑测验';

  @override
  String get quizTitle => '测验标题';

  @override
  String get quizDescription => '测验描述';

  @override
  String get makeThisQuizPublic => '将此测验设为公开';

  @override
  String get questions => '问题';

  @override
  String get addQuestion => '添加问题';

  @override
  String get saveQuiz => '保存测验';

  @override
  String get pleaseEnterATitle => '请输入标题';

  @override
  String get pleaseEnterADescription => '请输入描述';

  @override
  String get createQuestion => '创建问题';

  @override
  String get editQuestion => '编辑问题';

  @override
  String get questionTitle => '问题标题';

  @override
  String get pleaseEnterAQuestion => '请输入问题';

  @override
  String get options => '选项';

  @override
  String optionNumber(Object number) {
    return '选项 $number';
  }

  @override
  String get correctAnswer => '正确答案';

  @override
  String get pleaseSelectACorrectAnswer => '请选择正确答案';

  @override
  String get saveQuestion => '保存问题';

  @override
  String get noQuizHistoryFound => '未找到测验历史记录。';

  @override
  String get score => '得分';

  @override
  String get date => '日期';

  @override
  String get quizDetails => '测验详情';

  @override
  String get startQuiz => '开始测验';

  @override
  String questionXofY(Object current, Object total) {
    return '第 $current 题，共 $total 题';
  }

  @override
  String get next => '下一题';

  @override
  String get submit => '提交';

  @override
  String get review => '回顾';

  @override
  String get yourScore => '您的得分';

  @override
  String get correctAnswerLabel => '正确答案';

  @override
  String get yourAnswerLabel => '您的答案';

  @override
  String get lastAttemptSummary => '最后一次尝试摘要';

  @override
  String get playAgain => '再玩一次！';

  @override
  String get detailedAnalysis => '详细分析';

  @override
  String get reviewAnswers => '回顾答案';

  @override
  String get maths => '数学';

  @override
  String get science => '科学';

  @override
  String get computing => '计算机';

  @override
  String get historySubject => '历史';

  @override
  String get art => '艺术';

  @override
  String get geography => '地理';

  @override
  String get other => '其他';

  @override
  String get kindergarten => '幼儿园';

  @override
  String get university => '大学';

  @override
  String grade(Object number) {
    return '$number 年级';
  }

  @override
  String get searchQuizzesLabel => '搜索测验';

  @override
  String get gradeLabel => '年级';

  @override
  String get subjectLabel => '科目';

  @override
  String get noOfQuestionsLabel => '问题数量';

  @override
  String get any => '不限';

  @override
  String get reset => '重置';

  @override
  String get clickToAddQuizPicture => '点击添加\n测验图片';

  @override
  String get saveAndContinueToQuestions => '保存并继续添加问题';

  @override
  String get editQuestions => '编辑问题';

  @override
  String get addOption => '添加选项';

  @override
  String get selectRadioButtonToMarkCorrect => '选择单选按钮以标记正确答案。';

  @override
  String get durationSeconds => '持续时间（秒）';

  @override
  String get required => '必填';

  @override
  String get mustBeANumber => '必须是数字';

  @override
  String get questionCannotBeEmpty => '问题不能为空';

  @override
  String get optionCannotBeEmpty => '选项不能为空';

  @override
  String get performanceGrowth => '表现成长';

  @override
  String get unattemptedTimeout => '未尝试（超时）';

  @override
  String get correct => '正确';

  @override
  String get wrong => '错误';

  @override
  String get avgTime => '平均耗时';

  @override
  String get timeout => '超时！';

  @override
  String get tryAgain => '再试一次！';

  @override
  String get goodJob => '做得好！';

  @override
  String get outstanding => '太棒了！';

  @override
  String get attemptNotFound => '未找到尝试记录';

  @override
  String get pausedTitle => '已暂停';

  @override
  String get resume => '恢复';

  @override
  String get exitQuizConfirmTitle => '退出测验？';

  @override
  String get exitQuizConfirmDesc => '您确定要退出吗？您的进度将会丢失。';

  @override
  String get discardChangesConfirmTitle => '放弃更改？';

  @override
  String get discardChangesConfirmDesc => '您确定要放弃您的更改吗？';

  @override
  String get yes => '是';

  @override
  String get no => '否';

  @override
  String get discard => '放弃';

  @override
  String errorOccurred(Object error) {
    return '错误：$error';
  }

  @override
  String failedToSave(Object error) {
    return '保存失败：$error';
  }

  @override
  String errorPickingImage(Object error) {
    return '选择图像时出错：$error';
  }

  @override
  String unexpectedError(Object error) {
    return '意外错误：$error';
  }

  @override
  String get atLeastTwoOptions => '每个问题至少需要两个选项';

  @override
  String get atLeastTwoNonEmptyOptions => '每个问题至少需要两个非空选项';

  @override
  String get cannotDeleteLastQuestion => '无法删除最后一个问题，请修改它。';

  @override
  String fixErrorsInQuestion(Object index) {
    return '请修复问题 $index 中的错误';
  }

  @override
  String get addAtLeastOneQuestion => '请至少添加一个问题';

  @override
  String get quizSavedSuccessfully => '测验保存成功！';

  @override
  String get pleaseEnterEmailAndPassword => '请输入电子邮件和密码';

  @override
  String get generateWithAI => 'AI 自动生成';

  @override
  String get advancedOptions => '高级选项';

  @override
  String get numberOfQuestions => '问题数量';

  @override
  String get generating => '生成中...';

  @override
  String get quizCreatedSuccessfully => '测验创建成功！';

  @override
  String get apiKeyRequired => '需要 API 密钥';

  @override
  String get enterApiKey => '请输入您的 Gemini API 密钥';

  @override
  String get apiKeySaved => 'API 密钥保存成功！';

  @override
  String get autoGenerateDescription => '让 Gemini AI 在几秒钟内为您构建测验！';

  @override
  String get generate => '生成';

  @override
  String get quizGeneratedSuccessfully => '测验生成成功！';

  @override
  String get editProfile => '编辑个人资料';

  @override
  String get displayName => '显示名称';

  @override
  String get email => '电子邮件';

  @override
  String get password => '密码';

  @override
  String get changePassword => '更改密码（可选）';

  @override
  String get save => '保存';

  @override
  String get updateSuccessful => '更新成功！';

  @override
  String get all => '全部';

  @override
  String get endQuiz => '结束测验';

  @override
  String get deleteAccount => '删除账号';

  @override
  String get deleteAccountConfirmTitle => '删除账号？';

  @override
  String get deleteAccountConfirmDesc => '此操作是永久性的。您的所有测验和历史记录都将被删除。';

  @override
  String get notification => '通知';

  @override
  String get verificationRequired => '需要验证';

  @override
  String verificationSentDesc(Object email) {
    return '验证链接已发送至 $email。点击链接后，您的电子邮件将被更新。';
  }

  @override
  String get leaveBlankToKeepCurrent => '留空以保留当前密码';

  @override
  String correctCount(Object count) {
    return '$count 正确';
  }

  @override
  String get gallery => '相册';

  @override
  String get camera => '相机';
}
