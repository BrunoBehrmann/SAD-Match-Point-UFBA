import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/evento.dart';
import '../../providers/app_provider.dart';
import '../../services/firestore_service.dart';
import '../../utils/viabilidade.dart';
import '../../widgets/evento_card.dart';

class MeusEventosScreen extends StatefulWidget {
  const MeusEventosScreen({super.key});

  @override
  State<MeusEventosScreen> createState() => _MeusEventosScreenState();
}

class _MeusEventosScreenState extends State<MeusEventosScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _db = FirestoreService();

  @override
  void initState() {
    super.initState();
    final provider = context.read<AppProvider>();
    _tabController = TabController(
      length: provider.isGestor ? 2 : 1,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final uid = provider.currentUid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus Eventos'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            const Tab(text: 'Confirmados'),
            if (provider.isGestor) const Tab(text: 'Criados'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _EventosList(
            stream: uid != null ? _db.streamEventosConfirmados(uid) : const Stream.empty(),
            permitirExcluir: false,
            db: _db,
          ),
          if (provider.isGestor)
            _EventosList(
              stream: uid != null ? _db.streamEventosCriados(uid) : const Stream.empty(),
              permitirExcluir: true,
              mostrarPainel: true,
              db: _db,
            ),
        ],
      ),
    );
  }
}

class _EventosList extends StatelessWidget {
  final Stream<List<Evento>> stream;
  final bool permitirExcluir;
  final FirestoreService db;
  final bool mostrarPainel;

  const _EventosList({
    required this.stream,
    required this.permitirExcluir,
    required this.db,
    this.mostrarPainel = false,
  });

  Future<void> _confirmarExclusao(BuildContext context, Evento evento) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir evento'),
        content: Text('Deseja excluir o evento "${evento.nome}" permanentemente? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await db.excluirEvento(evento.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Evento excluído.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Evento>>(
        stream: stream,
        builder: (ctx, snap) {
          if (snap.hasError) {
            return const Center(child: Text('Erro ao carregar eventos.'));
          }
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final eventos = snap.data ?? [];
          if (eventos.isEmpty) {
            return const Center(child: Text('Nenhum evento aqui ainda.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: eventos.length + (mostrarPainel ? 1 : 0),
            itemBuilder: (_, i) {
              if (mostrarPainel && i == 0) {
                return _PainelGestor(eventos: eventos);
              }
              final evento = eventos[mostrarPainel ? i - 1 : i];
              if (!permitirExcluir) return EventoCard(evento: evento);
              return Dismissible(
                key: ValueKey(evento.id),
                direction: DismissDirection.endToStart,
                confirmDismiss: (_) async {
                  await _confirmarExclusao(context, evento);
                  return false;
                },
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.delete_outline,
                      color: Colors.white, size: 28),
                ),
                child: EventoCard(evento: evento),
              );
            },
          );
        },
      );
}

class _PainelGestor extends StatefulWidget {
  final List<Evento> eventos;
  const _PainelGestor({required this.eventos});

  @override
  State<_PainelGestor> createState() => _PainelGestorState();
}

class _PainelGestorState extends State<_PainelGestor> {
  bool _expandido = true;

  @override
  Widget build(BuildContext context) {
    final eventos = widget.eventos;
    final abertos =
        eventos.where((e) => e.status == EventStatus.aberto).toList();
    final encerrados =
        eventos.where((e) => e.status == EventStatus.encerrado).toList();
    final cancelados =
        eventos.where((e) => e.status == EventStatus.cancelado).toList();

    // Taxa de comparecimento dos encerrados
    int totalConfirmacoes = 0;
    int totalCheckIns = 0;
    for (final e in encerrados) {
      totalConfirmacoes += e.confirmados.length;
      totalCheckIns += e.confirmados.where((c) => c.checkInRealizado).length;
    }
    final taxaComp = totalConfirmacoes > 0
        ? totalCheckIns / totalConfirmacoes
        : null;

    // Evento aberto com menor viabilidade
    Evento? eventoAtencao;
    if (abertos.isNotEmpty) {
      eventoAtencao = abertos.reduce((a, b) =>
          a.indiceViabilidade < b.indiceViabilidade ? a : b);
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header colapsável
          InkWell(
            onTap: () => setState(() => _expandido = !_expandido),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  const Icon(Icons.dashboard_outlined,
                      color: Color(0xFF94A3B8), size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Painel do Gestor',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    _expandido
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: const Color(0xFF94A3B8),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          if (_expandido) ...[
            const Divider(height: 1, color: Color(0xFF1E293B)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Contadores de status
                  Row(
                    children: [
                      _ContadorChip(
                          valor: abertos.length,
                          label: 'Abertos',
                          cor: const Color(0xFF22C55E)),
                      const SizedBox(width: 8),
                      _ContadorChip(
                          valor: encerrados.length,
                          label: 'Encerrados',
                          cor: const Color(0xFF94A3B8)),
                      const SizedBox(width: 8),
                      _ContadorChip(
                          valor: cancelados.length,
                          label: 'Cancelados',
                          cor: const Color(0xFFEF4444)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Taxa de comparecimento
                  _MetricaLinha(
                    icone: Icons.trending_up,
                    label: 'Taxa de comparecimento',
                    valor: taxaComp == null
                        ? 'Sem eventos encerrados'
                        : '${(taxaComp * 100).toStringAsFixed(0)}%',
                    corValor: taxaComp == null
                        ? const Color(0xFF94A3B8)
                        : taxaComp >= 0.7
                            ? const Color(0xFF22C55E)
                            : taxaComp >= 0.4
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFFEF4444),
                  ),

                  // Evento de atenção
                  if (eventoAtencao != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            classificarViabilidade(
                                        eventoAtencao.indiceViabilidade) ==
                                    NivelViabilidade.baixa
                                ? Icons.warning_amber_rounded
                                : Icons.info_outline,
                            color: classificarViabilidade(
                                        eventoAtencao.indiceViabilidade) ==
                                    NivelViabilidade.baixa
                                ? const Color(0xFFEF4444)
                                : const Color(0xFFF59E0B),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '"${eventoAtencao.nome}" precisa de atenção',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Viabilidade: ${(eventoAtencao.indiceViabilidade * 100).round()}% — '
                                  '${eventoAtencao.confirmados.length}/${eventoAtencao.minimoJogadores} confirmados',
                                  style: const TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ContadorChip extends StatelessWidget {
  final int valor;
  final String label;
  final Color cor;
  const _ContadorChip(
      {required this.valor, required this.label, required this.cor});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: cor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: cor.withValues(alpha: 0.25)),
          ),
          child: Column(
            children: [
              Text(
                '$valor',
                style: TextStyle(
                  color: cor,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: cor.withValues(alpha: 0.8),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
}

class _MetricaLinha extends StatelessWidget {
  final IconData icone;
  final String label;
  final String valor;
  final Color corValor;
  const _MetricaLinha(
      {required this.icone,
      required this.label,
      required this.valor,
      required this.corValor});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icone, color: const Color(0xFF64748B), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 12,
              ),
            ),
          ),
          Text(
            valor,
            style: TextStyle(
              color: corValor,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
}
