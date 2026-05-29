/// 用户模型
class User {
  final String id;
  final String username;
  final String email;
  final String fullName;
  final String? avatarUrl;
  final String role;
  final bool isActive;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.fullName,
    this.avatarUrl,
    required this.role,
    required this.isActive,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] ?? '',
    username: json['username'] ?? '',
    email: json['email'] ?? '',
    fullName: json['full_name'] ?? '',
    avatarUrl: json['avatar_url'],
    role: json['role'] ?? 'member',
    isActive: json['is_active'] ?? true,
  );

  String get displayName => fullName.isNotEmpty ? fullName : username;
  String get initial => displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';
  
  String get roleLabel {
    switch (role) {
      case 'admin': return '系统管理员';
      case 'family_admin': return '家庭管理员';
      case 'member': return '成员';
      default: return role;
    }
  }
}

/// 家庭模型
class Family {
  final String id;
  final String name;
  final String? description;
  final int memberCount;
  final String? inviteCode;

  Family({
    required this.id,
    required this.name,
    this.description,
    required this.memberCount,
    this.inviteCode,
  });

  factory Family.fromJson(Map<String, dynamic> json) => Family(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    description: json['description'],
    memberCount: json['member_count'] ?? 0,
    inviteCode: json['invite_code'],
  );
}

/// 资产模型
class Asset {
  final String id;
  final String name;
  final String? description;
  final String nature;
  final String utility;
  final String ownership;
  final String liquidity;
  final List<String> tags;
  final String status;
  final AssetFinancial? financial;
  final String createdAt;

  Asset({
    required this.id,
    required this.name,
    this.description,
    required this.nature,
    required this.utility,
    required this.ownership,
    required this.liquidity,
    required this.tags,
    required this.status,
    this.financial,
    required this.createdAt,
  });

  factory Asset.fromJson(Map<String, dynamic> json) => Asset(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    description: json['description'],
    nature: json['nature'] ?? '',
    utility: json['utility'] ?? '',
    ownership: json['ownership'] ?? '',
    liquidity: json['liquidity'] ?? '',
    tags: (json['tags'] as List?)?.cast<String>() ?? [],
    status: json['status'] ?? 'active',
    financial: json['financial'] != null ? AssetFinancial.fromJson(json['financial']) : null,
    createdAt: json['created_at'] ?? '',
  );
}

/// 资产财务信息
class AssetFinancial {
  final double purchasePrice;
  final String? purchaseDate;
  final String currency;
  final double currentValue;
  final double monthlyCarryingCost;

  AssetFinancial({
    required this.purchasePrice,
    this.purchaseDate,
    required this.currency,
    required this.currentValue,
    required this.monthlyCarryingCost,
  });

  factory AssetFinancial.fromJson(Map<String, dynamic> json) => AssetFinancial(
    purchasePrice: (json['purchase_price'] ?? 0).toDouble(),
    purchaseDate: json['purchase_date'],
    currency: json['currency'] ?? 'CNY',
    currentValue: (json['current_value'] ?? 0).toDouble(),
    monthlyCarryingCost: (json['monthly_carrying_cost'] ?? 0).toDouble(),
  );
}

/// 收支记录
class Transaction {
  final String id;
  final String type;
  final double amount;
  final String? description;
  final String date;
  final String? categoryId;

  Transaction({
    required this.id,
    required this.type,
    required this.amount,
    this.description,
    required this.date,
    this.categoryId,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
    id: json['id'] ?? '',
    type: json['type'] ?? '',
    amount: (json['amount'] ?? 0).toDouble(),
    description: json['description'],
    date: json['date'] ?? '',
    categoryId: json['category_id'],
  );

  bool get isIncome => type == 'income';
}

/// 负债
class Liability {
  final String id;
  final String name;
  final String type;
  final double originalAmount;
  final double currentBalance;
  final double? interestRate;
  final double? monthlyPayment;

  Liability({
    required this.id,
    required this.name,
    required this.type,
    required this.originalAmount,
    required this.currentBalance,
    this.interestRate,
    this.monthlyPayment,
  });

  factory Liability.fromJson(Map<String, dynamic> json) => Liability(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    type: json['type'] ?? '',
    originalAmount: (json['original_amount'] ?? 0).toDouble(),
    currentBalance: (json['current_balance'] ?? 0).toDouble(),
    interestRate: json['interest_rate']?.toDouble(),
    monthlyPayment: json['monthly_payment']?.toDouble(),
  );

  String get typeLabel {
    switch (type) {
      case 'mortgage': return '房贷';
      case 'auto_loan': return '车贷';
      case 'credit_card': return '信用卡';
      case 'consumer_loan': return '消费贷';
      case 'personal_loan': return '个人借款';
      default: return type;
    }
  }
}

/// FIRE快照
class FireSnapshot {
  final double netWorth;
  final double liquidNetWorth;
  final double fireNumber;
  final double fiRatio;
  final int yearsToFire;
  final double savingsRate;
  final double safeWithdrawalMonthly;
  final double annualExpense;

  FireSnapshot({
    required this.netWorth,
    required this.liquidNetWorth,
    required this.fireNumber,
    required this.fiRatio,
    required this.yearsToFire,
    required this.savingsRate,
    required this.safeWithdrawalMonthly,
    required this.annualExpense,
  });

  factory FireSnapshot.fromJson(Map<String, dynamic> json) {
    final nw = json['net_worth'] ?? {};
    return FireSnapshot(
      netWorth: (nw['net_worth'] ?? 0).toDouble(),
      liquidNetWorth: (nw['liquid_net_worth'] ?? 0).toDouble(),
      fireNumber: (json['fire_number'] ?? 0).toDouble(),
      fiRatio: (json['fi_ratio'] ?? 0).toDouble(),
      yearsToFire: json['years_to_fire'] ?? 999,
      savingsRate: (json['savings_rate'] ?? 0).toDouble(),
      safeWithdrawalMonthly: (json['safe_withdrawal_monthly'] ?? 0).toDouble(),
      annualExpense: (json['annual_expense'] ?? 0).toDouble(),
    );
  }
}
