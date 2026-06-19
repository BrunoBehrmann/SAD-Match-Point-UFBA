import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/app_user.dart';
import '../../providers/app_provider.dart';
import '../../services/firestore_service.dart';
import '../../widgets/charts/match_point_charts.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final usuario = provider.usuario;
    final atletica = provider.atletica;

    if (usuario == null || !provider.isGestor) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dashboard')),
        body: const Center(child: Text('Acesso restrito a gestores.')),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: FutureBuilder<Map<String, dynamic>>(
          future:
              FirestoreService().getDashboardDetalhado(usuario.atleticaId),
          builder: (ctx, snap) {
            return CustomScrollView(
              slivers: [
                // ── Cabeçalho escuro ──────────────────────────────────
                SliverToBoxAdapter(
                  child: _DashboardHeader(
                    usuario: usuario,
                    atleticaNome: atletica?.nome,
                    onGerenciar: () =>
                        context.push('/gerenciar-atletica'),
                    onBack: () => context.pop(),
                  ),
                ),

                if (!snap.hasData)
                  const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate(
                        _buildBody(context, snap.data!, usuario),
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildBody(
      BuildContext context, Map<String, dynamic> data, AppUser usuario) {
    final faltas = data['faltasConsecutivas'] as int;
    final totalEventos = data['totalEventos'] as int;
    final abertos = data['eventosAbertos'] as int;
    final encerrados = data['eventosEncerrados'] as int;
    final cancelados = data['eventosCancelados'] as int;
    final taxa = data['taxaComparecimento'] as double;
    final porEsporte = data['porEsporte'] as Map<String, int>;
    final eventosRecentes =
        data['eventosRecentes'] as List<Map<String, dynamic>>;
    final topJogadores = data['topJogadores'] as List<AppUser>;
    final totalAtletas = data['totalAtletas'] as int;

    return [
      // ── Alerta W.O. ───────────────────────────────────────────────
      if (faltas >= 2) ...[
        _WoAlertCard(faltas: faltas),
        const SizedBox(height: 16),
      ],

      // ── Métricas ─────────────────────────────────────────────────
      const _SectionLabel(text: 'VISÃO GERAL'),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: MpMetricCard(
              icon: Icons.event_outlined,
              iconColor: const Color(0xFF2563EB),
              bgColor: const Color(0xFFEFF6FF),
              value: '$totalEventos',
              label: 'Total eventos',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: MpMetricCard(
              icon: Icons.event_available_outlined,
              iconColor: const Color(0xFF22C55E),
              bgColor: const Color(0xFFF0FDF4),
              value: '$abertos',
              label: 'Abertos',
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: MpMetricCard(
              icon: Icons.trending_up,
              iconColor: const Color(0xFF8B5CF6),
              bgColor: const Color(0xFFF5F3FF),
              value: '${(taxa * 100).toStringAsFixed(0)}%',
              label: 'Comparecimento',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: MpMetricCard(
              icon: Icons.people_outlined,
              iconColor: const Color(0xFFF97316),
              bgColor: const Color(0xFFFFF7ED),
              value: '$totalAtletas',
              label: 'Atletas',
            ),
          ),
        ],
      ),

      if (cancelados > 0) ...[
        const SizedBox(height: 10),
        _InfoChip(
          icon: Icons.cancel_outlined,
          text: '$cancelados evento(s) cancelado(s)',
          color: const Color(0xFFEF4444),
        ),
      ],

      const SizedBox(height: 24),

      // ── Distribuição por esporte ──────────────────────────────────
      if (porEsporte.isNotEmpty) ...[
        const _SectionLabel(text: 'EVENTOS POR ESPORTE'),
        const SizedBox(height: 12),
        _ChartCard(
          child: porEsporte.length == 1
              ? _UnicoCursoRow(esporte: porEsporte.keys.first, total: totalEventos)
              : MpPieChart(
                  data: _esporteToPie(porEsporte),
                  size: 120,
                ),
        ),
        const SizedBox(height: 24),
      ],

      // ── Tendência: últimos eventos ────────────────────────────────
      if (eventosRecentes.isNotEmpty) ...[
        const _SectionLabel(text: 'ÚLTIMOS EVENTOS ENCERRADOS'),
        const SizedBox(height: 12),
        _EventosRecentesCard(eventos: eventosRecentes),
        const SizedBox(height: 24),
      ],

      // ── Top jogadores ─────────────────────────────────────────────
      if (topJogadores.isNotEmpty) ...[
        const _SectionLabel(text: 'ATLETAS MAIS CONFIÁVEIS'),
        const SizedBox(height: 12),
        _TopJogadoresCard(
          jogadores: topJogadores,
          atleticaId: usuario.atleticaId,
        ),
        const SizedBox(height: 24),
      ],

      // ── Quórum médio nos eventos encerrados ────────────────────────
      if (encerrados > 0) ...[
        const _SectionLabel(text: 'RESUMO DE ENCERRAMENTO'),
        const SizedBox(height: 12),
        _ChartCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MpProgressBar(
                label: 'Taxa de comparecimento geral',
                value: taxa,
                color: taxa >= 0.7
                    ? const Color(0xFF22C55E)
                    : taxa >= 0.4
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFFEF4444),
              ),
              const SizedBox(height: 14),
              MpProgressBar(
                label: 'Eventos encerrados vs total',
                value: totalEventos > 0 ? encerrados / totalEventos : 0,
                color: const Color(0xFF8B5CF6),
                trailingText: '$encerrados/$totalEventos',
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],

      const SizedBox(height: 8),
    ];
  }

  static List<PieChartItem> _esporteToPie(Map<String, int> data) {
    final sorted = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.asMap().entries.map((e) {
      final idx = e.key % kChartPalette.length;
      return PieChartItem(
        label: e.value.key,
        value: e.value.value.toDouble(),
        color: kChartPalette[idx],
      );
    }).toList();
  }
}

// ─── Cabeçalho ────────────────────────────────────────────────────────────────

class _DashboardHeader extends StatelessWidget {
  final AppUser usuario;
  final String? atleticaNome;
  final VoidCallback onGerenciar;
  final VoidCallback onBack;

  const _DashboardHeader({
    required this.usuario,
    required this.atleticaNome,
    required this.onGerenciar,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) => Container(
        color: const Color(0xFF0F172A),
        child: Column(
          children: [
            SizedBox(height: MediaQuery.of(context).padding.top + 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: onBack,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back,
                          color: Colors.white, size: 18),
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'Painel do Gestor',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: onGerenciar,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.manage_accounts,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Nome e atlética
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: Color(0xFF2563EB),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.bar_chart_rounded,
                        color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          usuario.nome,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700),
                        ),
                        if (atleticaNome != null)
                          Text(
                            atleticaNome!,
                            style: const TextStyle(
                                color: Color(0xFF94A3B8), fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color:
                              const Color(0xFF2563EB).withValues(alpha: 0.5)),
                    ),
                    child: const Text(
                      'Gestor',
                      style: TextStyle(
                          color: Color(0xFF93C5FD),
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      );
}

// ─── Alerta W.O. ──────────────────────────────────────────────────────────────

class _WoAlertCard extends StatelessWidget {
  final int faltas;
  const _WoAlertCard({required this.faltas});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_rounded,
                  color: Color(0xFFEF4444), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Alerta W.O. — $faltas falta(s) consecutiva(s)',
                    style: const TextStyle(
                      color: Color(0xFFB91C1C),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Mais uma falta e a atlética perde o horário da quadra.',
                    style: TextStyle(
                        color: Color(0xFFEF4444), fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

// ─── Seção de eventos recentes ────────────────────────────────────────────────

class _EventosRecentesCard extends StatelessWidget {
  final List<Map<String, dynamic>> eventos;
  const _EventosRecentesCard({required this.eventos});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM', 'pt_BR');
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: const Border.fromBorderSide(
            BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        children: eventos.asMap().entries.map((entry) {
          final i = entry.key;
          final e = entry.value;
          final taxa = e['taxa'] as double;
          final confs = e['confirmados'] as int;
          final checks = e['checkIns'] as int;
          final dataHora = e['dataHora'] as DateTime;

          final corTaxa = taxa >= 0.7
              ? const Color(0xFF22C55E)
              : taxa >= 0.4
                  ? const Color(0xFFF59E0B)
                  : const Color(0xFFEF4444);

          return Column(
            children: [
              if (i > 0)
                const Divider(height: 1, indent: 16, endIndent: 16),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e['nome'] as String,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '${e['esporte']} · ${fmt.format(dataHora)}',
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$checks/$confs',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: corTaxa),
                        ),
                        Text(
                          '${(taxa * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                              fontSize: 11,
                              color: corTaxa,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ─── Top jogadores ────────────────────────────────────────────────────────────

class _TopJogadoresCard extends StatelessWidget {
  final List<AppUser> jogadores;
  final String atleticaId;
  const _TopJogadoresCard(
      {required this.jogadores, required this.atleticaId});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: const Border.fromBorderSide(
              BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: Column(
          children: jogadores.asMap().entries.map((entry) {
            final i = entry.key;
            final u = entry.value;
            final medalhaColor = i == 0
                ? const Color(0xFFEAB308)
                : i == 1
                    ? const Color(0xFF94A3B8)
                    : i == 2
                        ? const Color(0xFFB45309)
                        : null;

            return Column(
              children: [
                if (i > 0)
                  const Divider(height: 1, indent: 16, endIndent: 16),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor:
                            medalhaColor ?? const Color(0xFFF1F5F9),
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: medalhaColor != null
                                ? Colors.white
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(u.nome,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                            Text(
                              '${u.totalComparecimentos} presenças · '
                              '${u.streakPresencas}🔥',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      ),
                      _ConfiabilidadeBadge(taxa: u.taxaConfiabilidade),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      );
}

class _ConfiabilidadeBadge extends StatelessWidget {
  final double taxa;
  const _ConfiabilidadeBadge({required this.taxa});

  @override
  Widget build(BuildContext context) {
    final cor = taxa >= 0.7
        ? const Color(0xFF22C55E)
        : taxa >= 0.4
            ? const Color(0xFFF59E0B)
            : const Color(0xFFEF4444);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cor.withValues(alpha: 0.3)),
      ),
      child: Text(
        '${(taxa * 100).toStringAsFixed(0)}%',
        style: TextStyle(
            color: cor, fontSize: 12, fontWeight: FontWeight.w800),
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _ChartCard extends StatelessWidget {
  final Widget child;
  const _ChartCard({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: const Border.fromBorderSide(
              BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: child,
      );
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF94A3B8),
          letterSpacing: 1.2,
        ),
      );
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _InfoChip(
      {required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(text,
              style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w600)),
        ],
      );
}

class _UnicoCursoRow extends StatelessWidget {
  final String esporte;
  final int total;
  const _UnicoCursoRow({required this.esporte, required this.total});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
                color: Color(0xFF2563EB), shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(esporte,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13)),
          const Spacer(),
          Text('$total evento(s)',
              style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF94A3B8))),
        ],
      );
}
