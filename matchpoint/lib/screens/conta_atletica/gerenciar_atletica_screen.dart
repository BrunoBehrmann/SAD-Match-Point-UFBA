import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/app_user.dart';
import '../../providers/app_provider.dart';
import '../../services/firestore_service.dart';

class GerenciarAtleticaScreen extends StatelessWidget {
  const GerenciarAtleticaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final atletica = provider.atletica;
    final db = FirestoreService();

    return Scaffold(
      appBar: AppBar(
        title: Text(atletica?.nome ?? 'Minha Atlética'),
      ),
      body: atletica == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<AppUser>>(
              stream: db.streamAtletasAtletica(atletica.id),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text('Erro: ${snap.error}'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final membros = snap.data!
                  ..sort((a, b) => a.nome.compareTo(b.nome));

                if (membros.isEmpty) {
                  return const Center(
                    child: Text('Nenhum atleta vinculado a esta atlética ainda.'),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: membros.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final membro = membros[i];
                    final isTreinador =
                        atletica.gestoresIds.contains(membro.id);

                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(membro.nome[0].toUpperCase()),
                      ),
                      title: Text(membro.nome),
                      subtitle: Text(
                        isTreinador ? 'Treinador' : 'Atleta',
                        style: TextStyle(
                          color: isTreinador
                              ? Theme.of(context).colorScheme.primary
                              : null,
                          fontWeight: isTreinador
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      trailing: _BotaoPromocao(
                        atleticaId: atletica.id,
                        membro: membro,
                        isTreinador: isTreinador,
                        db: db,
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

class _BotaoPromocao extends StatefulWidget {
  final String atleticaId;
  final AppUser membro;
  final bool isTreinador;
  final FirestoreService db;

  const _BotaoPromocao({
    required this.atleticaId,
    required this.membro,
    required this.isTreinador,
    required this.db,
  });

  @override
  State<_BotaoPromocao> createState() => _BotaoPromocaoState();
}

class _BotaoPromocaoState extends State<_BotaoPromocao> {
  bool _carregando = false;

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return TextButton(
      onPressed: _alternar,
      style: TextButton.styleFrom(
        foregroundColor: widget.isTreinador
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.primary,
      ),
      child: Text(widget.isTreinador ? 'Rebaixar' : 'Promover'),
    );
  }

  Future<void> _alternar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(widget.isTreinador ? 'Rebaixar treinador' : 'Promover atleta'),
        content: Text(
          widget.isTreinador
              ? '${widget.membro.nome} perderá acesso de treinador.'
              : '${widget.membro.nome} poderá criar e gerenciar eventos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(widget.isTreinador ? 'Rebaixar' : 'Promover'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _carregando = true);
    try {
      if (widget.isTreinador) {
        await widget.db.rebaixarTreinador(widget.atleticaId, widget.membro.id);
      } else {
        await widget.db.promoverTreinador(widget.atleticaId, widget.membro.id);
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }
}
