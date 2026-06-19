import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../services/firestore_service.dart';
import '../../models/atletica.dart';
import '../../utils/constants.dart';
import '../../utils/cursos.dart';

class CadastroScreen extends StatefulWidget {
  const CadastroScreen({super.key});

  @override
  State<CadastroScreen> createState() => _CadastroScreenState();
}

class _CadastroScreenState extends State<CadastroScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeCtrl = TextEditingController();
  String? _curso;
  String? _atleticaId;
  List<Atletica> _atleticas = [];
  bool _carregandoAtleticas = true;
  String? _erroAtleticas;

  final _db = FirestoreService();

  @override
  void initState() {
    super.initState();
    _nomeCtrl.text = context.read<AppProvider>().currentNome ?? '';
    _carregarAtleticas();
  }

  Future<void> _carregarAtleticas() async {
    try {
      final lista = await _db.listarAtleticas();
      if (mounted) {
        setState(() {
          _atleticas = lista.where((a) => a.id != kSemAtleticaId).toList();
          _carregandoAtleticas = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _erroAtleticas = 'Erro ao carregar atléticas: $e';
          _carregandoAtleticas = false;
        });
      }
    }
  }

  void _onCursoChanged(String? curso) {
    setState(() {
      _curso = curso;
      if (curso != null) {
        final sugestao = _atleticas.cast<Atletica?>().firstWhere(
              (a) => a?.curso.toUpperCase() == curso.toUpperCase(),
              orElse: () => null,
            );
        if (sugestao != null) _atleticaId = sugestao.id;
      }
    });
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final bool podeSalvar = !provider.carregando && !_carregandoAtleticas;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete seu cadastro'),
        actions: [
          TextButton.icon(
            onPressed: () => context.read<AppProvider>().signOut(),
            icon: const Icon(Icons.logout),
            label: const Text('Sair'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (provider.erro != null) _errorBox(provider.erro!),
              if (_erroAtleticas != null) _errorBox(_erroAtleticas!),
              TextFormField(
                controller: _nomeCtrl,
                decoration: const InputDecoration(labelText: 'Nome completo'),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _curso,
                decoration: const InputDecoration(
                  labelText: 'Curso',
                ),
                items: cursos
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: _onCursoChanged,
              ),
              const SizedBox(height: 16),
              if (_carregandoAtleticas)
                const Center(child: CircularProgressIndicator())
              else if (_atleticas.isEmpty)
                const Text(
                  'Nenhuma atlética cadastrada. Contate o administrador.',
                  style: TextStyle(color: Colors.red),
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: _atleticaId,
                  decoration: const InputDecoration(
                    labelText: 'Atlética',
                  ),
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
                onPressed: podeSalvar ? _salvar : null,
                child: provider.carregando
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Salvar e entrar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorBox(String msg) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          border: Border.all(color: Colors.red.shade200),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(msg, style: TextStyle(color: Colors.red.shade800)),
      );

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<AppProvider>();
    await provider.cadastrarPerfil(
      nome: _nomeCtrl.text.trim(),
      curso: _curso ?? '',
      atleticaId: _atleticaId ?? kSemAtleticaId,
    );
  }
}
