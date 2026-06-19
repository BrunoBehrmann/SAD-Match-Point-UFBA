import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/atletica.dart';
import '../../models/evento.dart';
import '../../providers/app_provider.dart';
import '../../services/firestore_service.dart';
import '../../utils/constants.dart';
import '../../utils/esportes.dart';
import '../../utils/viabilidade.dart';
import '../../widgets/evento_card.dart';

class EventosScreen extends StatefulWidget {
  const EventosScreen({super.key});

  @override
  State<EventosScreen> createState() => _EventosScreenState();
}

class _EventosScreenState extends State<EventosScreen> {
  final _db = FirestoreService();

  String? _filtroEsporte;
  String? _filtroAtleticaId;
  DateTime? _filtroData;
  // null = qualquer viabilidade; .alta = só alta; .media = média ou mais
  NivelViabilidade? _filtroViabilidade;
  // 'viabilidade' (padrão) ou 'data'
  String _ordenacao = 'viabilidade';
  bool _filtrarAcessiveis = false;
  List<Atletica> _atleticas = [];
  bool _cancelamentosVerificados = false;

  @override
  void initState() {
    super.initState();
    _db.listarAtleticas().then((lista) {
      if (mounted) {
        setState(() {
          _atleticas =
              lista.where((a) => a.id != kSemAtleticaId).toList();
        });
      }
    });
    // Verifica cancelamentos pendentes assim que o widget estiver montado
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = context.read<AppProvider>().currentUid;
      if (uid != null) _verificarCancelamentos(uid);
    });
  }

  void _verificarCancelamentos(String userId) {
    if (_cancelamentosVerificados) return;
    _cancelamentosVerificados = true;

    _db.streamCancelamentosNaoVistos(userId).first.then((pendentes) {
      if (!mounted || pendentes.isEmpty) return;
      _mostrarDialogCancelamentos(pendentes, userId);
    });
  }

  Future<void> _mostrarDialogCancelamentos(
      List<Evento> eventos, String userId) async {
    final nomes = eventos.map((e) => '• ${e.nome}').join('\n');
    final plural = eventos.length > 1 ? 'eventos foram cancelados' : 'evento foi cancelado';

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Eventos cancelados'),
        content: Text(
          'O seguinte $plural pelo organizador:\n\n$nomes\n\n'
          'Pedimos desculpas pelo inconveniente.',
        ),
        actions: [
          FilledButton(
            onPressed: () async {
              try {
                for (final e in eventos) {
                  await _db.marcarCienteCancelamento(e.id, userId);
                }
              } finally {
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Estou ciente'),
          ),
        ],
      ),
    );
  }

  bool get _temFiltroSecundario =>
      _filtroAtleticaId != null ||
      _filtroData != null ||
      _filtroViabilidade != null ||
      _ordenacao != 'viabilidade' ||
      _filtrarAcessiveis;

  List<Evento> _aplicarFiltros(List<Evento> eventos, String? userAtleticaId) {
    var lista = eventos;

    if (_filtroEsporte != null) {
      lista = lista.where((e) => e.esporte == _filtroEsporte).toList();
    }
    if (_filtroAtleticaId != null) {
      lista =
          lista.where((e) => e.atleticaId == _filtroAtleticaId).toList();
    }
    if (_filtroData != null) {
      lista = lista.where((e) {
        final d = e.dataHora;
        return d.year == _filtroData!.year &&
            d.month == _filtroData!.month &&
            d.day == _filtroData!.day;
      }).toList();
    }
    if (_filtroViabilidade != null) {
      lista = lista.where((e) {
        final n = classificarViabilidade(e.indiceViabilidade);
        return switch (_filtroViabilidade!) {
          // Só Alta
          NivelViabilidade.alta => n == NivelViabilidade.alta,
          // Média ou mais (Alta + Média)
          NivelViabilidade.media => n != NivelViabilidade.baixa,
          // Baixa selecionada = apenas baixa
          NivelViabilidade.baixa => n == NivelViabilidade.baixa,
        };
      }).toList();
    }
    if (_filtrarAcessiveis && userAtleticaId != null) {
      lista =
          lista.where((e) => e.podeConfirmar(userAtleticaId)).toList();
    }

    // Ordenação
    if (_ordenacao == 'data') {
      lista.sort((a, b) => a.dataHora.compareTo(b.dataHora));
    } else {
      lista.sort(
          (a, b) => b.indiceViabilidade.compareTo(a.indiceViabilidade));
    }

    return lista;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final usuario = provider.usuario;
    final primeiroNome =
        usuario?.nome.split(' ').first ?? 'Atleta';

    final fmtData = DateFormat('dd/MM', 'pt_BR');

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Column(
          children: [
            // Header escuro
            Container(
              color: const Color(0xFF0F172A),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                      height: MediaQuery.of(context).padding.top + 8),
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(20, 0, 20, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Olá, $primeiroNome!',
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Text(
                                'Próximos Jogos',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: _mostrarFiltros,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _temFiltroSecundario
                                  ? const Color(0xFF2563EB)
                                  : Colors.white
                                      .withValues(alpha:0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.tune,
                                color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Quick sport chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding:
                        const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Row(
                      children: [
                        _QuickChip(
                          label: 'Todos',
                          selected: _filtroEsporte == null,
                          onTap: () =>
                              setState(() => _filtroEsporte = null),
                        ),
                        ...esportesDisponiveis.map((s) => _QuickChip(
                              label: s,
                              selected: _filtroEsporte == s,
                              onTap: () => setState(
                                  () => _filtroEsporte =
                                      _filtroEsporte == s ? null : s),
                            )),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Chips de filtros secundários ativos
            if (_temFiltroSecundario)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Row(
                  children: [
                    if (_filtroAtleticaId != null)
                      _ActiveChip(
                        label: _atleticas
                                .cast<Atletica?>()
                                .firstWhere(
                                    (a) => a?.id == _filtroAtleticaId,
                                    orElse: () => null)
                                ?.nome ??
                            _filtroAtleticaId!,
                        onRemove: () =>
                            setState(() => _filtroAtleticaId = null),
                      ),
                    if (_filtroData != null)
                      _ActiveChip(
                        label: fmtData.format(_filtroData!),
                        onRemove: () =>
                            setState(() => _filtroData = null),
                      ),
                    if (_filtroViabilidade != null)
                      _ActiveChip(
                        label: switch (_filtroViabilidade!) {
                          NivelViabilidade.alta => 'Viab. Alta',
                          NivelViabilidade.media => 'Viab. Média+',
                          NivelViabilidade.baixa => 'Viab. Baixa',
                        },
                        onRemove: () =>
                            setState(() => _filtroViabilidade = null),
                      ),
                    if (_ordenacao == 'data')
                      _ActiveChip(
                        label: 'Data ↑',
                        onRemove: () =>
                            setState(() => _ordenacao = 'viabilidade'),
                      ),
                    if (_filtrarAcessiveis)
                      _ActiveChip(
                        label: 'Acessíveis',
                        onRemove: () =>
                            setState(() => _filtrarAcessiveis = false),
                      ),
                    TextButton(
                      onPressed: () => setState(() {
                        _filtroAtleticaId = null;
                        _filtroData = null;
                        _filtroViabilidade = null;
                        _ordenacao = 'viabilidade';
                        _filtrarAcessiveis = false;
                      }),
                      style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact),
                      child: const Text('Limpar'),
                    ),
                  ],
                ),
              ),

            // Lista de eventos
            Expanded(
              child: StreamBuilder<List<Evento>>(
                stream: _db.streamEventosAbertos(),
                builder: (context, snap) {
                  if (snap.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(
                        child: Text('Erro: ${snap.error}'));
                  }

                  final eventos = _aplicarFiltros(
                      snap.data ?? [], usuario?.atleticaId);

                  if (eventos.isEmpty) {
                    return const Center(
                      child: Text('Nenhum evento encontrado.'),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.only(
                        top: 12, bottom: 24),
                    itemCount: eventos.length,
                    itemBuilder: (_, i) =>
                        EventoCard(evento: eventos[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarFiltros() {
    String? atleticaId = _filtroAtleticaId;
    DateTime? data = _filtroData;
    NivelViabilidade? viabilidade = _filtroViabilidade;
    String ordenacao = _ordenacao;
    bool acessiveis = _filtrarAcessiveis;
    final usuario = context.read<AppProvider>().usuario;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 12,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Filtros',
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 20),

              // — Atlética —
              DropdownButtonFormField<String>(
                initialValue: atleticaId,
                decoration: const InputDecoration(
                    labelText: 'Atlética',
                    border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text('Todas')),
                  ..._atleticas.map((a) => DropdownMenuItem(
                      value: a.id, child: Text(a.nome))),
                ],
                onChanged: (v) => setSheet(() => atleticaId = v),
              ),
              const SizedBox(height: 16),

              // — Data —
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today,
                    color: Color(0xFF2563EB)),
                title: Text(
                  data == null
                      ? 'Qualquer data'
                      : DateFormat('dd/MM/yyyy', 'pt_BR').format(data!),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                trailing: data != null
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setSheet(() => data = null))
                    : const Icon(Icons.chevron_right),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: data ?? DateTime.now(),
                    firstDate: DateTime.now()
                        .subtract(const Duration(days: 1)),
                    lastDate:
                        DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setSheet(() => data = picked);
                },
              ),
              const SizedBox(height: 20),

              // — Viabilidade —
              const Text('Viabilidade mínima',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _FiltroChip(
                    label: 'Qualquer',
                    selected: viabilidade == null,
                    color: const Color(0xFF64748B),
                    onTap: () => setSheet(() => viabilidade = null),
                  ),
                  _FiltroChip(
                    label: 'Média ou +',
                    selected: viabilidade == NivelViabilidade.media,
                    color: const Color(0xFFD97706),
                    onTap: () => setSheet(
                        () => viabilidade = NivelViabilidade.media),
                  ),
                  _FiltroChip(
                    label: 'Alta (≥70%)',
                    selected: viabilidade == NivelViabilidade.alta,
                    color: const Color(0xFF16A34A),
                    onTap: () => setSheet(
                        () => viabilidade = NivelViabilidade.alta),
                  ),
                  _FiltroChip(
                    label: 'Só Baixa',
                    selected: viabilidade == NivelViabilidade.baixa,
                    color: const Color(0xFFDC2626),
                    onTap: () => setSheet(
                        () => viabilidade = NivelViabilidade.baixa),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // — Ordenação —
              const Text('Ordenar por',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _FiltroChip(
                      label: '🏆 Mais viável',
                      selected: ordenacao == 'viabilidade',
                      color: const Color(0xFF2563EB),
                      onTap: () =>
                          setSheet(() => ordenacao = 'viabilidade'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _FiltroChip(
                      label: '📅 Mais próximo',
                      selected: ordenacao == 'data',
                      color: const Color(0xFF2563EB),
                      onTap: () =>
                          setSheet(() => ordenacao = 'data'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // — Acessíveis —
              if (usuario != null &&
                  usuario.atleticaId != kSemAtleticaId)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Apenas eventos que posso participar',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: const Text(
                      'Oculta eventos restritos a outras atléticas',
                      style: TextStyle(fontSize: 12)),
                  value: acessiveis,
                  onChanged: (v) => setSheet(() => acessiveis = v),
                ),
              const SizedBox(height: 24),

              // — Botões —
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _filtroAtleticaId = null;
                          _filtroData = null;
                          _filtroViabilidade = null;
                          _ordenacao = 'viabilidade';
                          _filtrarAcessiveis = false;
                        });
                        Navigator.pop(ctx);
                      },
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 52)),
                      child: const Text('Limpar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: () {
                        setState(() {
                          _filtroAtleticaId = atleticaId;
                          _filtroData = data;
                          _filtroViabilidade = viabilidade;
                          _ordenacao = ordenacao;
                          _filtrarAcessiveis = acessiveis;
                        });
                        Navigator.pop(ctx);
                      },
                      style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 52)),
                      child: const Text('Aplicar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _QuickChip(
      {required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF2563EB)
                : Colors.white.withValues(alpha:0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? Colors.white
                  : const Color(0xFFCBD5E1),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
}

class _ActiveChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _ActiveChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Chip(
          label: Text(label,
              style: const TextStyle(fontSize: 13)),
          deleteIcon: const Icon(Icons.close, size: 15),
          onDeleted: onRemove,
          visualDensity: VisualDensity.compact,
        ),
      );
}

class _FiltroChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _FiltroChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color : Colors.transparent,
            border: Border.all(
                color: selected ? color : const Color(0xFFCBD5E1),
                width: 1.5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : const Color(0xFF475569),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
}
