import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/atletica.dart';
import '../../models/evento.dart';
import '../../providers/app_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/geocoding_service.dart';
import '../../utils/constants.dart';
import '../../utils/esportes.dart';

class CriarEventoScreen extends StatefulWidget {
  const CriarEventoScreen({super.key});

  @override
  State<CriarEventoScreen> createState() => _CriarEventoScreenState();
}

class _CriarEventoScreenState extends State<CriarEventoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _db = FirestoreService();
  final _geocoding = GeocodingService();

  String? _esporte;
  final _nomeCtrl = TextEditingController();
  final _localNomeCtrl = TextEditingController();
  final _enderecoCtrl = TextEditingController();
  double? _lat;
  double? _lng;
  GeocodingResult? _geocodingResult;
  bool _buscandoEndereco = false;
  bool _usaCeef = false;
  DateTime? _dataHora;
  final _minimoCtrl = TextEditingController(text: '2');
  RegraAcesso _regra = RegraAcesso.aberto;
  List<Atletica> _atleticas = [];
  final Set<String> _atleticasParceirasIds = {};
  final Set<String> _materiais = {};
  final _materialCustomCtrl = TextEditingController();
  bool _salvando = false;

  static const _materiaisPresets = ['Bola', 'Bomba de ar', 'Coletes'];
  static const _enderecoCeef =
      'R. Dorilândia, 105 - Ondina, Salvador - BA, 40170-010';

  @override
  void initState() {
    super.initState();
    _db.listarAtleticas().then((lista) {
      if (mounted) {
        setState(() {
          _atleticas = lista.where((a) => a.id != kSemAtleticaId).toList();
        });
      }
    });
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _localNomeCtrl.dispose();
    _enderecoCtrl.dispose();
    _minimoCtrl.dispose();
    _materialCustomCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    if (!provider.isGestor) {
      return Scaffold(
        appBar: AppBar(title: const Text('Criar Evento')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Apenas gestores podem criar eventos.\nContate a administração da sua atlética.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Criar Evento')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nomeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nome do evento',
                  hintText: 'Ex: Futebol dos amigos',
                ),
                textCapitalization: TextCapitalization.sentences,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _esporte,
                decoration: const InputDecoration(labelText: 'Esporte'),
                items: esportesDisponiveis
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => _esporte = v),
                validator: (v) => v == null ? 'Selecione um esporte' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _localNomeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nome do local',
                  hintText: 'Ex: Quadra do CEEF',
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _enderecoCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Endereço',
                        hintText: 'Ex: Rua X, 123, Salvador, BA',
                      ),
                      textInputAction: TextInputAction.search,
                      onFieldSubmitted: (_) => _buscarEndereco(),
                      validator: (_) =>
                          (_lat == null || _lng == null)
                              ? 'Busque o endereço para localizar as coordenadas'
                              : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 48,
                    child: _buscandoEndereco
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton.filled(
                            icon: const Icon(Icons.search),
                            onPressed: _buscarEndereco,
                            tooltip: 'Buscar endereço',
                          ),
                  ),
                ],
              ),
              if (_geocodingResult != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle,
                          color: Theme.of(context).colorScheme.primary,
                          size: 14),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _geocodingResult!.displayName,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color:
                                    Theme.of(context).colorScheme.primary,
                              ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              CheckboxListTile(
                title: const Text('Usa CEEF'),
                value: _usaCeef,
                onChanged: (v) {
                  final checked = v ?? false;
                  setState(() {
                    _usaCeef = checked;
                    if (!checked) {
                      _localNomeCtrl.clear();
                      _enderecoCtrl.clear();
                      _lat = null;
                      _lng = null;
                      _geocodingResult = null;
                    }
                  });
                  if (checked) {
                    _localNomeCtrl.text = 'CEEF - Ondina';
                    _enderecoCtrl.text = _enderecoCeef;
                    _buscarEndereco();
                  }
                },
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_dataHora == null
                    ? 'Selecionar data e hora'
                    : DateFormat('dd/MM/yyyy HH:mm').format(_dataHora!)),
                leading: const Icon(Icons.calendar_today),
                onTap: _selecionarDataHora,
                trailing: const Icon(Icons.chevron_right),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _minimoCtrl,
                decoration:
                    const InputDecoration(labelText: 'Mínimo de jogadores'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  if (n == null || n < 1) return 'Mínimo inválido';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<RegraAcesso>(
                initialValue: _regra,
                decoration: const InputDecoration(labelText: 'Regra de acesso'),
                items: const [
                  DropdownMenuItem(
                    value: RegraAcesso.aberto,
                    child: Text('Aberto a todos'),
                  ),
                  DropdownMenuItem(
                    value: RegraAcesso.parceiros,
                    child: Text('Atléticas parceiras'),
                  ),
                  DropdownMenuItem(
                    value: RegraAcesso.somenteAtletica,
                    child: Text('Apenas minha atlética'),
                  ),
                ],
                onChanged: (v) => setState(() {
                  _regra = v!;
                  if (v != RegraAcesso.parceiros) _atleticasParceirasIds.clear();
                }),
              ),
              if (_regra == RegraAcesso.parceiros) ...[
                const SizedBox(height: 12),
                ParceirasSelector(
                  atleticas: _atleticas
                      .where((a) =>
                          a.id != context.read<AppProvider>().usuario?.atleticaId)
                      .toList(),
                  selecionadas: _atleticasParceirasIds,
                  onToggle: (id, selecionado) => setState(() {
                    if (selecionado) {
                      _atleticasParceirasIds.add(id);
                    } else {
                      _atleticasParceirasIds.remove(id);
                    }
                  }),
                ),
              ],
              const SizedBox(height: 16),
              Text('Materiais necessários',
                  style: Theme.of(context).textTheme.titleSmall),
              ..._materiaisPresets.map((m) => CheckboxListTile(
                    title: Text(m),
                    value: _materiais.contains(m),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        _materiais.add(m);
                      } else {
                        _materiais.remove(m);
                      }
                    }),
                  )),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _materialCustomCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Material customizado'),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: _adicionarMaterialCustom,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _salvando ? null : _salvar,
                child: _salvando
                    ? const CircularProgressIndicator()
                    : const Text('Criar Evento'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _buscarEndereco() async {
    final endereco = _enderecoCtrl.text.trim();
    if (endereco.isEmpty) return;

    setState(() => _buscandoEndereco = true);
    try {
      final result = await _geocoding.buscarCoordenadas(endereco);
      if (!mounted) return;
      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Endereço não encontrado. Tente ser mais específico.')),
        );
      } else {
        setState(() {
          _geocodingResult = result;
          _lat = result.lat;
          _lng = result.lng;
          if (_localNomeCtrl.text.isEmpty) {
            _localNomeCtrl.text =
                result.displayName.split(',').first.trim();
          }
        });
      }
    } finally {
      if (mounted) setState(() => _buscandoEndereco = false);
    }
  }

  void _adicionarMaterialCustom() {
    final m = _materialCustomCtrl.text.trim();
    if (m.isNotEmpty) {
      setState(() {
        _materiais.add(m);
        _materialCustomCtrl.clear();
      });
    }
  }

  Future<void> _selecionarDataHora() async {

    final data = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (data == null) return;
    if (!mounted) return;
    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (hora == null) return;
    setState(() {
      _dataHora =
          DateTime(data.year, data.month, data.day, hora.hour, hora.minute);
    });
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dataHora == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione data e hora')),
      );
      return;
    }
    if (_regra == RegraAcesso.parceiros && _atleticasParceirasIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Selecione ao menos uma atlética parceira')),
      );
      return;
    }

    setState(() => _salvando = true);
    final provider = context.read<AppProvider>();

    try {
      final evento = Evento(
        id: '',
        atleticaId: provider.usuario!.atleticaId,
        criadoPorId: provider.usuario!.id,
        criadoPorNome: provider.usuario!.nome,
        nome: _nomeCtrl.text.trim(),
        esporte: _esporte!,
        local: Local(
          nome: _localNomeCtrl.text.trim(),
          latitude: _lat!,
          longitude: _lng!,
          usaCeef: _usaCeef,
          endereco: _enderecoCtrl.text.trim(),
        ),
        dataHora: _dataHora!,
        minimoJogadores: int.parse(_minimoCtrl.text),
        regraAcesso: _regra,
        atleticasParceiraIds: _atleticasParceirasIds.toList(),
        materiaisNecessarios: _materiais.toList(),
        indiceViabilidade: 0.0,
      );

      await _db.criarEvento(evento);
      if (mounted) context.go('/');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao criar evento: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }
}

class ParceirasSelector extends StatelessWidget {
  final List<Atletica> atleticas;
  final Set<String> selecionadas;
  final void Function(String id, bool selecionado) onToggle;

  const ParceirasSelector({
    super.key,
    required this.atleticas,
    required this.selecionadas,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFED7AA)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.handshake_outlined,
                      size: 16, color: Color(0xFFD97706)),
                  SizedBox(width: 6),
                  Text(
                    'Atléticas parceiras',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFD97706),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Membros dessas atléticas (e da sua) poderão confirmar presença.',
                style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
              ),
              const SizedBox(height: 8),
              if (atleticas.isEmpty)
                const Text(
                  'Nenhuma outra atlética cadastrada.',
                  style: TextStyle(
                      fontSize: 12, color: Color(0xFF64748B)),
                )
              else
                ...atleticas.map(
                  (a) => CheckboxListTile(
                    title: Text(a.nome,
                        style: const TextStyle(fontSize: 13)),
                    value: selecionadas.contains(a.id),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) => onToggle(a.id, v ?? false),
                  ),
                ),
            ],
          ),
        ),
        if (selecionadas.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 6, left: 4),
            child: Text(
              'Selecione ao menos uma atlética parceira',
              style: TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
            ),
          ),
      ],
    );
  }
}
