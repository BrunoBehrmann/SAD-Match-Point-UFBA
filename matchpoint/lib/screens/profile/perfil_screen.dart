import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/app_user.dart';
import '../../providers/app_provider.dart';
import '../../services/firestore_service.dart';
import '../../utils/constants.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final usuario = provider.usuario;
    final atletica = provider.atletica;
    final semAtletica = usuario == null || usuario.atleticaId == kSemAtleticaId;

    if (usuario == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final iniciais = _iniciais(usuario.nome);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: [
              // Header escuro
              Container(
                color: const Color(0xFF0F172A),
                child: Column(
                  children: [
                    SizedBox(
                        height:
                            MediaQuery.of(context).padding.top + 12),
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          const SizedBox(width: 40),
                          const Text(
                            'Perfil',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Row(
                            children: [
                              _HeaderAction(
                                icon: Icons.edit_outlined,
                                onTap: () =>
                                    context.push('/editar-perfil'),
                              ),
                              if (provider.isGestor) ...[
                                const SizedBox(width: 4),
                                _HeaderAction(
                                  icon: Icons.dashboard_outlined,
                                  onTap: () =>
                                      context.push('/dashboard'),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: const Color(0xFF2563EB),
                      child: Text(
                        iniciais,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      usuario.nome,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (usuario.curso.isNotEmpty) usuario.curso,
                        if (!semAtletica && atletica != null)
                          atletica.nome,
                      ].join(' · '),
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 13,
                      ),
                    ),
                    if (provider.isGestor)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB)
                              .withValues(alpha:0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: const Color(0xFF2563EB)
                                  .withValues(alpha:0.5)),
                        ),
                        child: const Text(
                          'Gestor',
                          style: TextStyle(
                            color: Color(0xFF93C5FD),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),

              // Conteúdo
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Acesso destacado ao dashboard (gestores)
                    if (provider.isGestor) ...[
                      _DashboardCard(
                        onTap: () => context.push('/dashboard'),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Cards de stats
                    const Text(
                      'ESTATÍSTICAS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            icon: Icons.local_fire_department,
                            iconColor: const Color(0xFFF97316),
                            bgColor: const Color(0xFFFFF7ED),
                            valor:
                                '${usuario.streakPresencas}',
                            label: 'Seguidos',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.check_circle_outline,
                            iconColor: const Color(0xFF2563EB),
                            bgColor: const Color(0xFFEFF6FF),
                            valor:
                                '${usuario.totalComparecimentos}',
                            label: 'Presenças',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Ranking
                    Row(
                      children: [
                        const Text(
                          'RANKING',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF94A3B8),
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => _mostrarInfoRanking(context),
                          child: const Icon(Icons.info_outline,
                              size: 14, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _RankingTabs(
                      tabController: _tabController,
                      atleticaId: usuario.atleticaId,
                      semAtletica: semAtletica,
                      onVincular: () => context.push('/editar-perfil'),
                    ),

                    const SizedBox(height: 24),

                    // Sair
                    OutlinedButton.icon(
                      onPressed: () => provider.signOut(),
                      icon: const Icon(Icons.logout,
                          color: Color(0xFFEF4444), size: 18),
                      label: const Text('Sair da conta'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFEF4444),
                        side: const BorderSide(
                            color: Color(0xFFFEE2E2)),
                        backgroundColor: const Color(0xFFFEF2F2),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _iniciais(String nome) {
    final partes = nome.trim().split(' ');
    if (partes.length >= 2) {
      return '${partes[0][0]}${partes[1][0]}'.toUpperCase();
    }
    return nome.isNotEmpty ? nome[0].toUpperCase() : '?';
  }

  void _mostrarInfoRanking(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Como funciona o ranking'),
        content: const Text(
          'Sua pontuação combina dois fatores:\n\n'
          '• 70% — taxa de presença (quanto você comparece dos eventos '
          'que confirma)\n'
          '• 30% — volume de comparecimentos (total de presenças '
          'em relação a quem mais comparece na atlética)\n\n'
          'Confirme presença e apareça nos eventos para subir no ranking. '
          'Faltar a um evento confirmado reduz sua taxa.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
  }
}

// Card de acesso ao dashboard, destacado para gestores
class _DashboardCard extends StatelessWidget {
  final VoidCallback onTap;
  const _DashboardCard({required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.bar_chart_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Painel do gestor',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Métricas, comparecimento e alertas da atlética',
                        style: TextStyle(
                          color: Color(0xFFBFDBFE),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios,
                    color: Colors.white, size: 16),
              ],
            ),
          ),
        ),
      );
}

class _HeaderAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HeaderAction({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha:0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      );
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String valor;
  final String label;
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.valor,
    required this.label,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.fromBorderSide(
              BorderSide(color: iconColor.withValues(alpha:0.15))),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha:0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              valor,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: iconColor,
              ),
            ),
          ],
        ),
      );
}

class _RankingTabs extends StatelessWidget {
  final TabController tabController;
  final String atleticaId;
  final bool semAtletica;
  final VoidCallback onVincular;

  const _RankingTabs({
    required this.tabController,
    required this.atleticaId,
    required this.semAtletica,
    required this.onVincular,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: const Border.fromBorderSide(
            BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: const BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: TabBar(
              controller: tabController,
              labelColor: const Color(0xFF2563EB),
              unselectedLabelColor: const Color(0xFF94A3B8),
              indicatorColor: const Color(0xFF2563EB),
              indicatorSize: TabBarIndicatorSize.tab,
              labelStyle: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 13),
              unselectedLabelStyle:
                  const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              tabs: const [
                Tab(text: 'Atlética'),
                Tab(text: 'Geral'),
              ],
            ),
          ),
          SizedBox(
            height: 320,
            child: TabBarView(
              controller: tabController,
              children: [
                semAtletica
                    ? _SemAtleticaPlaceholder(onVincular: onVincular)
                    : _RankingList(
                        future: FirestoreService()
                            .getRankingAtletica(atleticaId),
                      ),
                _RankingList(
                  future: FirestoreService().getRankingGeral(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SemAtleticaPlaceholder extends StatelessWidget {
  final VoidCallback onVincular;
  const _SemAtleticaPlaceholder({required this.onVincular});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.info_outline,
                color: Color(0xFF94A3B8), size: 18),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Vincule-se a uma atlética para ver o ranking.',
                style:
                    TextStyle(color: Color(0xFF64748B), fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: onVincular,
              style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact),
              child: const Text('Vincular'),
            ),
          ],
        ),
      );
}

class _RankingList extends StatelessWidget {
  final Future<List<AppUser>> future;
  const _RankingList({required this.future});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AppUser>>(
      future: future,
      builder: (ctx, snap) {
        if (snap.hasError) {
          return const Center(child: Text('Erro ao carregar ranking.'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final lista = snap.data!;
        if (lista.isEmpty) {
          return const Center(
              child: Text('Nenhum participante no ranking ainda.'));
        }
        return ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: lista.length,
          itemBuilder: (_, i) {
            final user = lista[i];
            final medalha = i == 0
                ? const Color(0xFFEAB308)
                : i == 1
                    ? const Color(0xFF94A3B8)
                    : i == 2
                        ? const Color(0xFFB45309)
                        : null;
            return ListTile(
              dense: true,
              leading: CircleAvatar(
                backgroundColor: medalha ?? const Color(0xFFF1F5F9),
                child: Text(
                  '${i + 1}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: medalha != null
                        ? Colors.white
                        : const Color(0xFF64748B),
                  ),
                ),
              ),
              title: Text(user.nome,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: Text('${user.totalComparecimentos} presenças',
                  style: const TextStyle(fontSize: 12)),
              trailing: Text(
                '${(user.taxaConfiabilidade * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: Color(0xFF22C55E),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
