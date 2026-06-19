import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../models/evento.dart';
import '../utils/viabilidade.dart';

class EventoCard extends StatelessWidget {
  final Evento evento;
  const EventoCard({super.key, required this.evento});

  bool get _isCancelado => evento.status == EventStatus.cancelado;
  bool get _isEncerrado => evento.status == EventStatus.encerrado;
  bool get _inativo => _isCancelado || _isEncerrado;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM · HH:mm', 'pt_BR');
    final nivel = classificarViabilidade(evento.indiceViabilidade);
    final pct = (evento.indiceViabilidade * 100).round();

    // Cores: cinza para inativo, colorido para aberto
    final cor = _inativo ? const Color(0xFF94A3B8) : corViabilidade(nivel);
    final corFundo =
        _inativo ? const Color(0xFFF1F5F9) : _corFundo(nivel);
    final cardColor = _inativo ? const Color(0xFFF8FAFC) : Colors.white;
    final textoPrimario = _inativo
        ? const Color(0xFF94A3B8)
        : const Color(0xFF0F172A);
    final textoSecundario = _inativo
        ? const Color(0xFFCBD5E1)
        : const Color(0xFF64748B);

    return Card(
      color: cardColor,
      child: InkWell(
        onTap: () => context.push('/evento/${evento.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Badge do esporte + status
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _inativo
                                    ? const Color(0xFFE2E8F0)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                evento.esporte,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: textoSecundario,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                            if (_isCancelado) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEE2E2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'Cancelado',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFEF4444),
                                  ),
                                ),
                              ),
                            ] else if (_isEncerrado) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE2E8F0),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'Encerrado',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ],
                            // Badge de regra de acesso
                            if (evento.regraAcesso != RegraAcesso.aberto) ...[
                              const SizedBox(width: 6),
                              _AcessoBadge(regra: evento.regraAcesso),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          evento.nome,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: textoPrimario,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.location_on,
                                size: 13, color: textoSecundario),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                evento.local.nome,
                                style: TextStyle(
                                    fontSize: 13, color: textoSecundario),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.access_time,
                                size: 13, color: textoSecundario),
                            const SizedBox(width: 3),
                            Text(
                              fmt.format(evento.dataHora),
                              style: TextStyle(
                                  fontSize: 13, color: textoSecundario),
                            ),
                            const SizedBox(width: 10),
                            Icon(Icons.people_outline,
                                size: 13, color: textoSecundario),
                            const SizedBox(width: 3),
                            Text(
                              '${evento.confirmados.length}/${evento.minimoJogadores}',
                              style: TextStyle(
                                  fontSize: 13, color: textoSecundario),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Caixa de viabilidade
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: corFundo,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Viabilidade',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: cor,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          '$pct%',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: cor,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Barra de progresso
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: evento.indiceViabilidade,
                  minHeight: 5,
                  backgroundColor: const Color(0xFFF1F5F9),
                  valueColor: AlwaysStoppedAnimation<Color>(cor),
                ),
              ),
              // Alerta sem bola (só para eventos ativos)
              if (!_inativo && evento.semBola) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: Color(0xFFEF4444), size: 14),
                      SizedBox(width: 6),
                      Text(
                        'Alerta: Sem bola confirmada',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static Color _corFundo(NivelViabilidade nivel) => switch (nivel) {
        NivelViabilidade.alta => const Color(0xFFECFDF5),
        NivelViabilidade.media => const Color(0xFFFEFCE8),
        NivelViabilidade.baixa => const Color(0xFFFEF2F2),
      };
}

class _AcessoBadge extends StatelessWidget {
  final RegraAcesso regra;
  const _AcessoBadge({required this.regra});

  @override
  Widget build(BuildContext context) {
    final (label, icon, bg, fg) = switch (regra) {
      RegraAcesso.parceiros => (
          'Parceiros',
          Icons.handshake_outlined,
          const Color(0xFFFFF7ED),
          const Color(0xFFD97706),
        ),
      RegraAcesso.somenteAtletica => (
          'Restrito',
          Icons.lock_outline,
          const Color(0xFFEFF6FF),
          const Color(0xFF2563EB),
        ),
      _ => ('', Icons.public, Colors.transparent, Colors.transparent),
    };
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: fg),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
