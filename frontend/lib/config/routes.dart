import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_state.dart';
import '../features/auth/login_page.dart';
import '../features/auth/register_page.dart';
import '../features/auth/forgot_password_page.dart';
import '../features/home/home_shell.dart';
import '../features/home/dashboard_page.dart';
import '../features/assets/asset_list_page.dart';
import '../features/assets/asset_detail_page.dart';
import '../features/assets/asset_edit_page.dart';
import '../features/assets/asset_filter_page.dart';
import '../features/assets/category_manage_page.dart';
import '../features/assets/relationship_page.dart';
import '../features/assets/consumable_page.dart';
import '../features/assets/scan_page.dart';
import '../features/assets/insurance_gaps_page.dart';
import '../features/finance/fire_dashboard_page.dart';
import '../features/finance/liability_page.dart';
import '../features/finance/monthly_budget_page.dart';
import '../features/finance/budget_templates_page.dart';
import '../features/finance/yearly_stats_page.dart';
import '../features/finance/portfolio_page.dart';
import '../features/finance/price_chart_page.dart';
import '../features/finance/monte_carlo_page.dart';
import '../features/finance/cost_basis_page.dart';
import '../features/finance/passive_income_page.dart';
import '../features/finance/trade_page.dart';
import '../features/documents/document_list_page.dart';
import '../features/documents/pdf_viewer_page.dart';
import '../features/documents/image_viewer_page.dart';
import '../features/documents/upload_page.dart';
import '../features/notifications/notification_list_page.dart';
import '../features/notifications/notification_settings_page.dart';
import '../features/family/family_list_page.dart';
import '../features/family/family_detail_page.dart';
import '../features/family/invite_page.dart';
import '../features/settings/profile_page.dart';
import '../features/settings/settings_page.dart';
import '../features/settings/terms_page.dart';
import '../features/settings/privacy_policy_page.dart';
import '../features/settings/user_guide_page.dart';
import '../features/admin/admin_users_page.dart';

/// Auth状态的Listenable包装，用于GoRouter refreshListenable
class AuthListenable extends ChangeNotifier {
  final Ref _ref;

  AuthListenable(this._ref) {
    _ref.listen(authStateProvider, (previous, next) {
      notifyListeners();
    });
  }
}

final authListenableProvider = Provider<AuthListenable>((ref) {
  return AuthListenable(ref);
});

final routerProvider = Provider<GoRouter>((ref) {
  final authListenable = ref.read(authListenableProvider);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: authListenable,
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      final isLoggedIn = auth.isAuthenticated;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation == '/forgot-password';

      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && isAuthRoute) return '/';
      return null;
    },
    routes: [
      // Auth routes
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterPage()),
      GoRoute(path: '/forgot-password', builder: (_, _) => const ForgotPasswordPage()),

      // Main shell with bottom navigation
      ShellRoute(
        builder: (_, _, child) => HomeShell(child: child),
        routes: [
          GoRoute(path: '/', builder: (_, _) => const DashboardPage()),
          GoRoute(path: '/assets', builder: (_, _) => const AssetListPage()),
          GoRoute(path: '/finance', builder: (_, _) => const FireDashboardPage()),
          GoRoute(path: '/documents', builder: (_, _) => const DocumentListPage()),
          GoRoute(path: '/mine', builder: (_, _) => const ProfilePage()),
        ],
      ),

      // Asset routes — 静态路径必须在 :id 之前
      GoRoute(path: '/assets/create', builder: (_, _) => const AssetEditPage()),
      GoRoute(path: '/assets/filter', builder: (_, _) => const AssetFilterPage()),
      GoRoute(path: '/assets/scan', builder: (_, _) => const ScanPage()),
      GoRoute(path: '/assets/insurance-gaps', builder: (_, _) => const InsuranceGapsPage()),
      GoRoute(path: '/assets/categories', builder: (_, _) => const CategoryManagePage()),
      GoRoute(path: '/assets/:id', builder: (_, state) => AssetDetailPage(assetId: state.pathParameters['id']!)),
      GoRoute(path: '/assets/:id/edit', builder: (_, state) => AssetEditPage(assetId: state.pathParameters['id'])),
      GoRoute(path: '/assets/:id/relationships', builder: (_, state) => RelationshipPage(assetId: state.pathParameters['id']!)),
      GoRoute(path: '/assets/:id/consumable', builder: (_, state) => ConsumablePage(assetId: state.pathParameters['id']!)),
      GoRoute(path: '/assets/:id/trade', builder: (_, state) => TradePage(assetId: state.pathParameters['id']!)),

      // Finance
      GoRoute(path: '/finance/liabilities', builder: (_, _) => const LiabilityPage()),
      GoRoute(path: '/finance/budget', builder: (_, _) => const MonthlyBudgetPage()),
      GoRoute(path: '/finance/budget-templates', builder: (_, _) => const BudgetTemplatesPage()),
      GoRoute(path: '/finance/yearly-stats', builder: (_, _) => const YearlyStatsPage()),
      GoRoute(path: '/finance/portfolio', builder: (_, _) => const PortfolioPage()),
      GoRoute(path: '/finance/price/:assetId', builder: (_, state) => PriceChartPage(assetId: state.pathParameters['assetId']!)),
      GoRoute(path: '/finance/monte-carlo', builder: (_, _) => const MonteCarloPage()),
      GoRoute(path: '/finance/cost-basis/:assetId', builder: (_, state) => CostBasisPage(assetId: state.pathParameters['assetId']!)),
      GoRoute(path: '/finance/passive-income', builder: (_, _) => const PassiveIncomePage()),

      // Documents
      GoRoute(path: '/documents/upload', builder: (_, _) => const UploadPage()),
      GoRoute(path: '/documents/:id/pdf', builder: (_, state) => PdfViewerPage(documentId: state.pathParameters['id']!)),
      GoRoute(path: '/documents/:id/image', builder: (_, state) => ImageViewerPage(documentId: state.pathParameters['id']!)),

      // Notifications
      GoRoute(path: '/notifications', builder: (_, _) => const NotificationListPage()),
      GoRoute(path: '/notifications/settings', builder: (_, _) => const NotificationSettingsPage()),

      // Family
      GoRoute(path: '/family', builder: (_, _) => const FamilyListPage()),
      GoRoute(path: '/family/:id', builder: (_, state) => FamilyDetailPage(familyId: state.pathParameters['id']!)),
      GoRoute(path: '/family/:id/invite', builder: (_, state) => InvitePage(familyId: state.pathParameters['id']!, inviteCode: state.extra as String?)),

      // Settings
      GoRoute(path: '/settings', builder: (_, _) => const SettingsPage()),
      GoRoute(path: '/settings/terms', builder: (_, _) => const TermsPage()),
      GoRoute(path: '/settings/privacy', builder: (_, _) => const PrivacyPolicyPage()),
      GoRoute(path: '/settings/guide', builder: (_, _) => const UserGuidePage()),

      // Admin
      GoRoute(path: '/admin/users', builder: (_, _) => const AdminUsersPage()),
    ],
  );
});
