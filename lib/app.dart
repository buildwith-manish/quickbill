import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'presentation/providers/business_profile_providers.dart';
import 'presentation/screens/clients/client_form_screen.dart';
import 'presentation/screens/clients/client_list_screen.dart';
import 'presentation/screens/home/home_screen.dart';
import 'presentation/screens/invoices/invoice_create_screen.dart';
import 'presentation/screens/invoices/invoice_list_screen.dart';
import 'presentation/screens/invoices/invoice_preview_screen.dart';
import 'presentation/screens/onboarding/business_setup_screen.dart';
import 'presentation/screens/settings/settings_screen.dart';
import 'presentation/widgets/db_corruption_guard.dart';
import 'theme/app_theme.dart';

/// Routes that sit *inside* the bottom-nav shell (4 tabs).
final _shellBranches = <StatefulShellBranch>[
  StatefulShellBranch(
    routes: [
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
    ],
  ),
  StatefulShellBranch(
    routes: [
      GoRoute(
        path: '/invoices',
        name: 'invoices',
        builder: (context, state) => const InvoiceListScreen(),
      ),
    ],
  ),
  StatefulShellBranch(
    routes: [
      GoRoute(
        path: '/clients',
        name: 'clients',
        builder: (context, state) => const ClientListScreen(),
      ),
    ],
  ),
  StatefulShellBranch(
    routes: [
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  ),
];

/// Provider for the app's [GoRouter]. Observes the business profile to
/// redirect to onboarding when first-launch setup hasn't happened yet.
final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _ProfileListenable(ref);
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: '/home',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final profileAsync = ref.read(businessProfileControllerProvider);
      final isOnboarding = state.matchedLocation == '/onboarding';

      return profileAsync.when(
        data: (profile) {
          if (profile == null && !isOnboarding) return '/onboarding';
          if (profile != null && isOnboarding) return '/home';
          return null;
        },
        loading: () => null,
        error: (_, __) => null,
      );
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const BusinessSetupScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return _ScaffoldWithNav(navigationShell: navigationShell);
        },
        branches: _shellBranches,
      ),
      GoRoute(
        path: '/clients/new',
        name: 'client-new',
        builder: (context, state) => const ClientFormScreen(clientId: null),
      ),
      GoRoute(
        path: '/clients/:id/edit',
        name: 'client-edit',
        builder: (context, state) => ClientFormScreen(
          clientId: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        path: '/invoices/new',
        name: 'invoice-new',
        builder: (context, state) => const InvoiceCreateScreen(invoiceId: null),
      ),
      GoRoute(
        path: '/invoices/:id/edit',
        name: 'invoice-edit',
        builder: (context, state) => InvoiceCreateScreen(
          invoiceId: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        path: '/invoices/:id/preview',
        name: 'invoice-preview',
        builder: (context, state) => InvoicePreviewScreen(
          invoiceId: state.pathParameters['id']!,
        ),
      ),
    ],
  );
});

class _ScaffoldWithNav extends StatelessWidget {
  const _ScaffoldWithNav({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (i) => navigationShell.goBranch(
          i,
          initialLocation: i == navigationShell.currentIndex,
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long),
            label: 'Invoices',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: 'Clients',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

/// Adapter that turns the Riverpod business-profile state into a
/// [Listenable] for go_router's `refreshListenable`.
///
/// The listen subscription is tied to the [routerProvider]'s lifecycle
/// (auto-disposed when the provider disposes) — no manual close needed.
class _ProfileListenable extends ChangeNotifier {
  _ProfileListenable(this._ref) {
    _ref.listen(
      businessProfileControllerProvider,
      (_, __) => notifyListeners(),
    );
  }

  final Ref _ref;
}

class InvoryApp extends ConsumerWidget {
  const InvoryApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Invory',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('hi'),
      ],
      builder: (context, child) =>
          DbCorruptionGuard(child: child ?? const SizedBox()),
      routerConfig: router,
    );
  }
}
