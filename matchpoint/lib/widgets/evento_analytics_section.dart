import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../models/evento.dart';
import '../services/firestore_service.dart';
import 'charts/match_point_charts.dart';

/// Seção de analytics visível apenas para gestores no detalhe do evento.
/// Exibe distribuição de confirmados por atlética/curso, quórum, materiais
/// e taxa de check-in (quando encerrado).
class EventoAnalyticsSection extends StatefulWidget {
  final Evento evento;

  const EventoAnalyticsSection({super.key, required this.evento});

  @override
  State<EventoAnalyticsSection> createState() =>
      _EventoAnalyticsSectionState();
}

class _EventoAnalyticsSectionState extends State<EventoAnalyticsSection> {
  bool _expandido = false;
  Future<List<AppUser>>? _usuariosFuture;

  void _toggle() {
    setState(() {
      _expandido = !_expandido;
      if (_expandido && _usuariosFuture == null) {
        final ids =
            widget.evento.confirmados.map((c) => c.usuarioId).toList();
        _usuariosFuture = FirestoreService().getUsuariosBatch(ids);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final evento = widget.evento;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Column(
        children: [
          // ── Cabeçalho clicável ──────────────────────────────────
          InkWell(
            onTap: _toggle,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.analytics_outlined,
                        size: 17, color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Análise do Evento',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color(0xFF1E40AF),
                      ),
                    ),
                  ),
                  Icon(
                    _expandido
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: const Color(0xFF2563EB),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // ── Conteúdo expandido ─────────────────────────────────
          if (_expandido) ...[
            const Divider(height: 1, color: Color(0xFFBFDBFE)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quórum
                  _buildQuorum(evento),
                  const SizedBox(height: 14),

                  // Materiais
                  if (evento.materiaisNecessarios.isNotEmpty) ...[
                    _buildMateriais(evento),
                    const SizedBox(height: 14),
                  ],

                  // Taxa de check-in (se encerrado)
                  if (evento.status == EventStatus.encerrado) ...[
                    _buildTaxaCheckIn(evento),
                    const SizedBox(height: 14),
                  ],

                  // Distribuições por atletica/curso (lazy)
                  if (evento.confirmados.isNotEmpty) ...[
                    FutureBuilder<List<AppUser>>(
                      future: _usuariosFuture,
                      builder: (ctx, snap) {
                        if (!snap.hasData) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                                child: CircularProgressIndicator(
                                    strokeWidth: 2)),
                          );
                        }
                        final usuarios = snap.data!;
                        return _buildDistribuicoes(evento, usuarios);
                      },
                    ),
                  ] else
                    const _EmptyState(
                        text: 'Nenhuma confirmação ainda — sem dados.'),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuorum(Evento evento) {
    final confirmados = evento.confirmados.length;
    final minimo = evento.minimoJogadores;
    final progress = minimo > 0 ? (confirmados / minimo).clamp(0.0, 1.0) : 1.0;
    final atingiu = confirmados >= minimo;

    return MpProgressBar(
      label: 'Quórum ($confirmados confirmados / mínimo $minimo)',
      value: progress,
      color: atingiu ? const Color(0xFF22C55E) : const Color(0xFFF59E0B),
      trailingText: atingiu ? '✓ Atingido' : '$confirmados/$minimo',
    );
  }

  Widget _buildMateriais(Evento evento) {
    final necessarios = evento.materiaisNecessarios;
    final cobertos = necessarios.where((m) {
      return evento.confirmados
          .any((c) => c.materiaisQueVaiLevar.any((ml) =>
              ml.toLowerCase().contains(m.toLowerCase()) ||
              m.toLowerCase().contains(ml.toLowerCase())));
    }).toList();
    final cobertura =
        necessarios.isNotEmpty ? cobertos.length / necessarios.length : 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MpProgressBar(
          label: 'Cobertura de materiais',
          value: cobertura,
          color: cobertura >= 1.0
              ? const Color(0xFF22C55E)
              : cobertura >= 0.5
                  ? const Color(0xFFF59E0B)
                  : const Color(0xFFEF4444),
          trailingText: '${cobertos.length}/${necessarios.length}',
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: necessarios.map((m) {
            final temAlguem = cobertos.contains(m);
            return Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: temAlguem
                    ? const Color(0xFFF0FDF4)
                    : const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: temAlguem
                      ? const Color(0xFF86EFAC)
                      : const Color(0xFFFBBF24),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    temAlguem ? Icons.check_circle_outline : Icons.warning_amber,
                    size: 12,
                    color: temAlguem
                        ? const Color(0xFF22C55E)
                        : const Color(0xFFF59E0B),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    m,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: temAlguem
                          ? const Color(0xFF166534)
                          : const Color(0xFF92400E),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTaxaCheckIn(Evento evento) {
    final total = evento.confirmados.length;
    final checks =
        evento.confirmados.where((c) => c.checkInRealizado).length;
    final taxa = total > 0 ? checks / total : 0.0;

    return MpProgressBar(
      label: 'Taxa de comparecimento real',
      value: taxa,
      color: taxa >= 0.7
          ? const Color(0xFF22C55E)
          : taxa >= 0.4
              ? const Color(0xFFF59E0B)
              : const Color(0xFFEF4444),
      trailingText: '$checks/$total apareceram',
    );
  }

  Widget _buildDistribuicoes(Evento evento, List<AppUser> usuarios) {
    // Mapa userId → AppUser para lookup rápido
    final userMap = {for (final u in usuarios) u.id: u};

    // Distribuição por atlética
    final Map<String, int> porAtletica = {};
    // Distribuição por curso
    final Map<String, int> porCurso = {};

    for (final conf in evento.confirmados) {
      final user = userMap[conf.usuarioId];
      if (user != null) {
        final atic = user.atleticaId.isNotEmpty ? user.atleticaId : 'Sem atlética';
        porAtletica[atic] = (porAtletica[atic] ?? 0) + 1;

        final curso = user.curso.isNotEmpty ? user.curso : 'Não informado';
        porCurso[curso] = (porCurso[curso] ?? 0) + 1;
      }
    }

    // Confiabilidade média do grupo
    final taxaMedia = evento.confirmados.isEmpty
        ? 0.0
        : evento.confirmados
                .map((c) => c.taxaConfiabilidade)
                .reduce((a, b) => a + b) /
            evento.confirmados.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Confiabilidade média
        _SubSectionLabel(text: 'Confiabilidade média do grupo'),
        const SizedBox(height: 8),
        MpProgressBar(
          label: 'Taxa média de comparecimento histórico',
          value: taxaMedia,
          color: taxaMedia >= 0.7
              ? const Color(0xFF22C55E)
              : taxaMedia >= 0.4
                  ? const Color(0xFFF59E0B)
                  : const Color(0xFFEF4444),
        ),
        const SizedBox(height: 16),

        // Por atlética
        if (porAtletica.length > 1) ...[
          _SubSectionLabel(text: 'Confirmados por atlética'),
          const SizedBox(height: 10),
          _ChartBox(
            child: MpPieChart(
              data: _mapToPie(porAtletica),
              size: 100,
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Por curso
        if (porCurso.length > 1) ...[
          _SubSectionLabel(text: 'Confirmados por curso'),
          const SizedBox(height: 10),
          _ChartBox(
            child: MpPieChart(
              data: _mapToPie(porCurso),
              size: 100,
            ),
          ),
        ] else if (porCurso.length == 1) ...[
          _SubSectionLabel(text: 'Curso dos confirmados'),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                    color: Color(0xFF2563EB), shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  porCurso.keys.first,
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF475569)),
                ),
              ),
              Text(
                '${porCurso.values.first} confirmado(s)',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A)),
              ),
            ],
          ),
        ],
      ],
    );
  }

  static List<PieChartItem> _mapToPie(Map<String, int> data) {
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

class _SubSectionLabel extends StatelessWidget {
  final String text;
  const _SubSectionLabel({required this.text});

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF64748B),
          letterSpacing: 0.8,
        ),
      );
}

class _ChartBox extends StatelessWidget {
  final Widget child;
  const _ChartBox({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: const Border.fromBorderSide(
              BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: child,
      );
}

class _EmptyState extends StatelessWidget {
  final String text;
  const _EmptyState({required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.info_outline,
                size: 15, color: Color(0xFF94A3B8)),
            const SizedBox(width: 6),
            Text(text,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF94A3B8))),
          ],
        ),
      );
}
