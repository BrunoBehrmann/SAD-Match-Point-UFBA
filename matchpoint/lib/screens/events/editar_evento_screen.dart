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
import 'criar_evento_screen.dart' show ParceirasSelector;

class EditarEventoScreen extends StatefulWidget {
  final String eventoId;
  const EditarEventoScreen({super.key, required this.eventoId});

  @override
  State<EditarEventoScreen> createState() => _EditarEventoScreenState();
}

class _EditarEventoScreenState extends State<EditarEventoScreen> {
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

  bool _carregando = true;
  bool _salvando = false;
  bool _cancelando = false;

  static const _materiaisPresets = ['Bola', 'Bomba de ar', 'Coletes'];
  static const _enderecoCeef =
      'R. Dorilândia, 105 - Ondina, Salvador - BA, 40170-010';

  @override
  void initState() {
    super.initState();
    _carregarEvento();
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

  Future<void> _carregarEvento() async {
    final evento = await _db.getEvento(widget.eventoId);
    if (!mounted) return;

    if (evento == null) {
      setState(() => _carregando = false);
      return;
    }

    setState(() {
      _esporte = evento.esporte;
      _nomeCtrl.text = evento.nome;
      _localNomeCtrl.text = evento.local.nome;
      _enderecoCtrl.text = evento.local.endereco ?? '';
      _lat = evento.local.latitude;
      _lng = evento.local.longitude;
      _usaCeef = evento.local.usaCeef;
      _dataHora = evento.dataHora;
      _minimoCtrl.text = evento.minimoJogadores.toString();
      _regra = evento.regraAcesso;
      _atleticasParceirasIds.addAll(evento.atleticasParceiraIds);
      _materiais.addAll(evento.materiaisNecessarios);
      _carregando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return Scaffold(
        appBar: AppBar(title: const Text('Editar Evento')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Editar Evento')),
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
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
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
              _buildEnderecoStatus(),
              CheckboxListTile(
                title: const Text('Usa CEEF'),
                value: _usaCeef,
                onChanged: (v) {
                  final checked = v ?? false;
                  setState(() => _usaCeef = checked);
                  if (checked) {
                    _localNomeCtrl.text =
                        'CEEF - Complexo Esportivo Educacional da UFBA';
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
                decoration:
                    const InputDecoration(labelText: 'Regra de acesso'),
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
                          a.id !=
                          context.read<AppProvider>().usuario?.atleticaId)
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
                    : const Text('Salvar Alterações'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                  side:
                      BorderSide(color: Theme.of(context).colorScheme.error),
                ),
                onPressed: _cancelando ? null : _cancelarEvento,
                child: _cancelando
                    ? const CircularProgressIndicator()
                    : const Text('CANCELAR EVENTO'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEnderecoStatus() {
    if (_geocodingResult != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 4, left: 4),
        child: Row(
          children: [
            Icon(Icons.check_circle,
                color: Theme.of(context).colorScheme.primary, size: 14),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                _geocodingResult!.displayName,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    if (_lat != null && _lng != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 4, left: 4),
        child: Row(
          children: [
            Icon(Icons.location_on,
                color: Theme.of(context).colorScheme.secondary, size: 14),
            const SizedBox(width: 4),
            Text(
              'Localização definida',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.secondary,
                  ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
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
    final agora = DateTime.now();
    // Evita initialDate < firstDate (crash) quando o evento já passou
    final inicial = (_dataHora != null && _dataHora!.isAfter(agora))
        ? _dataHora!
        : agora.add(const Duration(days: 1));
    final data = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: agora,
      lastDate: agora.add(const Duration(days: 365)),
    );
    if (data == null) return;
    if (!mounted) return;
    final hora = await showTimePicker(
      context: context,
      initialTime: _dataHora != null
          ? TimeOfDay.fromDateTime(_dataHora!)
          : TimeOfDay.now(),
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
            content: Text('Selecione ao menos uma atlética parceira')),
      );
      return;
    }

    setState(() => _salvando = true);
    try {
      await _db.atualizarEvento(widget.eventoId, {
        'nome': _nomeCtrl.text.trim(),
        'esporte': _esporte,
        'local': Local(
          nome: _localNomeCtrl.text.trim(),
          latitude: _lat!,
          longitude: _lng!,
          usaCeef: _usaCeef,
          endereco: _enderecoCtrl.text.trim().isEmpty
              ? null
              : _enderecoCtrl.text.trim(),
        ).toMap(),
        'dataHora': _dataHora!.toUtc(),
        'minimoJogadores': int.parse(_minimoCtrl.text),
        'regraAcesso': _regra.name,
        'atleticasParceiraIds': _atleticasParceirasIds.toList(),
        'materiaisNecessarios': _materiais.toList(),
      });
      if (mounted) context.go('/meus-eventos');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar evento: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _cancelarEvento() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar Evento'),
        content: const Text(
            'Tem certeza? Todos os confirmados serão notificados.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Não')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Sim, cancelar',
                  style: TextStyle(
                      color: Theme.of(ctx).colorScheme.error))),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _cancelando = true);
    try {
      await _db.cancelarEvento(widget.eventoId);
      if (mounted) context.go('/meus-eventos');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao cancelar evento: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _cancelando = false);
    }
  }
}
