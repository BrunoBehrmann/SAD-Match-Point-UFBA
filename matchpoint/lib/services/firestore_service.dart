import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';
import '../models/evento.dart';
import '../models/atletica.dart';
import '../utils/viabilidade.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- Usuários ---

  Stream<AppUser?> streamUsuario(String uid) => _db
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((doc) => doc.exists ? AppUser.fromFirestore(doc) : null);

  Future<AppUser?> getUsuario(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.exists ? AppUser.fromFirestore(doc) : null;
  }

  Future<void> atualizarPerfil(String uid, Map<String, dynamic> dados) =>
      _db.collection('users').doc(uid).update(dados);

  Future<List<AppUser>> getRankingAtletica(String atleticaId) async {
    final snap = await _db
        .collection('users')
        .where('atleticaId', isEqualTo: atleticaId)
        .get();
    final lista = snap.docs.map(AppUser.fromFirestore).toList();
    lista.sort((a, b) => b.pontuacaoRanking.compareTo(a.pontuacaoRanking));
    return lista;
  }

  Future<List<AppUser>> getRankingGeral() async {
    final snap = await _db.collection('users').get();
    final lista = snap.docs.map(AppUser.fromFirestore).toList();
    lista.sort((a, b) => b.pontuacaoRanking.compareTo(a.pontuacaoRanking));
    return lista;
  }

  // --- Atléticas ---

  Future<Atletica?> getAtletica(String id) async {
    final doc = await _db.collection('atleticas').doc(id).get();
    return doc.exists ? Atletica.fromFirestore(doc) : null;
  }

  // Cache de nomes de atléticas — válido por sessão (nome raramente muda).
  static final Map<String, String> _nomeAtleticaCache = {};

  /// Retorna o nome da atlética, usando cache para evitar re-fetch redundante.
  Future<String?> getNomeAtletica(String id) async {
    final cached = _nomeAtleticaCache[id];
    if (cached != null) return cached;
    final at = await getAtletica(id);
    if (at != null) _nomeAtleticaCache[id] = at.nome;
    return at?.nome;
  }

  Stream<Atletica?> streamAtletica(String id) => _db
      .collection('atleticas')
      .doc(id)
      .snapshots()
      .map((doc) => doc.exists ? Atletica.fromFirestore(doc) : null);

  Stream<List<AppUser>> streamAtletasAtletica(String atleticaId) => _db
      .collection('users')
      .where('atleticaId', isEqualTo: atleticaId)
      .snapshots()
      .map((snap) => snap.docs.map(AppUser.fromFirestore).toList());

  Future<void> promoverTreinador(String atleticaId, String userId) =>
      _db.collection('atleticas').doc(atleticaId).update({
        'gestoresIds': FieldValue.arrayUnion([userId]),
      });

  Future<void> rebaixarTreinador(String atleticaId, String userId) =>
      _db.collection('atleticas').doc(atleticaId).update({
        'gestoresIds': FieldValue.arrayRemove([userId]),
      });

  /// Retorna true se o código estava correto e o usuário foi promovido.
  Future<bool> ativarCodigoGestor({
    required String atleticaId,
    required String codigo,
    required String userId,
  }) async {
    final doc = await _db.collection('atleticas').doc(atleticaId).get();
    final data = doc.data() as Map<String, dynamic>;
    final codigoCorreto = (data['codigoGestor'] as String? ?? '').trim();
    if (codigoCorreto.isEmpty || codigo.trim() != codigoCorreto) return false;
    await promoverTreinador(atleticaId, userId);
    return true;
  }

  Future<List<Atletica>> listarAtleticas() async {
    final snap = await _db
        .collection('atleticas')
        .get(const GetOptions(source: Source.server));
    return snap.docs.map(Atletica.fromFirestore).toList();
  }

  // --- Eventos ---

  Stream<List<Evento>> streamEventosAbertos() => _db
      .collection('eventos')
      .where('status', isEqualTo: 'aberto')
      .snapshots()
      .map((snap) {
        final lista = snap.docs.map(Evento.fromFirestore).toList();
        final agora = DateTime.now();
        for (final evento in lista) {
          if (agora.isAfter(evento.dataHora.add(const Duration(hours: 6)))) {
            encerrarEvento(evento.id); // fire-and-forget: encerra em background
          }
        }
        lista.sort((a, b) =>
            b.indiceViabilidade.compareTo(a.indiceViabilidade));
        return lista;
      });

  /// Encerra todos os eventos abertos cuja janela de check-in já fechou
  /// (dataHora + 6h < agora). Chamado no login para cobrir períodos offline.
  Future<void> encerrarEventosExpirados() async {
    final snap = await _db
        .collection('eventos')
        .where('status', isEqualTo: 'aberto')
        .get();
    final agora = DateTime.now();
    for (final doc in snap.docs) {
      final evento = Evento.fromFirestore(doc);
      if (agora.isAfter(evento.dataHora.add(const Duration(hours: 6)))) {
        await encerrarEvento(evento.id);
      }
    }
  }

  Stream<List<Evento>> streamEventosConfirmados(String userId) => _db
      .collection('eventos')
      .snapshots()
      .map((snap) {
        final lista = snap.docs
            .map(Evento.fromFirestore)
            .where((e) => e.confirmados.any((c) => c.usuarioId == userId))
            .toList();
        // Abertos primeiro, depois encerrados/cancelados; dentro de cada grupo por data desc
        lista.sort((a, b) {
          final aAtivo = a.status == EventStatus.aberto ? 0 : 1;
          final bAtivo = b.status == EventStatus.aberto ? 0 : 1;
          if (aAtivo != bAtivo) return aAtivo.compareTo(bAtivo);
          return b.dataHora.compareTo(a.dataHora);
        });
        return lista;
      });

  Stream<List<Evento>> streamEventosCriados(String userId) => _db
      .collection('eventos')
      .where('criadoPorId', isEqualTo: userId)
      .snapshots()
      .map((snap) {
        final lista = snap.docs.map(Evento.fromFirestore).toList();
        // Abertos primeiro, depois encerrados/cancelados; dentro de cada grupo por data desc
        lista.sort((a, b) {
          final aAtivo = a.status == EventStatus.aberto ? 0 : 1;
          final bAtivo = b.status == EventStatus.aberto ? 0 : 1;
          if (aAtivo != bAtivo) return aAtivo.compareTo(bAtivo);
          return b.dataHora.compareTo(a.dataHora);
        });
        return lista;
      });

  Stream<Evento?> streamEvento(String id) => _db
      .collection('eventos')
      .doc(id)
      .snapshots()
      .map((doc) => doc.exists ? Evento.fromFirestore(doc) : null);

  Future<Evento?> getEvento(String id) async {
    final doc = await _db.collection('eventos').doc(id).get();
    return doc.exists ? Evento.fromFirestore(doc) : null;
  }

  Future<String> criarEvento(Evento evento) async {
    final ref = await _db.collection('eventos').add(evento.toFirestore());
    return ref.id;
  }

  Future<void> atualizarEvento(String id, Map<String, dynamic> dados) =>
      _db.collection('eventos').doc(id).update(dados);

  Future<void> cancelarEvento(String id) => _db
      .collection('eventos')
      .doc(id)
      .update({'status': 'cancelado', 'cientesCancelamento': []});

  /// Encerra o evento (status -> encerrado) e atualiza a confiabilidade dos
  /// confirmados: quem não fez check-in tem a streak zerada e a taxa
  /// recalculada (a falta já está refletida em totalConfirmacoes).
  /// Retorna um resumo { totalConfirmados, totalCheckIns, faltantes }.
  Future<Map<String, dynamic>> encerrarEvento(String eventoId) async {
    final eventoRef = _db.collection('eventos').doc(eventoId);
    final snap = await eventoRef.get();
    if (!snap.exists) throw Exception('Evento não encontrado');
    final evento = Evento.fromFirestore(snap);

    final faltantes = <String>[];
    int totalCheckIns = 0;
    for (final c in evento.confirmados) {
      if (c.checkInRealizado) {
        totalCheckIns++;
      } else {
        faltantes.add(c.nomeUsuario);
      }
    }

    // Já encerrado: retorna o resumo sem reprocessar faltas (idempotência)
    if (evento.status == EventStatus.encerrado) {
      return {
        'totalConfirmados': evento.confirmados.length,
        'totalCheckIns': totalCheckIns,
        'faltantes': faltantes,
      };
    }

    await eventoRef.update({'status': 'encerrado'});

    for (final c in evento.confirmados) {
      if (!c.checkInRealizado) await _registrarFalta(c.usuarioId);
    }

    return {
      'totalConfirmados': evento.confirmados.length,
      'totalCheckIns': totalCheckIns,
      'faltantes': faltantes,
    };
  }

  /// Zera a streak e recalcula a taxa/ranking de quem confirmou mas faltou.
  Future<void> _registrarFalta(String userId) async {
    final ref = _db.collection('users').doc(userId);

    String atleticaId = '';
    double novaTaxa = 0.5;
    int comparecimentos = 0;

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final user = AppUser.fromFirestore(snap);
      atleticaId = user.atleticaId;
      comparecimentos = user.totalComparecimentos;
      novaTaxa = user.totalConfirmacoes > 0
          ? (user.totalComparecimentos / user.totalConfirmacoes)
              .clamp(0.0, 1.0)
          : 0.5;

      tx.update(ref, {
        'streakPresencas': 0,
        'taxaConfiabilidade': novaTaxa,
      });
    });

    if (atleticaId.isNotEmpty && atleticaId != 'sem-atletica') {
      await _atualizarRankingAposCheckIn(
          userId, atleticaId, novaTaxa, comparecimentos);
    }
  }

  Future<void> marcarCienteCancelamento(
      String eventoId, String userId) async {
    try {
      await _db.collection('eventos').doc(eventoId).update({
        'cientesCancelamento': FieldValue.arrayUnion([userId]),
      });
    } on FirebaseException catch (e) {
      if (e.code != 'not-found') rethrow;
      // Documento apagado — não há nada a marcar, ignorar silenciosamente
    }
  }

  /// Retorna eventos cancelados em que o usuário confirmou presença
  /// mas ainda não confirmou ciência do cancelamento.
  Stream<List<Evento>> streamCancelamentosNaoVistos(String userId) => _db
      .collection('eventos')
      .where('status', isEqualTo: 'cancelado')
      .snapshots()
      .map((snap) => snap.docs
          .map(Evento.fromFirestore)
          .where((e) =>
              e.confirmados.any((c) => c.usuarioId == userId) &&
              !e.cientesCancelamento.contains(userId))
          .toList());

  Future<void> excluirEvento(String id) =>
      _db.collection('eventos').doc(id).delete();

  Future<void> confirmarPresenca({
    required String eventoId,
    required ConfirmacaoUsuario confirmacao,
    required double novoIndice,
  }) async {
    final eventoRef = _db.collection('eventos').doc(eventoId);
    final userRef = _db.collection('users').doc(confirmacao.usuarioId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(eventoRef);
      final evento = Evento.fromFirestore(snap);

      final jaConfirmado =
          evento.confirmados.any((c) => c.usuarioId == confirmacao.usuarioId);
      if (jaConfirmado) return;

      final novosConfirmados = [...evento.confirmados, confirmacao];
      tx.update(eventoRef, {
        'confirmados': novosConfirmados.map((c) => c.toMap()).toList(),
        'indiceViabilidade': novoIndice,
      });
      tx.update(userRef, {
        'totalConfirmacoes': FieldValue.increment(1),
      });
    });
  }

  Future<void> cancelarPresenca({
    required String eventoId,
    required String userId,
    required double novoIndice,
  }) async {
    final eventoRef = _db.collection('eventos').doc(eventoId);
    final userRef = _db.collection('users').doc(userId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(eventoRef);
      final evento = Evento.fromFirestore(snap);
      final novosConfirmados =
          evento.confirmados.where((c) => c.usuarioId != userId).toList();
      tx.update(eventoRef, {
        'confirmados': novosConfirmados.map((c) => c.toMap()).toList(),
        'indiceViabilidade': novoIndice,
      });
      tx.update(userRef, {
        'totalConfirmacoes': FieldValue.increment(-1),
      });
    });
  }

  /// Atualiza os materiais que um confirmado vai levar (sem mexer no índice
  /// nem na confiabilidade — apenas a lista de materiais da confirmação).
  Future<void> atualizarMateriaisConfirmacao({
    required String eventoId,
    required String userId,
    required List<String> materiais,
  }) async {
    final ref = _db.collection('eventos').doc(eventoId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final evento = Evento.fromFirestore(snap);
      final idx = evento.confirmados.indexWhere((c) => c.usuarioId == userId);
      if (idx == -1) return;

      final atualizado =
          evento.confirmados[idx].copyWith(materiaisQueVaiLevar: materiais);
      final lista = [...evento.confirmados];
      lista[idx] = atualizado;

      tx.update(ref, {
        'confirmados': lista.map((c) => c.toMap()).toList(),
      });
    });
  }

  Future<void> realizarCheckIn({
    required String eventoId,
    required String userId,
  }) async {
    final ref = _db.collection('eventos').doc(eventoId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final evento = Evento.fromFirestore(snap);

      final idx = evento.confirmados.indexWhere((c) => c.usuarioId == userId);
      if (idx == -1) return;

      final updated = evento.confirmados[idx].copyWith(
        checkInRealizado: true,
        timestampCheckIn: DateTime.now(),
      );
      final lista = [...evento.confirmados];
      lista[idx] = updated;

      tx.update(ref, {
        'confirmados': lista.map((c) => c.toMap()).toList(),
      });
    });

    await _atualizarConfiabilidadeUsuario(userId);
  }

  Future<void> _atualizarConfiabilidadeUsuario(String userId) async {
    final ref = _db.collection('users').doc(userId);

    // Variáveis mutáveis — late final causaria crash em retry da transação
    String atleticaId = '';
    double novaTaxa = 0.5;
    int novoTotal = 0;

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final user = AppUser.fromFirestore(snap);

      atleticaId = user.atleticaId;
      novoTotal = user.totalComparecimentos + 1;
      final novaStreak = user.streakPresencas + 1;
      novaTaxa = user.totalConfirmacoes > 0
          ? (novoTotal / user.totalConfirmacoes).clamp(0.0, 1.0)
          : 0.5;

      tx.update(ref, {
        'totalComparecimentos': novoTotal,
        'streakPresencas': novaStreak,
        'taxaConfiabilidade': novaTaxa,
      });
    });

    // Atualiza ranking após gravar nova confiabilidade
    if (atleticaId.isNotEmpty && atleticaId != 'sem-atletica') {
      await _atualizarRankingAposCheckIn(
          userId, atleticaId, novaTaxa, novoTotal);
    }
  }

  /// Busca o máximo de comparecimentos na atlética e recalcula o ranking do usuário.
  /// Atualização lazy: cada usuário recalcula ao fazer check-in.
  Future<void> _atualizarRankingAposCheckIn(
    String userId,
    String atleticaId,
    double taxa,
    int comparecimentos,
  ) async {
    final snap = await _db
        .collection('users')
        .where('atleticaId', isEqualTo: atleticaId)
        .get();

    int maxComp = comparecimentos; // garante que o valor atual seja considerado
    for (final doc in snap.docs) {
      final u = AppUser.fromFirestore(doc);
      if (u.totalComparecimentos > maxComp) maxComp = u.totalComparecimentos;
    }

    await atualizarRankingUsuario(userId, taxa, comparecimentos, maxComp);
  }

  Future<void> atualizarRankingUsuario(
      String userId, double taxa, int comparecimentos, int maxGlobal) async {
    final pontuacao =
        calcularPontuacaoRanking(taxa, comparecimentos, maxGlobal);
    await _db
        .collection('users')
        .doc(userId)
        .update({'pontuacaoRanking': pontuacao});
  }

  // --- Dashboard (gestores) ---

  Future<Map<String, dynamic>> getDashboardAtletica(
      String atleticaId) async {
    final eventosSnap = await _db
        .collection('eventos')
        .where('atleticaId', isEqualTo: atleticaId)
        .get();

    final eventos = eventosSnap.docs.map(Evento.fromFirestore).toList();
    final total = eventos.length;
    final encerrados =
        eventos.where((e) => e.status == EventStatus.encerrado).toList();

    int totalConfirmacoes = 0;
    int totalCheckIns = 0;
    for (final e in encerrados) {
      totalConfirmacoes += e.confirmados.length;
      totalCheckIns +=
          e.confirmados.where((c) => c.checkInRealizado).length;
    }

    final taxaComparecimento = totalConfirmacoes > 0
        ? totalCheckIns / totalConfirmacoes
        : 0.0;

    final atletica = await getAtletica(atleticaId);
    final topJogadores = await getRankingAtletica(atleticaId);

    return {
      'totalEventos': total,
      'taxaComparecimento': taxaComparecimento,
      'topJogadores': topJogadores.take(5).toList(),
      'faltasConsecutivas': atletica?.faltasConsecutivas ?? 0,
    };
  }

  /// Versão detalhada para o novo dashboard: inclui distribuição por esporte,
  /// eventos recentes encerrados e contagem por status.
  Future<Map<String, dynamic>> getDashboardDetalhado(
      String atleticaId) async {
    final eventosSnap = await _db
        .collection('eventos')
        .where('atleticaId', isEqualTo: atleticaId)
        .get();

    final eventos = eventosSnap.docs.map(Evento.fromFirestore).toList();

    final abertos =
        eventos.where((e) => e.status == EventStatus.aberto).length;
    final encerrados =
        eventos.where((e) => e.status == EventStatus.encerrado).toList();
    final cancelados =
        eventos.where((e) => e.status == EventStatus.cancelado).length;

    int totalConfirmacoes = 0;
    int totalCheckIns = 0;
    final Map<String, int> porEsporte = {};

    for (final e in eventos) {
      porEsporte[e.esporte] = (porEsporte[e.esporte] ?? 0) + 1;
    }

    for (final e in encerrados) {
      totalConfirmacoes += e.confirmados.length;
      totalCheckIns += e.confirmados.where((c) => c.checkInRealizado).length;
    }

    final taxaComparecimento = totalConfirmacoes > 0
        ? totalCheckIns / totalConfirmacoes
        : 0.0;

    // Últimos 5 eventos encerrados, mais recente primeiro
    final recentes = [...encerrados]
      ..sort((a, b) => b.dataHora.compareTo(a.dataHora));

    final eventosRecentes = recentes.take(5).map((e) {
      final confs = e.confirmados.length;
      final checks = e.confirmados.where((c) => c.checkInRealizado).length;
      return {
        'nome': e.nome,
        'esporte': e.esporte,
        'dataHora': e.dataHora,
        'confirmados': confs,
        'checkIns': checks,
        'taxa': confs > 0 ? checks / confs : 0.0,
      };
    }).toList();

    final atletica = await getAtletica(atleticaId);
    final topJogadores = await getRankingAtletica(atleticaId);

    return {
      'totalEventos': eventos.length,
      'eventosAbertos': abertos,
      'eventosEncerrados': encerrados.length,
      'eventosCancelados': cancelados,
      'taxaComparecimento': taxaComparecimento,
      'porEsporte': porEsporte,
      'eventosRecentes': eventosRecentes,
      'topJogadores': topJogadores.take(5).toList(),
      'totalAtletas': topJogadores.length,
      'faltasConsecutivas': atletica?.faltasConsecutivas ?? 0,
    };
  }

  /// Busca múltiplos usuários por ID (para analytics do evento).
  /// Faz batches de 10 para respeitar o limite do Firestore whereIn.
  Future<List<AppUser>> getUsuariosBatch(List<String> ids) async {
    if (ids.isEmpty) return [];
    final results = <AppUser>[];
    for (var i = 0; i < ids.length; i += 10) {
      final batch = ids.skip(i).take(10).toList();
      final snap = await _db
          .collection('users')
          .where(FieldPath.documentId, whereIn: batch)
          .get();
      results.addAll(snap.docs.map(AppUser.fromFirestore));
    }
    return results;
  }
}
