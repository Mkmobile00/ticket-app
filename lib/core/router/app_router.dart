import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/account/account_screen.dart';
import '../../features/account/change_password_screen.dart';
import '../../features/auth/forgot_password_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/auth/splash_screen.dart';
import '../../features/auth/verify_email_screen.dart';
import '../../features/bookings/bookings_screen.dart';
import '../../features/bookings/ticket_screen.dart';
import '../../features/checkout/checkout_screen.dart';
import '../../features/checkout/payment_webview_screen.dart';
import '../../features/common/web_view_screen.dart';
import '../../features/events/event_detail_screen.dart';
import '../../features/events/events_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/home/search_screen.dart';
import '../../features/common/trailer_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/movies/movie_detail_screen.dart';
import '../../features/movies/movies_list_screen.dart';
import '../../features/movies/showtimes_screen.dart';
import '../../features/seats/seat_map_screen.dart';
import '../../features/sports/sport_detail_screen.dart';
import '../../features/sports/sports_screen.dart';
import '../../providers/providers.dart';
import '../theme/app_theme.dart';

final _rootKey = rootNavigatorKey;
final _shellKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

/// Routes that require a logged-in user. Everything else is open to guests.
bool _isProtected(String loc) =>
    loc.startsWith('/bookings') ||
    loc.startsWith('/account') ||
    loc.startsWith('/checkout') ||
    loc.startsWith('/ticket');

/// The app router; rebuilds its redirect whenever auth state changes.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final status = ref.read(authProvider).status;
      final loc = state.matchedLocation;

      // Still reading the saved token → wait on splash.
      if (status == AuthStatus.unknown) {
        return loc == '/splash' ? null : '/splash';
      }
      // Once known, leave splash for the home feed (guests welcome).
      if (loc == '/splash') return '/home';

      final authed = status == AuthStatus.authenticated;

      // Signed in but email not verified → force the verification screen.
      if (authed && ref.read(authProvider).user?.emailVerified == false) {
        return loc == '/verify-email' ? null : '/verify-email';
      }
      // Verified users should never sit on the verify screen.
      if (authed && loc == '/verify-email') return '/home';

      // Guests may browse everything except personal/booking areas.
      if (!authed && _isProtected(loc)) return '/login';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/forgot', builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(path: '/verify-email', builder: (_, __) => const VerifyEmailScreen()),

      // Bottom-nav shell.
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => _HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(navigatorKey: _shellKey, routes: [
            GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/movies', builder: (_, __) => const MoviesListScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/bookings', builder: (_, __) => const BookingsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/account', builder: (_, __) => const AccountScreen()),
          ]),
        ],
      ),

      // Full-screen flow routes (over the bottom nav).
      GoRoute(path: '/search', parentNavigatorKey: _rootKey, builder: (_, __) => const SearchScreen()),
      GoRoute(path: '/notifications', parentNavigatorKey: _rootKey, builder: (_, __) => const NotificationsScreen()),
      GoRoute(
        path: '/trailer',
        parentNavigatorKey: _rootKey,
        builder: (_, s) {
          final a = s.extra as TrailerArgs?;
          return a == null
              ? const Scaffold(body: Center(child: Text('Trailer unavailable')))
              : TrailerScreen(videoId: a.videoId, title: a.title);
        },
      ),
      GoRoute(
        path: '/movies/:slug',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => MovieDetailScreen(slug: s.pathParameters['slug']!),
      ),
      GoRoute(
        path: '/movies/:slug/showtimes',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => ShowtimesScreen(slug: s.pathParameters['slug']!, movieTitle: s.extra as String?),
      ),
      GoRoute(path: '/events', parentNavigatorKey: _rootKey, builder: (_, __) => const EventsScreen()),
      GoRoute(
        path: '/events/:slug',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => EventDetailScreen(slug: s.pathParameters['slug']!),
      ),
      GoRoute(path: '/sports', parentNavigatorKey: _rootKey, builder: (_, __) => const SportsScreen()),
      GoRoute(
        path: '/sports/:slug',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => SportDetailScreen(slug: s.pathParameters['slug']!),
      ),
      GoRoute(
        path: '/seats',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => s.extra is SeatArgs
            ? SeatMapScreen(args: s.extra as SeatArgs)
            : const _MissingArgs(),
      ),
      GoRoute(
        path: '/checkout',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => s.extra is CheckoutArgs
            ? CheckoutScreen(args: s.extra as CheckoutArgs)
            : const _MissingArgs(),
      ),
      GoRoute(
        path: '/payment-webview',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => s.extra is PaymentWebViewArgs
            ? PaymentWebViewScreen(args: s.extra as PaymentWebViewArgs)
            : const _MissingArgs(),
      ),
      GoRoute(
        path: '/ticket/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => TicketScreen(bookingId: int.parse(s.pathParameters['id']!)),
      ),
      GoRoute(path: '/account/password', parentNavigatorKey: _rootKey, builder: (_, __) => const ChangePasswordScreen()),
      GoRoute(
        path: '/web',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => s.extra is WebArgs
            ? WebViewScreen(args: s.extra as WebArgs)
            : const _MissingArgs(),
      ),
    ],
  );
});

/// Scaffold with the persistent bottom navigation bar.
class _HomeShell extends StatelessWidget {
  final StatefulNavigationShell shell;
  const _HomeShell({required this.shell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.accent.withValues(alpha: .2),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home, color: AppColors.accent), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.movie_outlined), selectedIcon: Icon(Icons.movie, color: AppColors.accent), label: 'Movies'),
          NavigationDestination(icon: Icon(Icons.confirmation_number_outlined), selectedIcon: Icon(Icons.confirmation_number, color: AppColors.accent), label: 'Bookings'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person, color: AppColors.accent), label: 'Account'),
        ],
      ),
    );
  }
}

/// Shown when a flow route is reached without its `extra` (e.g. after a
/// router refresh dropped it). Returns to home instead of crashing.
class _MissingArgs extends StatefulWidget {
  const _MissingArgs();
  @override
  State<_MissingArgs> createState() => _MissingArgsState();
}

class _MissingArgsState extends State<_MissingArgs> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go('/home');
    });
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.accent)));
}
