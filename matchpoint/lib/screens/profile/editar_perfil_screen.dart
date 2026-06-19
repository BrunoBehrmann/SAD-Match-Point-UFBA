import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/atletica.dart';
import '../../providers/app_provider.dart';
import '../../services/firestore_service.dart';
import '../../utils/constants.dart';
import '../../utils/cursos.dart';

class EditarPerfilScreen extends StatefulWidget {
  const EditarPerfilScreen({super.key});

  @override
  State<EditarPerfilScreen> createState() => _EditarPerfilScreenState();
}

class _EditarPerfilScreenState extends State<EditarPerfilScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomeCtrl;
  String? _curso;
  String? _atleticaId;
  List<Atletica> _atleticas = [];
  bool _salvando = false;

  final _db = FirestoreService();

  @override
  void initState() {
    super.initState();
    final usuario = context.read<AppProvider>().usuario;
    _nomeCtrl = TextEditingController(text: usuario?.nome ?? '');
    _curso = usuario?.curso.isEmpty == true ? null : usuario?.curso;
    final id = usuario?.atleticaId;
    _atleticaId = (id == null || id == kSemAtleticaId) ? null : id;
    _carregarAtleticas();
  }

  Future<void> _carregarAtleticas() async {
    final lista = await _db.listarAtleticas();
    if (mounted) {
      setState(() {
        _atleticas = lista.where((a) => a.id != kSemAtleticaId).toList();
      });
    }
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Editar Perfil')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nomeCtrl,
                decoration: const InputDecoration(labelText: 'Nome'),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: cursos.contains(_curso) ? _curso : null,
                decoration: const InputDecoration(labelText: 'Curso'),
                items: cursos
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _curso = v),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _atleticaId,
                decoration: const InputDecoration(labelText: 'Atlética'),
                items: _atleticas
                    .map((a) => DropdownMenuItem(
                          value: a.id,
                          child: Text(a.nome),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _atleticaId = v),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _salvando ? null : _salvar,
                child: _salvando
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Salvar'),
              ),
              if (!provider.isGestor) ...[
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => _mostrarDialogoCodigo(context),
                  icon: const Icon(Icons.vpn_key_outlined),
                  label: const Text('Tenho um código de treinador'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _mostrarDialogoCodigo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CodigoTreinadorSheet(),
    );
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);
    try {
      await context.read<AppProvider>().atualizarPerfil(
            nome: _nomeCtrl.text.trim(),
            curso: _curso ?? '',
            atleticaId: _atleticaId ?? kSemAtleticaId,
          );
      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }
}

class _CodigoTreinadorSheet extends StatefulWidget {
  const _CodigoTreinadorSheet();

  @override
  State<_CodigoTreinadorSheet> createState() => _CodigoTreinadorSheetState();
}

class _CodigoTreinadorSheetState extends State<_CodigoTreinadorSheet> {
  final _codigoCtrl = TextEditingController();
  String? _erro;
  bool _carregando = false;

  @override
  void dispose() {
    _codigoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Código de treinador',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text(
              'Digite o código fornecido pelo administrador da sua atlética.'),
          const SizedBox(height: 20),
          if (_erro != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_erro!,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          TextField(
            controller: _codigoCtrl,
            decoration: const InputDecoration(
              labelText: 'Código',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
            textCapitalization: TextCapitalization.none,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _carregando ? null : _ativar,
            child: _carregando
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Ativar'),
          ),
        ],
      ),
    );
  }

  Future<void> _ativar() async {
    final codigo = _codigoCtrl.text.trim();
    if (codigo.isEmpty) {
      setState(() => _erro = 'Digite o código.');
      return;
    }
    setState(() {
      _carregando = true;
      _erro = null;
    });
    final provider = context.read<AppProvider>();
    final erro = await provider.ativarCodigoGestor(codigo);
    if (!mounted) return;
    if (erro != null) {
      setState(() {
        _erro = erro;
        _carregando = false;
      });
    } else {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Você agora é treinador!')),
      );
    }
  }
}
