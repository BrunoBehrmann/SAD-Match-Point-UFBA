import 'dart:math';
import 'package:flutter/material.dart';
import '../models/evento.dart';
import '../utils/viabilidade.dart';

/// Exibe o breakdown do Índice de Viabilidade em um BottomSheet.
/// Mostra os três fatores (Quórum, Clima, Confiabilidade) com barras e
/// frases de apoio à decisão. O percentual numérico total só aparece
/// para gestores (isGestor: true).
void mostrarViabilidadeDetalhe({
  required BuildContext context,
  required Evento evento,
  required double? chanceChuva,
  required bool isGestor,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _ViabilidadeDetalheSheet(
      evento: evento,
      chanceChuva: chanceChuva,
      isGestor: isGestor,
    ),
  );
}

class _ViabilidadeDetalheSheet extends StatelessWidget {
  final Evento evento;
  final double? chanceChuva;
  final bool isGestor;

  const _ViabilidadeDetalheSheet({
    required this.evento,
    required this.chanceChuva,
    required this.isGestor,
  });

  @override
  Widget build(BuildContext context) {
    final confirmados = evento.confirmados.length;
    final minimo = evento.minimoJogadores;
    final chuva = chanceChuva;

    // Fatores individuais
    final fatorQuorum =
        minimo > 0 ? min(confirmados / minimo, 1.0) : 1.0;
    final fatorClima =
        chuva != null ? 1.0 - (chuva / 100) : null;

    // taxaFaltaMedia é null quando não há confirmados:
    // confiabilidade é excluída do cálculo (não há dado, não há estimativa)
    final semHistoricoConf = evento.confirmados.isEmpty;
    final taxaFaltaMedia = semHistoricoConf
        ? null
        : evento.confirmados
                .map((c) => 1.0 - c.taxaConfiabilidade)
                .reduce((a, b) => a + b) /
            evento.confirmados.length;
    final fatorConf =
        taxaFaltaMedia != null ? 1.0 - taxaFaltaMedia : null;

    // Contribuição ponderada de cada fator
    final contribQuorum = fatorQuorum * 0.20;
    final contribClima = (fatorClima ?? 0.0) * 0.45;
    final contribConf = fatorConf != null ? fatorConf * 0.35 : 0.0;

    // Recalculado com os dados atuais — mais preciso que o valor armazenado
    final indiceRecalculado = fatorClima != null
        ? calcularViabilidade(
            confirmados: confirmados,
            minimo: minimo,
            chanceChuva: chuva!,
            taxaFaltaMedia: taxaFaltaMedia, // null = sem confiabilidade
          )
        : evento.indiceViabilidade;

    final nivel = classificarViabilidade(indiceRecalculado);
    final corIndice = corViabilidade(nivel);

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
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

          // Título + índice total (apenas gestores)
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Índice de Viabilidade',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Como esse evento foi avaliado',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              if (isGestor)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: corIndice.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: corIndice.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '${(indiceRecalculado * 100).round()}%',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: corIndice,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),

          // Fator Quórum
          _FatorCard(
            titulo: 'Quórum de jogadores',
            peso: 20,
            fator: fatorQuorum,
            contribuicao: contribQuorum,
            descricao: confirmados == 0
                ? 'Nenhum jogador confirmado ainda'
                : '$confirmados de $minimo jogadores confirmados',
            fraseApoio: _fraseQuorum(confirmados, minimo),
            corFrase: _corFraseQuorum(confirmados, minimo),
            icone: Icons.people,
          ),
          const SizedBox(height: 12),

          // Fator Clima
          _FatorCard(
            titulo: 'Condição climática',
            peso: 45,
            fator: fatorClima,
            contribuicao: contribClima,
            descricao: chuva == null
                ? 'Dados de clima não disponíveis'
                : 'Chance de chuva: ${chuva.toStringAsFixed(0)}%',
            fraseApoio: _fraseClima(chuva),
            corFrase: _corFraseClima(chuva),
            icone: Icons.wb_cloudy,
            indisponivel: chuva == null,
          ),
          const SizedBox(height: 12),

          // Fator Confiabilidade
          _FatorCard(
            titulo: 'Confiabilidade do grupo',
            peso: 35,
            fator: fatorConf,
            contribuicao: contribConf,
            descricao: semHistoricoConf
                ? 'Sem confirmados — histórico indisponível'
                : 'Taxa média de presença: ${(fatorConf! * 100).toStringAsFixed(0)}%',
            fraseApoio: _fraseConf(fatorConf, semHistoricoConf),
            corFrase: _corFraseConf(fatorConf, semHistoricoConf),
            icone: Icons.verified_user,
            indisponivel: semHistoricoConf,
          ),
          const SizedBox(height: 20),

          // Frase final de apoio à decisão
          _FraseFinal(indice: indiceRecalculado, isGestor: isGestor),

          // Aviso: sem confirmados, o índice fica limitado (confiabilidade desligada)
          if (semHistoricoConf) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline,
                      size: 18, color: Color(0xFF64748B)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Sem confirmados, o índice fica limitado a 65%. '
                      'A confiabilidade do grupo (35%) entra no cálculo '
                      'após a primeira confirmação.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),

          // Nota SAD
          const Text(
            'Este índice é uma estimativa para apoiar sua decisão — '
            'o organizador tem a palavra final.',
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF94A3B8),
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _fraseQuorum(int confirmados, int minimo) {
    if (confirmados == 0) return 'Divulgue o evento para atrair jogadores';
    if (confirmados >= minimo) return 'Quórum mínimo atingido ✓';
    final faltam = minimo - confirmados;
    return 'Faltam $faltam jogador${faltam > 1 ? 'es' : ''} para o mínimo';
  }

  Color _corFraseQuorum(int confirmados, int minimo) {
    if (confirmados >= minimo) return const Color(0xFF16A34A);
    if (confirmados == 0) return const Color(0xFFDC2626);
    return const Color(0xFFD97706);
  }

  String _fraseClima(double? chuva) {
    if (chuva == null) return 'Verifique a previsão antes de decidir';
    if (chuva <= 20) return 'Clima favorável para o evento ✓';
    if (chuva <= 50) return 'Clima incerto — considere um plano B';
    return 'Alto risco de chuva — avalie reagendar ⚠';
  }

  Color _corFraseClima(double? chuva) {
    if (chuva == null) return const Color(0xFF94A3B8);
    if (chuva <= 20) return const Color(0xFF16A34A);
    if (chuva <= 50) return const Color(0xFFD97706);
    return const Color(0xFFDC2626);
  }

  String _fraseConf(double? fator, bool semConfirmados) {
    if (semConfirmados) return 'Disponível após a primeira confirmação';
    if (fator! >= 0.80) return 'Grupo com ótimo histórico de presença ✓';
    if (fator >= 0.60) return 'Histórico razoável — alguns podem faltar';
    return 'Histórico irregular — considere o risco de cancelamento ⚠';
  }

  Color _corFraseConf(double? fator, bool semConfirmados) {
    if (semConfirmados) return const Color(0xFF94A3B8);
    if (fator! >= 0.80) return const Color(0xFF16A34A);
    if (fator >= 0.60) return const Color(0xFFD97706);
    return const Color(0xFFDC2626);
  }
}

class _FatorCard extends StatelessWidget {
  final String titulo;
  final int peso;
  final double? fator;
  final double contribuicao;
  final String descricao;
  final String fraseApoio;
  final Color corFrase;
  final IconData icone;
  final bool indisponivel;

  const _FatorCard({
    required this.titulo,
    required this.peso,
    required this.fator,
    required this.contribuicao,
    required this.descricao,
    required this.fraseApoio,
    required this.corFrase,
    required this.icone,
    this.indisponivel = false,
  });

  @override
  Widget build(BuildContext context) {
    final valorFator = fator ?? 0.0;
    final barColor = indisponivel
        ? const Color(0xFFCBD5E1)
        : _corBarra(valorFator);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: const Border.fromBorderSide(
            BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: barColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icone, color: barColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Peso: $peso%',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              // Contribuição ponderada
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    indisponivel
                        ? '--'
                        : '${(valorFator * 100).round()}%',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: barColor,
                    ),
                  ),
                  Text(
                    indisponivel
                        ? 'do fator'
                        : '+${(contribuicao * 100).toStringAsFixed(1)}pts',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Barra de progresso
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: indisponivel ? 0 : valorFator,
              minHeight: 8,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          const SizedBox(height: 8),

          // Descrição
          Text(
            descricao,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 4),

          // Frase de apoio à decisão
          Text(
            fraseApoio,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: corFrase,
            ),
          ),
        ],
      ),
    );
  }

  Color _corBarra(double valor) {
    if (valor >= 0.70) return const Color(0xFF16A34A);
    if (valor >= 0.40) return const Color(0xFFD97706);
    return const Color(0xFFDC2626);
  }
}

class _FraseFinal extends StatelessWidget {
  final double indice;
  final bool isGestor;
  const _FraseFinal({required this.indice, required this.isGestor});

  @override
  Widget build(BuildContext context) {
    final (frase, cor, icone) = _conteudo();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cor.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, color: cor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              frase,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: cor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  (String, Color, IconData) _conteudo() {
    if (indice >= 0.70) {
      return (
        isGestor
            ? 'Alta probabilidade de acontecer. Tudo indica que o evento está bem encaminhado.'
            : 'Alta probabilidade de acontecer. Confirme sua presença!',
        const Color(0xFF16A34A),
        Icons.check_circle_outline,
      );
    }
    if (indice >= 0.40) {
      return (
        isGestor
            ? 'Risco moderado. Verifique o fator com menor pontuação e tome uma ação antes do evento.'
            : 'Probabilidade moderada. Fique atento a atualizações do evento.',
        const Color(0xFFD97706),
        Icons.warning_amber_outlined,
      );
    }
    return (
      isGestor
          ? 'Baixa viabilidade. Considere remarcar ou divulgar mais o evento para aumentar o quórum.'
          : 'Baixa probabilidade no momento. O organizador pode remarcar o evento.',
      const Color(0xFFDC2626),
      Icons.cancel_outlined,
    );
  }
}
