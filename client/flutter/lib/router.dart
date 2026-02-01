import 'package:go_router/go_router.dart';
import 'features/auth/connect_screen.dart';
import 'features/auth/auth_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/auth/guest_screen.dart';
import 'features/lobby/lobby_screen.dart';
import 'features/room/room_screen.dart';
import 'features/settings/settings_screen.dart';

final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const ConnectScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const AuthScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/guest',
      builder: (context, state) => const GuestScreen(),
    ),
    GoRoute(
      path: '/lobby',
      builder: (context, state) => const LobbyScreen(),
    ),
    GoRoute(
      path: '/room/:id',
      builder: (context, state) => RoomScreen(
        roomId: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);
