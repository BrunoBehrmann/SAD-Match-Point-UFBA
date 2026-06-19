import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/evento.dart';
import '../../models/app_user.dart';
import '../../providers/app_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';
import '../../services/weather_service.dart';
import '../../utils/viabilidade.dart';
import '../../widgets/evento_analytics_section.dart';
import '../../widgets/viabilidade_badge.dart';
import '../../widgets/viabilidade_detalhe_sheet.dart';

class EventoDetalheScreen extends StatefulWidget {
  final String eventoId;
  const EventoDetalheScreen({super.key, required this.eventoId});

  @override
  State<EventoDetalheScreen> createState() => _EventoDetalheScreenState();
}

class _EventoDetalheScreenState extends State<EventoDetalheScreen> {
  final _db = FirestoreService();
  final _location = LocationService();
  late final _weather = WeatherService(dotenv.env['OPENWEATHERMAP_KEY'] ?? '');

  double? _chanceChuva;
  String? _climaErro;
  bool _climaCarregado = false;
  bool _dialogCancelamentoExibido = false;
  Map<String, String> _atleticaNomes = {};
  bool _atleticaNomesCarregados = false;

  Future<void> _abrirMaps(double lat, double lng, String nome) async {
    final geoUri = Uri.parse(
        'geo:$lat,$lng?q=$lat,$lng(${Uri.encodeComponent(nome)})');
    if (await canLaunchUrl(geoUri)) {
      await launchUrl(geoUri);
      return;
    }
    final webUri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    await launchUrl(webUri, mode: LaunchMode.externalApplication);
  }

  Future<void> _mostrarDialogCancelamento(
      Evento evento, String userId) async {
    if (_dialogCancelamentoExibido) return;
    _dialogCancelamentoExibido = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Evento cancelado'),
        content: Text(
          'O evento "${evento.nome}" foi cancelado pelo organizador.\n\n'
          'Pedimos desculpas pelo inconveniente.',
        ),
        actions: [
          FilledButton(
            onPressed: () async {
              try {
                await _db.marcarCienteCancelamento(evento.id, userId);
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

  Future<void> _carregarClima(Evento evento) async {
    if (_climaCarregado) return;
    _climaCarregado = true;

    try {
      final chance = await _weather.getChanceChuva(
        latitude: evento.local.latitude,
        longitude: evento.local.longitude,
        dataHora: evento.dataHora,
        cacheKey: '${evento.id}_${evento.dataHora.toIso8601String()}',
      );
      if (mounted) setState(() => _chanceChuva = chance);

      // Recalcula e persiste o índice com o clima real.
      // taxaFaltaMedia null quando não há confirmados: confiabilidade excluída.
      final taxaFaltaMedia = evento.confirmados.isEmpty
          ? null
          : evento.confirmados
                  .map((c) => 1.0 - c.taxaConfiabilidade)
                  .reduce((a, b) => a + b) /
              evento.confirmados.length;

      final novoIndice = calcularViabilidade(
        confirmados: evento.confirmados.length,
        minimo: evento.minimoJogadores,
        chanceChuva: chance,
        taxaFaltaMedia: taxaFaltaMedia,
      );

      // Só grava se divergir mais de 1% do valor armazenado (evita writes desnecessários)
      if ((novoIndice - evento.indiceViabilidade).abs() > 0.01) {
        await _db.atualizarEvento(
            evento.id, {'indiceViabilidade': novoIndice});
      }
    } on WeatherForaDoAlcanceException {
      // Evento além dos 5 dias cobertos pela API gratuita
      if (mounted) {
        final dias = evento.dataHora.difference(DateTime.now()).inDays;
        setState(() {
          _climaErro = 'Previsão indisponível — evento em $dias dias '
              '(API gratuita cobre até 5 dias)';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _climaErro = 'Erro ao carregar clima');
      }
    }
  }

  Future<void> _carregarNomesAtleticas(Evento evento) async {
    if (_atleticaNomesCarregados) return;
    _atleticaNomesCarregados = true;
    final ids = <String>{
      evento.atleticaId,
      ...evento.atleticasParceiraIds,
    };
    final nomes = <String, String>{};
    for (final id in ids) {
      final nome = await _db.getNomeAtletica(id);
      if (nome != null) nomes[id] = nome;
    }
    if (mounted) setState(() => _atleticaNomes = nomes);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final usuario = provider.usuario;
    final fmt = DateFormat('EEEE, dd/MM/yyyy · HH:mm', 'pt_BR');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes do Evento'),
        actions: [
          if (provider.isGestor)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () =>
                  context.push('/editar-evento/${widget.eventoId}'),
            ),
        ],
      ),
      body: StreamBuilder<Evento?>(
        stream: _db.streamEvento(widget.eventoId),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final evento = snap.data;
          if (evento == null) {
            return const Center(child: Text('Evento não encontrado'));
          }

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _carregarClima(evento);
            _carregarNomesAtleticas(evento);

            // Dialog único de cancelamento para quem confirmou presença
            if (evento.status == EventStatus.cancelado &&
                usuario != null &&
                evento.confirmados.any((c) => c.usuarioId == usuario.id) &&
                !evento.cientesCancelamento.contains(usuario.id)) {
              _mostrarDialogCancelamento(evento, usuario.id);
            }
          });

          final jaConfirmado = usuario != null &&
              evento.confirmados.any((c) => c.usuarioId == usuario.id);
          final jaFezCheckIn = usuario != null &&
              evento.confirmados
                  .where((c) => c.usuarioId == usuario.id)
                  .any((c) => c.checkInRealizado);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: nome + badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            evento.nome,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              evento.esporte,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Tooltip(
                      message: 'Toque para ver o detalhamento',
                      child: GestureDetector(
                        onTap: () => mostrarViabilidadeDetalhe(
                          context: context,
                          evento: evento,
                          chanceChuva: _chanceChuva,
                          isGestor: provider.isGestor,
                        ),
                        child: ViabilidadeBadge(
                            indice: evento.indiceViabilidade),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Data/hora
                Text(fmt.format(evento.dataHora)),

                // Criador
                if (evento.criadoPorNome.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.person_outline,
                          size: 14, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 4),
                      Text(
                        'Criado por ${evento.criadoPorNome}',
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 4),
                // Regra de acesso
                _RegraAcessoRow(
                  evento: evento,
                  atleticaNomes: _atleticaNomes,
                ),

                const SizedBox(height: 4),
                // Local com link para mapa
                InkWell(
                  onTap: (evento.local.latitude != 0 ||
                          evento.local.longitude != 0)
                      ? () => _abrirMaps(
                            evento.local.latitude,
                            evento.local.longitude,
                            evento.local.nome,
                          )
                      : null,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(Icons.location_on,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(evento.local.nome),
                              if (evento.local.endereco != null &&
                                  evento.local.endereco!.isNotEmpty)
                                Text(
                                  evento.local.endereco!,
                                  style:
                                      Theme.of(context).textTheme.bodySmall,
                                ),
                            ],
                          ),
                        ),
                        if (evento.local.latitude != 0 ||
                            evento.local.longitude != 0)
                          Icon(Icons.directions,
                              size: 20,
                              color: Theme.of(context).colorScheme.primary),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 32),

                // Clima
                _climaErro != null
                    ? _InfoRow(
                        icon: Icons.cloud_off_outlined,
                        label: _climaErro!,
                        color: const Color(0xFF94A3B8),
                      )
                    : _InfoRow(
                        icon: _chanceChuva == null
                            ? Icons.cloud_outlined
                            : (_chanceChuva! > 50
                                ? Icons.umbrella
                                : Icons.wb_sunny),
                        label: _chanceChuva == null
                            ? 'Carregando clima...'
                            : 'Chance de chuva: ${_chanceChuva!.toStringAsFixed(0)}%',
                        color: _chanceChuva != null && _chanceChuva! > 50
                            ? Colors.blue
                            : Colors.orange,
                      ),
                const SizedBox(height: 8),

                // Quórum
                _InfoRow(
                  icon: Icons.people,
                  label:
                      '${evento.confirmados.length} confirmados / mínimo ${evento.minimoJogadores}',
                ),
                const SizedBox(height: 8),

                // Aviso de bola
                if (evento.semBola)
                  const _InfoRow(
                    icon: Icons.warning_amber_rounded,
                    label: 'Nenhum confirmado marcou a bola',
                    color: Colors.orange,
                  ),

                const SizedBox(height: 24),

                // Materiais necessários
                if (evento.materiaisNecessarios.isNotEmpty) ...[
                  Text('Materiais necessários',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: evento.materiaisNecessarios
                        .map((m) => Chip(label: Text(m)))
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                ],

                // Lista de confirmados
                Text('Confirmados (${evento.confirmados.length})',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ...evento.confirmados.map((c) => ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        child: Text(c.nomeUsuario.isNotEmpty
                            ? c.nomeUsuario[0].toUpperCase()
                            : '?'),
                      ),
                      title: Text(c.nomeUsuario),
                      subtitle: c.materiaisQueVaiLevar.isNotEmpty
                          ? Text(
                              'Leva: ${c.materiaisQueVaiLevar.join(', ')}')
                          : null,
                      trailing: c.checkInRealizado
                          ? const Icon(Icons.check_circle,
                              color: Colors.green, size: 18)
                          : null,
                    )),

                const SizedBox(height: 24),

                // Botões de ação
                if (evento.status == EventStatus.aberto &&
                    usuario != null) ...[
                  if (!jaConfirmado) ...[
                    if (evento.podeConfirmar(usuario.atleticaId))
                      _BotaoConfirmar(
                        evento: evento,
                        usuario: usuario,
                        db: _db,
                        chanceChuva: _chanceChuva,
                      )
                    else
                      _AcessoBloqueadoBanner(evento: evento),
                  ],
                  if (jaConfirmado && !jaFezCheckIn) ...[
                    _BotaoCheckIn(
                      evento: evento,
                      usuario: usuario,
                      db: _db,
                      location: _location,
                    ),
                    const SizedBox(height: 8),
                    if (evento.materiaisNecessarios.isNotEmpty) ...[
                      _BotaoEditarMateriais(
                        evento: evento,
                        usuario: usuario,
                        db: _db,
                      ),
                      const SizedBox(height: 8),
                    ],
                    _BotaoCancelarPresenca(
                      evento: evento,
                      usuario: usuario,
                      db: _db,
                      chanceChuva: _chanceChuva,
                    ),
                  ],
                  if (jaFezCheckIn)
                    const Center(
                      child: Text('✓ Check-in realizado!',
                          style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.w700)),
                    ),
                ],

                // Encerramento (gestor, após o horário do evento)
                if (provider.isGestor &&
                    evento.status == EventStatus.aberto &&
                    DateTime.now().isAfter(evento.dataHora)) ...[
                  const SizedBox(height: 8),
                  _BotaoEncerrarEvento(evento: evento, db: _db),
                ],

                // Selo de evento encerrado
                if (evento.status == EventStatus.encerrado) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Evento encerrado',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ],

                // Analytics para gestores (expansível)
                if (provider.isGestor) ...[
                  const SizedBox(height: 16),
                  EventoAnalyticsSection(evento: evento),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

// Exibe regra de acesso com ícone e lista de atléticas para regraAcesso.parceiros
class _RegraAcessoRow extends StatelessWidget {
  final Evento evento;
  final Map<String, String> atleticaNomes;
  const _RegraAcessoRow(
      {required this.evento, required this.atleticaNomes});

  @override
  Widget build(BuildContext context) {
    switch (evento.regraAcesso) {
      case RegraAcesso.aberto:
        return const Row(
          children: [
            Icon(Icons.public, size: 14, color: Color(0xFF94A3B8)),
            SizedBox(width: 4),
            Text('Aberto a todos',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          ],
        );
      case RegraAcesso.somenteAtletica:
        final nome = atleticaNomes[evento.atleticaId] ?? 'atlética organizadora';
        return Row(
          children: [
            const Icon(Icons.lock_outline, size: 14, color: Color(0xFF2563EB)),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'Apenas membros: $nome',
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF2563EB)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      case RegraAcesso.parceiros:
        final todasAtleticas = [
          atleticaNomes[evento.atleticaId],
          ...evento.atleticasParceiraIds.map((id) => atleticaNomes[id]),
        ].whereType<String>().toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.handshake_outlined,
                    size: 14, color: Color(0xFFD97706)),
                SizedBox(width: 4),
                Text('Atléticas parceiras',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFD97706))),
              ],
            ),
            if (todasAtleticas.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 18, top: 2),
                child: Text(
                  todasAtleticas.join(' · '),
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF64748B)),
                ),
              ),
          ],
        );
    }
  }
}

// Mostrado no lugar do botão "Confirmar Presença" quando o usuário não tem acesso
class _AcessoBloqueadoBanner extends StatelessWidget {
  final Evento evento;
  const _AcessoBloqueadoBanner({required this.evento});

  @override
  Widget build(BuildContext context) {
    final mensagem = switch (evento.regraAcesso) {
      RegraAcesso.somenteAtletica =>
        'Este evento é restrito a membros da atlética organizadora.',
      RegraAcesso.parceiros =>
        'Este evento é restrito a membros das atléticas parceiras.',
      _ => 'Você não tem acesso para confirmar presença neste evento.',
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.block, size: 18, color: Color(0xFF94A3B8)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              mensagem,
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF64748B)),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const _InfoRow({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
        ],
      );
}

class _BotaoConfirmar extends StatefulWidget {
  final Evento evento;
  final AppUser usuario;
  final FirestoreService db;
  final double? chanceChuva;
  const _BotaoConfirmar(
      {required this.evento,
      required this.usuario,
      required this.db,
      required this.chanceChuva});

  @override
  State<_BotaoConfirmar> createState() => _BotaoConfirmarState();
}

class _BotaoConfirmarState extends State<_BotaoConfirmar> {
  final Set<String> _materiaisSelecionados = {};
  bool _salvando = false;

  @override
  Widget build(BuildContext context) {
    final climaCarregando = widget.chanceChuva == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.evento.materiaisNecessarios.isNotEmpty) ...[
          Text('O que você vai levar?',
              style: Theme.of(context).textTheme.titleSmall),
          ...widget.evento.materiaisNecessarios.map((m) => CheckboxListTile(
                title: Text(m),
                value: _materiaisSelecionados.contains(m),
                onChanged: climaCarregando
                    ? null
                    : (v) => setState(() {
                          if (v == true) {
                            _materiaisSelecionados.add(m);
                          } else {
                            _materiaisSelecionados.remove(m);
                          }
                        }),
              )),
          const SizedBox(height: 8),
        ],
        Tooltip(
          message: climaCarregando
              ? 'Aguardando dados de clima para calcular viabilidade...'
              : '',
          child: FilledButton(
            onPressed: (_salvando || climaCarregando) ? null : _confirmar,
            child: _salvando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : climaCarregando
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          ),
                          SizedBox(width: 8),
                          Text('Carregando clima...'),
                        ],
                      )
                    : const Text('Confirmar Presença'),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmar() async {
    setState(() => _salvando = true);
    try {
      final confirmacao = ConfirmacaoUsuario(
        usuarioId: widget.usuario.id,
        nomeUsuario: widget.usuario.nome,
        materiaisQueVaiLevar: _materiaisSelecionados.toList(),
        taxaConfiabilidade: widget.usuario.taxaConfiabilidade,
      );

      final todosConfirmados = [...widget.evento.confirmados, confirmacao];
      final taxaFaltaMedia = todosConfirmados
              .map((c) => 1.0 - c.taxaConfiabilidade)
              .reduce((a, b) => a + b) /
          todosConfirmados.length;

      final novoIndice = calcularViabilidade(
        confirmados: todosConfirmados.length,
        minimo: widget.evento.minimoJogadores,
        chanceChuva: widget.chanceChuva!,
        taxaFaltaMedia: taxaFaltaMedia,
      );

      await widget.db.confirmarPresenca(
        eventoId: widget.evento.id,
        confirmacao: confirmacao,
        novoIndice: novoIndice,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Presença confirmada!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao confirmar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }
}

class _BotaoCheckIn extends StatefulWidget {
  final Evento evento;
  final AppUser usuario;
  final FirestoreService db;
  final LocationService location;
  const _BotaoCheckIn(
      {required this.evento,
      required this.usuario,
      required this.db,
      required this.location});

  @override
  State<_BotaoCheckIn> createState() => _BotaoCheckInState();
}

class _BotaoCheckInState extends State<_BotaoCheckIn> {
  bool _fazendo = false;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
        onPressed: _fazendo ? null : _fazerCheckIn,
        icon: _fazendo
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.location_on),
        label: const Text('Fazer Check-in por GPS'),
        style: FilledButton.styleFrom(backgroundColor: Colors.green),
      );

  Future<void> _fazerCheckIn() async {
    setState(() => _fazendo = true);
    try {
      // Janela de check-in: 2h antes até 6h após o evento
      final agora = DateTime.now();
      final dataEvento = widget.evento.dataHora;
      final abertura = dataEvento.subtract(const Duration(hours: 2));
      final fechamento = dataEvento.add(const Duration(hours: 6));
      if (agora.isBefore(abertura) || agora.isAfter(fechamento)) {
        if (mounted) {
          String fmtDt(DateTime dt) =>
              '${dt.day.toString().padLeft(2, '0')}/'
              '${dt.month.toString().padLeft(2, '0')} '
              'às ${dt.hour.toString().padLeft(2, '0')}:'
              '${dt.minute.toString().padLeft(2, '0')}';
          final msg = agora.isBefore(abertura)
              ? 'Check-in abre em ${fmtDt(abertura)} (2h antes do evento).'
              : 'Prazo de check-in encerrado (até 6h após o evento).';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg)),
          );
        }
        return;
      }

      // Verifica permissão antes de tentar localizar
      final temPermissao = await widget.location.verificarPermissao();
      if (!temPermissao) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Permissão de localização negada. Habilite nas configurações.')),
          );
        }
        return;
      }

      final dentro = await widget.location.dentroDoRaio(
        latEvento: widget.evento.local.latitude,
        lonEvento: widget.evento.local.longitude,
      );
      if (!dentro) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('Você está fora do raio de 500m do local do evento.')),
          );
        }
        return;
      }

      await widget.db.realizarCheckIn(
        eventoId: widget.evento.id,
        userId: widget.usuario.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Check-in realizado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro no check-in: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _fazendo = false);
    }
  }
}

class _BotaoCancelarPresenca extends StatefulWidget {
  final Evento evento;
  final AppUser usuario;
  final FirestoreService db;
  final double? chanceChuva;
  const _BotaoCancelarPresenca(
      {required this.evento,
      required this.usuario,
      required this.db,
      required this.chanceChuva});

  @override
  State<_BotaoCancelarPresenca> createState() =>
      _BotaoCancelarPresencaState();
}

class _BotaoCancelarPresencaState extends State<_BotaoCancelarPresenca> {
  bool _cancelando = false;

  @override
  Widget build(BuildContext context) => OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.error,
          side: BorderSide(color: Theme.of(context).colorScheme.error),
        ),
        onPressed: _cancelando ? null : _cancelar,
        child: _cancelando
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Text('Cancelar Presença'),
      );

  Future<void> _cancelar() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar presença'),
        content:
            const Text('Tem certeza que deseja cancelar sua presença?'),
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
      // Recalcula viabilidade sem este usuário, usando taxas reais dos que ficam
      final restantes = widget.evento.confirmados
          .where((c) => c.usuarioId != widget.usuario.id)
          .toList();

      final taxaFaltaMedia = restantes.isEmpty
          ? null
          : restantes
                  .map((c) => 1.0 - c.taxaConfiabilidade)
                  .reduce((a, b) => a + b) /
              restantes.length;

      final novoIndice = calcularViabilidade(
        confirmados: restantes.length,
        minimo: widget.evento.minimoJogadores,
        chanceChuva: widget.chanceChuva ?? 0,
        taxaFaltaMedia: taxaFaltaMedia,
      );

      await widget.db.cancelarPresenca(
        eventoId: widget.evento.id,
        userId: widget.usuario.id,
        novoIndice: novoIndice,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Presença cancelada.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao cancelar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _cancelando = false);
    }
  }
}

class _BotaoEditarMateriais extends StatelessWidget {
  final Evento evento;
  final AppUser usuario;
  final FirestoreService db;
  const _BotaoEditarMateriais(
      {required this.evento, required this.usuario, required this.db});

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: () => _abrir(context),
        icon: const Icon(Icons.checklist, size: 18),
        label: const Text('Editar o que vou levar'),
      );

  Future<void> _abrir(BuildContext context) async {
    final atual = evento.confirmados
        .firstWhere((c) => c.usuarioId == usuario.id)
        .materiaisQueVaiLevar;
    final selecionados = <String>{...atual};

    final salvou = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('O que você vai levar?',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              ...evento.materiaisNecessarios.map((m) => CheckboxListTile(
                    title: Text(m),
                    value: selecionados.contains(m),
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) => setSheet(() {
                      if (v == true) {
                        selecionados.add(m);
                      } else {
                        selecionados.remove(m);
                      }
                    }),
                  )),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 52)),
                child: const Text('Salvar'),
              ),
            ],
          ),
        ),
      ),
    );

    if (salvou != true || !context.mounted) return;
    try {
      await db.atualizarMateriaisConfirmacao(
        eventoId: evento.id,
        userId: usuario.id,
        materiais: selecionados.toList(),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Materiais atualizados.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar: $e')),
        );
      }
    }
  }
}

class _BotaoEncerrarEvento extends StatefulWidget {
  final Evento evento;
  final FirestoreService db;
  const _BotaoEncerrarEvento({required this.evento, required this.db});

  @override
  State<_BotaoEncerrarEvento> createState() => _BotaoEncerrarEventoState();
}

class _BotaoEncerrarEventoState extends State<_BotaoEncerrarEvento> {
  bool _encerrando = false;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
        onPressed: _encerrando ? null : _encerrar,
        icon: _encerrando
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.flag_outlined),
        label: const Text('Encerrar evento'),
        style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF475569)),
      );

  Future<void> _encerrar() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Encerrar evento'),
        content: const Text(
            'Isso finaliza o evento e atualiza a confiabilidade dos '
            'confirmados. Quem não fez check-in terá a sequência de '
            'presenças zerada. Deseja continuar?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Não')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sim, encerrar')),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _encerrando = true);
    try {
      final resumo = await widget.db.encerrarEvento(widget.evento.id);
      if (mounted) await _mostrarResumo(resumo);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao encerrar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _encerrando = false);
    }
  }

  Future<void> _mostrarResumo(Map<String, dynamic> resumo) async {
    final totalConfirmados = resumo['totalConfirmados'] as int;
    final totalCheckIns = resumo['totalCheckIns'] as int;
    final faltantes = (resumo['faltantes'] as List).cast<String>();
    final taxa = totalConfirmados > 0
        ? (totalCheckIns / totalConfirmados * 100).round()
        : 0;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Evento encerrado'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ResumoLinha(
                label: 'Confirmados', valor: '$totalConfirmados'),
            _ResumoLinha(
                label: 'Compareceram (check-in)',
                valor: '$totalCheckIns'),
            _ResumoLinha(
                label: 'Taxa de comparecimento', valor: '$taxa%'),
            if (faltantes.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Faltaram:',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(faltantes.join(', '),
                  style: const TextStyle(color: Color(0xFF64748B))),
            ],
          ],
        ),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK')),
        ],
      ),
    );
  }
}

class _ResumoLinha extends StatelessWidget {
  final String label;
  final String valor;
  const _ResumoLinha({required this.label, required this.valor});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(color: Color(0xFF64748B))),
            Text(valor,
                style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      );
}
