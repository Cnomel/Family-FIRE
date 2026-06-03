import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
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
/// import 'i18n/app_localizations.dart';
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
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In zh, this message translates to:
  /// **'Family Fire'**
  String get appTitle;

  /// No description provided for @login.
  ///
  /// In zh, this message translates to:
  /// **'登录'**
  String get login;

  /// No description provided for @register.
  ///
  /// In zh, this message translates to:
  /// **'注册'**
  String get register;

  /// No description provided for @forgotPassword.
  ///
  /// In zh, this message translates to:
  /// **'忘记密码'**
  String get forgotPassword;

  /// No description provided for @resetPassword.
  ///
  /// In zh, this message translates to:
  /// **'重置密码'**
  String get resetPassword;

  /// No description provided for @username.
  ///
  /// In zh, this message translates to:
  /// **'用户名'**
  String get username;

  /// No description provided for @email.
  ///
  /// In zh, this message translates to:
  /// **'邮箱'**
  String get email;

  /// No description provided for @password.
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get password;

  /// No description provided for @confirmPassword.
  ///
  /// In zh, this message translates to:
  /// **'确认密码'**
  String get confirmPassword;

  /// No description provided for @fullName.
  ///
  /// In zh, this message translates to:
  /// **'姓名'**
  String get fullName;

  /// No description provided for @usernameOrEmail.
  ///
  /// In zh, this message translates to:
  /// **'用户名/邮箱'**
  String get usernameOrEmail;

  /// No description provided for @loginButton.
  ///
  /// In zh, this message translates to:
  /// **'登录'**
  String get loginButton;

  /// No description provided for @registerButton.
  ///
  /// In zh, this message translates to:
  /// **'注册'**
  String get registerButton;

  /// No description provided for @noAccount.
  ///
  /// In zh, this message translates to:
  /// **'没有账号？'**
  String get noAccount;

  /// No description provided for @hasAccount.
  ///
  /// In zh, this message translates to:
  /// **'已有账号？'**
  String get hasAccount;

  /// No description provided for @forgotPasswordLink.
  ///
  /// In zh, this message translates to:
  /// **'忘记密码？'**
  String get forgotPasswordLink;

  /// No description provided for @sendResetLink.
  ///
  /// In zh, this message translates to:
  /// **'发送重置链接'**
  String get sendResetLink;

  /// No description provided for @backToLogin.
  ///
  /// In zh, this message translates to:
  /// **'返回登录'**
  String get backToLogin;

  /// No description provided for @home.
  ///
  /// In zh, this message translates to:
  /// **'首页'**
  String get home;

  /// No description provided for @assets.
  ///
  /// In zh, this message translates to:
  /// **'资产'**
  String get assets;

  /// No description provided for @finance.
  ///
  /// In zh, this message translates to:
  /// **'财务'**
  String get finance;

  /// No description provided for @documents.
  ///
  /// In zh, this message translates to:
  /// **'文档'**
  String get documents;

  /// No description provided for @mine.
  ///
  /// In zh, this message translates to:
  /// **'我的'**
  String get mine;

  /// No description provided for @totalAssets.
  ///
  /// In zh, this message translates to:
  /// **'总资产'**
  String get totalAssets;

  /// No description provided for @totalLiabilities.
  ///
  /// In zh, this message translates to:
  /// **'总负债'**
  String get totalLiabilities;

  /// No description provided for @netWorth.
  ///
  /// In zh, this message translates to:
  /// **'净资产'**
  String get netWorth;

  /// No description provided for @yesterdayReturn.
  ///
  /// In zh, this message translates to:
  /// **'昨日收益'**
  String get yesterdayReturn;

  /// No description provided for @fireNumber.
  ///
  /// In zh, this message translates to:
  /// **'FIRE数字'**
  String get fireNumber;

  /// No description provided for @fiRatio.
  ///
  /// In zh, this message translates to:
  /// **'财务独立比率'**
  String get fiRatio;

  /// No description provided for @savingsRate.
  ///
  /// In zh, this message translates to:
  /// **'储蓄率'**
  String get savingsRate;

  /// No description provided for @yearsToFire.
  ///
  /// In zh, this message translates to:
  /// **'年实现财务独立'**
  String get yearsToFire;

  /// No description provided for @monthlyExpense.
  ///
  /// In zh, this message translates to:
  /// **'月支出'**
  String get monthlyExpense;

  /// No description provided for @monthlyIncome.
  ///
  /// In zh, this message translates to:
  /// **'月收入'**
  String get monthlyIncome;

  /// No description provided for @assetAllocation.
  ///
  /// In zh, this message translates to:
  /// **'资产配置'**
  String get assetAllocation;

  /// No description provided for @netWorthTrend.
  ///
  /// In zh, this message translates to:
  /// **'净资产趋势'**
  String get netWorthTrend;

  /// No description provided for @addAsset.
  ///
  /// In zh, this message translates to:
  /// **'添加资产'**
  String get addAsset;

  /// No description provided for @editAsset.
  ///
  /// In zh, this message translates to:
  /// **'编辑资产'**
  String get editAsset;

  /// No description provided for @assetName.
  ///
  /// In zh, this message translates to:
  /// **'资产名称'**
  String get assetName;

  /// No description provided for @description.
  ///
  /// In zh, this message translates to:
  /// **'描述'**
  String get description;

  /// No description provided for @purchasePrice.
  ///
  /// In zh, this message translates to:
  /// **'购买价格'**
  String get purchasePrice;

  /// No description provided for @purchaseDate.
  ///
  /// In zh, this message translates to:
  /// **'购买日期'**
  String get purchaseDate;

  /// No description provided for @currentValue.
  ///
  /// In zh, this message translates to:
  /// **'当前价值'**
  String get currentValue;

  /// No description provided for @nature.
  ///
  /// In zh, this message translates to:
  /// **'性质'**
  String get nature;

  /// No description provided for @utility.
  ///
  /// In zh, this message translates to:
  /// **'用途'**
  String get utility;

  /// No description provided for @ownership.
  ///
  /// In zh, this message translates to:
  /// **'持有方式'**
  String get ownership;

  /// No description provided for @liquidity.
  ///
  /// In zh, this message translates to:
  /// **'流动性'**
  String get liquidity;

  /// No description provided for @tags.
  ///
  /// In zh, this message translates to:
  /// **'标签'**
  String get tags;

  /// No description provided for @search.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get search;

  /// No description provided for @filter.
  ///
  /// In zh, this message translates to:
  /// **'筛选'**
  String get filter;

  /// No description provided for @all.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get all;

  /// No description provided for @tangible.
  ///
  /// In zh, this message translates to:
  /// **'有形资产'**
  String get tangible;

  /// No description provided for @digital.
  ///
  /// In zh, this message translates to:
  /// **'数字资产'**
  String get digital;

  /// No description provided for @financial.
  ///
  /// In zh, this message translates to:
  /// **'金融资产'**
  String get financial;

  /// No description provided for @intangible.
  ///
  /// In zh, this message translates to:
  /// **'无形资产'**
  String get intangible;

  /// No description provided for @service.
  ///
  /// In zh, this message translates to:
  /// **'服务'**
  String get service;

  /// No description provided for @productive.
  ///
  /// In zh, this message translates to:
  /// **'生产性'**
  String get productive;

  /// No description provided for @consumable.
  ///
  /// In zh, this message translates to:
  /// **'消耗品'**
  String get consumable;

  /// No description provided for @protective.
  ///
  /// In zh, this message translates to:
  /// **'防护性'**
  String get protective;

  /// No description provided for @speculative.
  ///
  /// In zh, this message translates to:
  /// **'投机性'**
  String get speculative;

  /// No description provided for @lifestyle.
  ///
  /// In zh, this message translates to:
  /// **'生活方式'**
  String get lifestyle;

  /// No description provided for @essential.
  ///
  /// In zh, this message translates to:
  /// **'必需品'**
  String get essential;

  /// No description provided for @owned.
  ///
  /// In zh, this message translates to:
  /// **'自有'**
  String get owned;

  /// No description provided for @mortgaged.
  ///
  /// In zh, this message translates to:
  /// **'抵押'**
  String get mortgaged;

  /// No description provided for @leased.
  ///
  /// In zh, this message translates to:
  /// **'租赁'**
  String get leased;

  /// No description provided for @subscribed.
  ///
  /// In zh, this message translates to:
  /// **'订阅'**
  String get subscribed;

  /// No description provided for @licensed.
  ///
  /// In zh, this message translates to:
  /// **'授权'**
  String get licensed;

  /// No description provided for @custodied.
  ///
  /// In zh, this message translates to:
  /// **'托管'**
  String get custodied;

  /// No description provided for @instant.
  ///
  /// In zh, this message translates to:
  /// **'即时'**
  String get instant;

  /// No description provided for @high.
  ///
  /// In zh, this message translates to:
  /// **'高'**
  String get high;

  /// No description provided for @medium.
  ///
  /// In zh, this message translates to:
  /// **'中'**
  String get medium;

  /// No description provided for @low.
  ///
  /// In zh, this message translates to:
  /// **'低'**
  String get low;

  /// No description provided for @fixed.
  ///
  /// In zh, this message translates to:
  /// **'固定'**
  String get fixed;

  /// No description provided for @liabilities.
  ///
  /// In zh, this message translates to:
  /// **'负债'**
  String get liabilities;

  /// No description provided for @addLiability.
  ///
  /// In zh, this message translates to:
  /// **'添加负债'**
  String get addLiability;

  /// No description provided for @liabilityName.
  ///
  /// In zh, this message translates to:
  /// **'负债名称'**
  String get liabilityName;

  /// No description provided for @originalAmount.
  ///
  /// In zh, this message translates to:
  /// **'原始金额'**
  String get originalAmount;

  /// No description provided for @currentBalance.
  ///
  /// In zh, this message translates to:
  /// **'当前余额'**
  String get currentBalance;

  /// No description provided for @interestRate.
  ///
  /// In zh, this message translates to:
  /// **'年利率'**
  String get interestRate;

  /// No description provided for @monthlyPayment.
  ///
  /// In zh, this message translates to:
  /// **'月供'**
  String get monthlyPayment;

  /// No description provided for @mortgage.
  ///
  /// In zh, this message translates to:
  /// **'房贷'**
  String get mortgage;

  /// No description provided for @autoLoan.
  ///
  /// In zh, this message translates to:
  /// **'车贷'**
  String get autoLoan;

  /// No description provided for @creditCard.
  ///
  /// In zh, this message translates to:
  /// **'信用卡'**
  String get creditCard;

  /// No description provided for @consumerLoan.
  ///
  /// In zh, this message translates to:
  /// **'消费贷'**
  String get consumerLoan;

  /// No description provided for @personalLoan.
  ///
  /// In zh, this message translates to:
  /// **'个人借款'**
  String get personalLoan;

  /// No description provided for @incomeExpense.
  ///
  /// In zh, this message translates to:
  /// **'收支管理'**
  String get incomeExpense;

  /// No description provided for @income.
  ///
  /// In zh, this message translates to:
  /// **'收入'**
  String get income;

  /// No description provided for @expense.
  ///
  /// In zh, this message translates to:
  /// **'支出'**
  String get expense;

  /// No description provided for @category.
  ///
  /// In zh, this message translates to:
  /// **'分类'**
  String get category;

  /// No description provided for @amount.
  ///
  /// In zh, this message translates to:
  /// **'金额'**
  String get amount;

  /// No description provided for @date.
  ///
  /// In zh, this message translates to:
  /// **'日期'**
  String get date;

  /// No description provided for @totalIncome.
  ///
  /// In zh, this message translates to:
  /// **'总收入'**
  String get totalIncome;

  /// No description provided for @totalExpense.
  ///
  /// In zh, this message translates to:
  /// **'总支出'**
  String get totalExpense;

  /// No description provided for @net.
  ///
  /// In zh, this message translates to:
  /// **'结余'**
  String get net;

  /// No description provided for @investments.
  ///
  /// In zh, this message translates to:
  /// **'投资组合'**
  String get investments;

  /// No description provided for @transaction.
  ///
  /// In zh, this message translates to:
  /// **'交易记录'**
  String get transaction;

  /// No description provided for @buy.
  ///
  /// In zh, this message translates to:
  /// **'买入'**
  String get buy;

  /// No description provided for @sell.
  ///
  /// In zh, this message translates to:
  /// **'卖出'**
  String get sell;

  /// No description provided for @dividend.
  ///
  /// In zh, this message translates to:
  /// **'分红'**
  String get dividend;

  /// No description provided for @documentsTitle.
  ///
  /// In zh, this message translates to:
  /// **'文档'**
  String get documentsTitle;

  /// No description provided for @uploadDocument.
  ///
  /// In zh, this message translates to:
  /// **'上传文档'**
  String get uploadDocument;

  /// No description provided for @takePhoto.
  ///
  /// In zh, this message translates to:
  /// **'拍照'**
  String get takePhoto;

  /// No description provided for @fromGallery.
  ///
  /// In zh, this message translates to:
  /// **'从相册选择'**
  String get fromGallery;

  /// No description provided for @pickFile.
  ///
  /// In zh, this message translates to:
  /// **'选择文件'**
  String get pickFile;

  /// No description provided for @notifications.
  ///
  /// In zh, this message translates to:
  /// **'通知'**
  String get notifications;

  /// No description provided for @markAllRead.
  ///
  /// In zh, this message translates to:
  /// **'全部已读'**
  String get markAllRead;

  /// No description provided for @unreadCount.
  ///
  /// In zh, this message translates to:
  /// **'未读'**
  String get unreadCount;

  /// No description provided for @today.
  ///
  /// In zh, this message translates to:
  /// **'今天'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In zh, this message translates to:
  /// **'昨天'**
  String get yesterday;

  /// No description provided for @thisWeek.
  ///
  /// In zh, this message translates to:
  /// **'本周'**
  String get thisWeek;

  /// No description provided for @earlier.
  ///
  /// In zh, this message translates to:
  /// **'更早'**
  String get earlier;

  /// No description provided for @family.
  ///
  /// In zh, this message translates to:
  /// **'家庭'**
  String get family;

  /// No description provided for @createFamily.
  ///
  /// In zh, this message translates to:
  /// **'创建家庭'**
  String get createFamily;

  /// No description provided for @familyName.
  ///
  /// In zh, this message translates to:
  /// **'家庭名称'**
  String get familyName;

  /// No description provided for @inviteCode.
  ///
  /// In zh, this message translates to:
  /// **'邀请码'**
  String get inviteCode;

  /// No description provided for @joinFamily.
  ///
  /// In zh, this message translates to:
  /// **'加入家庭'**
  String get joinFamily;

  /// No description provided for @members.
  ///
  /// In zh, this message translates to:
  /// **'成员'**
  String get members;

  /// No description provided for @admin.
  ///
  /// In zh, this message translates to:
  /// **'管理员'**
  String get admin;

  /// No description provided for @member.
  ///
  /// In zh, this message translates to:
  /// **'成员'**
  String get member;

  /// No description provided for @remove.
  ///
  /// In zh, this message translates to:
  /// **'移除'**
  String get remove;

  /// No description provided for @settings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settings;

  /// No description provided for @profile.
  ///
  /// In zh, this message translates to:
  /// **'个人资料'**
  String get profile;

  /// No description provided for @editProfile.
  ///
  /// In zh, this message translates to:
  /// **'编辑资料'**
  String get editProfile;

  /// No description provided for @changePassword.
  ///
  /// In zh, this message translates to:
  /// **'修改密码'**
  String get changePassword;

  /// No description provided for @darkMode.
  ///
  /// In zh, this message translates to:
  /// **'深色模式'**
  String get darkMode;

  /// No description provided for @language.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get language;

  /// No description provided for @biometric.
  ///
  /// In zh, this message translates to:
  /// **'生物识别'**
  String get biometric;

  /// No description provided for @enableBiometric.
  ///
  /// In zh, this message translates to:
  /// **'启用生物识别'**
  String get enableBiometric;

  /// No description provided for @privacy.
  ///
  /// In zh, this message translates to:
  /// **'隐私'**
  String get privacy;

  /// No description provided for @privacyMode.
  ///
  /// In zh, this message translates to:
  /// **'隐私模式'**
  String get privacyMode;

  /// No description provided for @about.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get about;

  /// No description provided for @logout.
  ///
  /// In zh, this message translates to:
  /// **'退出登录'**
  String get logout;

  /// No description provided for @confirm.
  ///
  /// In zh, this message translates to:
  /// **'确认'**
  String get confirm;

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get edit;

  /// No description provided for @create.
  ///
  /// In zh, this message translates to:
  /// **'创建'**
  String get create;

  /// No description provided for @submit.
  ///
  /// In zh, this message translates to:
  /// **'提交'**
  String get submit;

  /// No description provided for @loading.
  ///
  /// In zh, this message translates to:
  /// **'加载中...'**
  String get loading;

  /// No description provided for @noData.
  ///
  /// In zh, this message translates to:
  /// **'暂无数据'**
  String get noData;

  /// No description provided for @noAssets.
  ///
  /// In zh, this message translates to:
  /// **'暂无资产，点击添加第一个资产'**
  String get noAssets;

  /// No description provided for @noDocuments.
  ///
  /// In zh, this message translates to:
  /// **'暂无文档'**
  String get noDocuments;

  /// No description provided for @noNotifications.
  ///
  /// In zh, this message translates to:
  /// **'暂无通知'**
  String get noNotifications;

  /// No description provided for @noLiabilities.
  ///
  /// In zh, this message translates to:
  /// **'暂无负债'**
  String get noLiabilities;

  /// No description provided for @error.
  ///
  /// In zh, this message translates to:
  /// **'错误'**
  String get error;

  /// No description provided for @success.
  ///
  /// In zh, this message translates to:
  /// **'成功'**
  String get success;

  /// No description provided for @networkError.
  ///
  /// In zh, this message translates to:
  /// **'网络错误，请检查网络连接'**
  String get networkError;

  /// No description provided for @serverError.
  ///
  /// In zh, this message translates to:
  /// **'服务器错误，请稍后重试'**
  String get serverError;

  /// No description provided for @authError.
  ///
  /// In zh, this message translates to:
  /// **'认证失败，请重新登录'**
  String get authError;

  /// No description provided for @validationError.
  ///
  /// In zh, this message translates to:
  /// **'请检查输入内容'**
  String get validationError;

  /// No description provided for @passwordMismatch.
  ///
  /// In zh, this message translates to:
  /// **'两次密码不一致'**
  String get passwordMismatch;

  /// No description provided for @passwordTooShort.
  ///
  /// In zh, this message translates to:
  /// **'密码长度至少8位'**
  String get passwordTooShort;

  /// No description provided for @passwordStrengthWeak.
  ///
  /// In zh, this message translates to:
  /// **'弱'**
  String get passwordStrengthWeak;

  /// No description provided for @passwordStrengthMedium.
  ///
  /// In zh, this message translates to:
  /// **'中'**
  String get passwordStrengthMedium;

  /// No description provided for @passwordStrengthStrong.
  ///
  /// In zh, this message translates to:
  /// **'强'**
  String get passwordStrengthStrong;

  /// No description provided for @oldPassword.
  ///
  /// In zh, this message translates to:
  /// **'当前密码'**
  String get oldPassword;

  /// No description provided for @newPassword.
  ///
  /// In zh, this message translates to:
  /// **'新密码'**
  String get newPassword;

  /// No description provided for @selectDate.
  ///
  /// In zh, this message translates to:
  /// **'选择日期'**
  String get selectDate;

  /// No description provided for @selectCategory.
  ///
  /// In zh, this message translates to:
  /// **'选择分类'**
  String get selectCategory;

  /// No description provided for @step1.
  ///
  /// In zh, this message translates to:
  /// **'选择分类'**
  String get step1;

  /// No description provided for @step2.
  ///
  /// In zh, this message translates to:
  /// **'基本信息'**
  String get step2;

  /// No description provided for @step3.
  ///
  /// In zh, this message translates to:
  /// **'财务信息'**
  String get step3;

  /// No description provided for @step4.
  ///
  /// In zh, this message translates to:
  /// **'详细信息'**
  String get step4;

  /// No description provided for @relationshipGraph.
  ///
  /// In zh, this message translates to:
  /// **'关系图'**
  String get relationshipGraph;

  /// No description provided for @consumableTracking.
  ///
  /// In zh, this message translates to:
  /// **'消耗品追踪'**
  String get consumableTracking;

  /// No description provided for @quantity.
  ///
  /// In zh, this message translates to:
  /// **'数量'**
  String get quantity;

  /// No description provided for @unit.
  ///
  /// In zh, this message translates to:
  /// **'单位'**
  String get unit;

  /// No description provided for @reorderThreshold.
  ///
  /// In zh, this message translates to:
  /// **'补货阈值'**
  String get reorderThreshold;

  /// No description provided for @scanToAdd.
  ///
  /// In zh, this message translates to:
  /// **'扫码添加'**
  String get scanToAdd;

  /// No description provided for @fireDashboard.
  ///
  /// In zh, this message translates to:
  /// **'FIRE仪表盘'**
  String get fireDashboard;

  /// No description provided for @monteCarlo.
  ///
  /// In zh, this message translates to:
  /// **'蒙特卡洛模拟'**
  String get monteCarlo;

  /// No description provided for @successRate.
  ///
  /// In zh, this message translates to:
  /// **'成功率'**
  String get successRate;

  /// No description provided for @medianYears.
  ///
  /// In zh, this message translates to:
  /// **'中位年数'**
  String get medianYears;

  /// No description provided for @priceHistory.
  ///
  /// In zh, this message translates to:
  /// **'价格走势'**
  String get priceHistory;

  /// No description provided for @assetDetail.
  ///
  /// In zh, this message translates to:
  /// **'资产详情'**
  String get assetDetail;

  /// No description provided for @lifecycle.
  ///
  /// In zh, this message translates to:
  /// **'生命周期'**
  String get lifecycle;

  /// No description provided for @depreciation.
  ///
  /// In zh, this message translates to:
  /// **'折旧'**
  String get depreciation;

  /// No description provided for @expiration.
  ///
  /// In zh, this message translates to:
  /// **'到期'**
  String get expiration;

  /// No description provided for @appreciation.
  ///
  /// In zh, this message translates to:
  /// **'增值'**
  String get appreciation;

  /// No description provided for @volatile.
  ///
  /// In zh, this message translates to:
  /// **'波动'**
  String get volatile;

  /// No description provided for @stable.
  ///
  /// In zh, this message translates to:
  /// **'稳定'**
  String get stable;

  /// No description provided for @insuranceGaps.
  ///
  /// In zh, this message translates to:
  /// **'保险缺口'**
  String get insuranceGaps;

  /// No description provided for @noInsurance.
  ///
  /// In zh, this message translates to:
  /// **'无保险覆盖'**
  String get noInsurance;

  /// No description provided for @valueHistory.
  ///
  /// In zh, this message translates to:
  /// **'价值历史'**
  String get valueHistory;

  /// No description provided for @months.
  ///
  /// In zh, this message translates to:
  /// **'个月'**
  String get months;

  /// No description provided for @shareInviteCode.
  ///
  /// In zh, this message translates to:
  /// **'分享邀请码'**
  String get shareInviteCode;

  /// No description provided for @inviteExpiry.
  ///
  /// In zh, this message translates to:
  /// **'邀请码有效期7天'**
  String get inviteExpiry;

  /// No description provided for @copied.
  ///
  /// In zh, this message translates to:
  /// **'已复制到剪贴板'**
  String get copied;

  /// No description provided for @familyMembers.
  ///
  /// In zh, this message translates to:
  /// **'家庭成员'**
  String get familyMembers;

  /// No description provided for @joinedAt.
  ///
  /// In zh, this message translates to:
  /// **'加入时间'**
  String get joinedAt;

  /// No description provided for @role.
  ///
  /// In zh, this message translates to:
  /// **'角色'**
  String get role;

  /// No description provided for @manageFamily.
  ///
  /// In zh, this message translates to:
  /// **'管理家庭'**
  String get manageFamily;

  /// No description provided for @leaveFamily.
  ///
  /// In zh, this message translates to:
  /// **'退出家庭'**
  String get leaveFamily;

  /// No description provided for @deleteFamily.
  ///
  /// In zh, this message translates to:
  /// **'删除家庭'**
  String get deleteFamily;

  /// No description provided for @confirmDelete.
  ///
  /// In zh, this message translates to:
  /// **'确认删除？此操作不可撤销'**
  String get confirmDelete;

  /// No description provided for @assetStats.
  ///
  /// In zh, this message translates to:
  /// **'资产统计'**
  String get assetStats;

  /// No description provided for @byNature.
  ///
  /// In zh, this message translates to:
  /// **'按性质'**
  String get byNature;

  /// No description provided for @byUtility.
  ///
  /// In zh, this message translates to:
  /// **'按用途'**
  String get byUtility;

  /// No description provided for @byOwnership.
  ///
  /// In zh, this message translates to:
  /// **'按持有方式'**
  String get byOwnership;

  /// No description provided for @byLiquidity.
  ///
  /// In zh, this message translates to:
  /// **'按流动性'**
  String get byLiquidity;

  /// No description provided for @refreshPrices.
  ///
  /// In zh, this message translates to:
  /// **'刷新价格'**
  String get refreshPrices;

  /// No description provided for @costBasis.
  ///
  /// In zh, this message translates to:
  /// **'成本基础'**
  String get costBasis;

  /// No description provided for @totalGain.
  ///
  /// In zh, this message translates to:
  /// **'总收益'**
  String get totalGain;

  /// No description provided for @gainPercent.
  ///
  /// In zh, this message translates to:
  /// **'收益率'**
  String get gainPercent;

  /// No description provided for @holdings.
  ///
  /// In zh, this message translates to:
  /// **'持仓'**
  String get holdings;

  /// No description provided for @allocation.
  ///
  /// In zh, this message translates to:
  /// **'配置'**
  String get allocation;

  /// No description provided for @passiveIncome.
  ///
  /// In zh, this message translates to:
  /// **'被动收入'**
  String get passiveIncome;

  /// No description provided for @annualIncome.
  ///
  /// In zh, this message translates to:
  /// **'年收入'**
  String get annualIncome;

  /// No description provided for @expenses.
  ///
  /// In zh, this message translates to:
  /// **'支出分析'**
  String get expenses;

  /// No description provided for @recurringExpenses.
  ///
  /// In zh, this message translates to:
  /// **'经常性支出'**
  String get recurringExpenses;

  /// No description provided for @selectLanguage.
  ///
  /// In zh, this message translates to:
  /// **'选择语言'**
  String get selectLanguage;

  /// No description provided for @chinese.
  ///
  /// In zh, this message translates to:
  /// **'中文'**
  String get chinese;

  /// No description provided for @english.
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @systemDefault.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get systemDefault;

  /// No description provided for @appearance.
  ///
  /// In zh, this message translates to:
  /// **'外观'**
  String get appearance;

  /// No description provided for @security.
  ///
  /// In zh, this message translates to:
  /// **'安全'**
  String get security;

  /// No description provided for @notificationSettings.
  ///
  /// In zh, this message translates to:
  /// **'通知设置'**
  String get notificationSettings;

  /// No description provided for @adminFunctions.
  ///
  /// In zh, this message translates to:
  /// **'管理员功能'**
  String get adminFunctions;

  /// No description provided for @userManagement.
  ///
  /// In zh, this message translates to:
  /// **'用户管理'**
  String get userManagement;

  /// No description provided for @version.
  ///
  /// In zh, this message translates to:
  /// **'版本'**
  String get version;

  /// No description provided for @userAgreement.
  ///
  /// In zh, this message translates to:
  /// **'用户协议'**
  String get userAgreement;

  /// No description provided for @privacyPolicy.
  ///
  /// In zh, this message translates to:
  /// **'隐私政策'**
  String get privacyPolicy;

  /// No description provided for @checkUpdate.
  ///
  /// In zh, this message translates to:
  /// **'检查更新'**
  String get checkUpdate;

  /// No description provided for @currentVersion.
  ///
  /// In zh, this message translates to:
  /// **'当前版本'**
  String get currentVersion;

  /// No description provided for @latestVersion.
  ///
  /// In zh, this message translates to:
  /// **'已是最新版本'**
  String get latestVersion;

  /// No description provided for @confirmLogout.
  ///
  /// In zh, this message translates to:
  /// **'确认退出'**
  String get confirmLogout;

  /// No description provided for @confirmLogoutMessage.
  ///
  /// In zh, this message translates to:
  /// **'确认退出登录？'**
  String get confirmLogoutMessage;

  /// No description provided for @hideAmountDisplay.
  ///
  /// In zh, this message translates to:
  /// **'隐藏金额显示'**
  String get hideAmountDisplay;

  /// No description provided for @biometricSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'Face ID / 指纹'**
  String get biometricSubtitle;

  /// No description provided for @budgetManagement.
  ///
  /// In zh, this message translates to:
  /// **'收支管理'**
  String get budgetManagement;

  /// No description provided for @budgetTemplates.
  ///
  /// In zh, this message translates to:
  /// **'收支项管理'**
  String get budgetTemplates;

  /// No description provided for @yearlyStats.
  ///
  /// In zh, this message translates to:
  /// **'年度统计'**
  String get yearlyStats;

  /// No description provided for @monthlyBudget.
  ///
  /// In zh, this message translates to:
  /// **'月度预算'**
  String get monthlyBudget;

  /// No description provided for @expenseTemplates.
  ///
  /// In zh, this message translates to:
  /// **'支出项'**
  String get expenseTemplates;

  /// No description provided for @incomeTemplates.
  ///
  /// In zh, this message translates to:
  /// **'收入项'**
  String get incomeTemplates;

  /// No description provided for @systemFixedItems.
  ///
  /// In zh, this message translates to:
  /// **'系统固定项'**
  String get systemFixedItems;

  /// No description provided for @customFixedItems.
  ///
  /// In zh, this message translates to:
  /// **'自定义固定项'**
  String get customFixedItems;

  /// No description provided for @temporaryItems.
  ///
  /// In zh, this message translates to:
  /// **'临时项'**
  String get temporaryItems;

  /// No description provided for @expectedRange.
  ///
  /// In zh, this message translates to:
  /// **'预期范围'**
  String get expectedRange;

  /// No description provided for @upgradeToFixed.
  ///
  /// In zh, this message translates to:
  /// **'升级为固定项'**
  String get upgradeToFixed;

  /// No description provided for @monthlyTrend.
  ///
  /// In zh, this message translates to:
  /// **'月度趋势'**
  String get monthlyTrend;

  /// No description provided for @monthlyDetail.
  ///
  /// In zh, this message translates to:
  /// **'月度明细'**
  String get monthlyDetail;

  /// No description provided for @categoryBreakdown.
  ///
  /// In zh, this message translates to:
  /// **'分类统计'**
  String get categoryBreakdown;

  /// No description provided for @totalNet.
  ///
  /// In zh, this message translates to:
  /// **'总结余'**
  String get totalNet;

  /// No description provided for @averageSavingsRate.
  ///
  /// In zh, this message translates to:
  /// **'平均储蓄率'**
  String get averageSavingsRate;
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
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
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
