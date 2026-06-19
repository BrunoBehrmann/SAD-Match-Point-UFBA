import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../providers/app_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/cadastro_screen.dart';
import '../screens/events/eventos_screen.dart';
import '../screens/events/evento_detalhe_screen.dart';
import '../screens/events/criar_evento_screen.dart';
import '../screens/events/editar_evento_screen.dart';
import '../screens/events/meus_eventos_screen.dart';
import '../screens/profile/perfil_screen.dart';
import '../screens/profile/editar_perfil_screen.dart';
import '../screens/conta_atletica/gerenciar_atletica_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../widgets/main_scaffold.dart';

final _rootKey = GlobalKey<NavigatorState>();

GoRouter buildRouter(AppProvider provider) => GoRouter(
      navigatorKey: _rootKey,
      refreshListenable: provider,
      redirect: (context, state) {
        final autenticado = provider.autenticado;
        final perfilCompleto = provider.perfilCompleto;
        final carregando = provider.carregando;
        final path = state.matchedLocation;

        // Aguarda o perfil carregar antes de redirecionar
        if (autenticado && carregando) return null;

        if (!autenticado && path != '/login') return '/login';
        if (autenticado && !perfilCompleto && path != '/cadastro') {
          return '/cadastro';
        }
        if (autenticado && perfilCompleto && (path == '/login' || path == '/cadastro')) return '/';
        return null;
      },
      routes: [
        GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
        GoRoute(path: '/cadastro', builder: (context, state) => const CadastroScreen()),
        ShellRoute(
          builder: (context, state, child) => MainScaffold(child: child),
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const EventosScreen(),
            ),
            GoRoute(
              path: '/criar-evento',
              builder: (context, state) => const CriarEventoScreen(),
            ),
            GoRoute(
              path: '/meus-eventos',
              builder: (context, state) => const MeusEventosScreen(),
            ),
            GoRoute(
              path: '/perfil',
              builder: (context, state) => const PerfilScreen(),
            ),
          ],
        ),
        GoRoute(
          path: '/evento/:id',
          builder: (context, state) =>
              EventoDetalheScreen(eventoId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/editar-evento/:id',
          builder: (context, state) =>
              EditarEventoScreen(eventoId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/editar-perfil',
          builder: (context, state) => const EditarPerfilScreen(),
        ),
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/gerenciar-atletica',
          builder: (context, state) => const GerenciarAtleticaScreen(),
        ),
      ],
    );
