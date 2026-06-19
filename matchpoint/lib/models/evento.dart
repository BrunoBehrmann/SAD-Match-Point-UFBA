import 'package:cloud_firestore/cloud_firestore.dart';

enum RegraAcesso { aberto, parceiros, somenteAtletica }

enum EventStatus { aberto, encerrado, cancelado }

class Local {
  final String nome;
  final double latitude;
  final double longitude;
  final bool usaCeef;
  final String? endereco;

  const Local({
    required this.nome,
    required this.latitude,
    required this.longitude,
    this.usaCeef = false,
    this.endereco,
  });

  factory Local.fromMap(Map<String, dynamic> m) => Local(
        nome: m['nome'] ?? '',
        latitude: (m['latitude'] ?? 0.0).toDouble(),
        longitude: (m['longitude'] ?? 0.0).toDouble(),
        usaCeef: m['usaCeef'] ?? false,
        endereco: m['endereco'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'nome': nome,
        'latitude': latitude,
        'longitude': longitude,
        'usaCeef': usaCeef,
        if (endereco != null) 'endereco': endereco,
      };
}

class ConfirmacaoUsuario {
  final String usuarioId;
  final String nomeUsuario;
  final List<String> materiaisQueVaiLevar;
  final bool checkInRealizado;
  final DateTime? timestampCheckIn;
  final double taxaConfiabilidade;

  const ConfirmacaoUsuario({
    required this.usuarioId,
    required this.nomeUsuario,
    this.materiaisQueVaiLevar = const [],
    this.checkInRealizado = false,
    this.timestampCheckIn,
    this.taxaConfiabilidade = 0.5,
  });

  factory ConfirmacaoUsuario.fromMap(Map<String, dynamic> m) =>
      ConfirmacaoUsuario(
        usuarioId: m['usuarioId'] ?? '',
        nomeUsuario: m['nomeUsuario'] ?? '',
        materiaisQueVaiLevar:
            List<String>.from(m['materiaisQueVaiLevar'] ?? []),
        checkInRealizado: m['checkInRealizado'] ?? false,
        timestampCheckIn: m['timestampCheckIn'] != null
            ? (m['timestampCheckIn'] as Timestamp).toDate()
            : null,
        taxaConfiabilidade:
            (m['taxaConfiabilidade'] ?? 0.5).toDouble(),
      );

  Map<String, dynamic> toMap() => {
        'usuarioId': usuarioId,
        'nomeUsuario': nomeUsuario,
        'materiaisQueVaiLevar': materiaisQueVaiLevar,
        'checkInRealizado': checkInRealizado,
        'timestampCheckIn': timestampCheckIn != null
            ? Timestamp.fromDate(timestampCheckIn!)
            : null,
        'taxaConfiabilidade': taxaConfiabilidade,
      };

  ConfirmacaoUsuario copyWith({
    List<String>? materiaisQueVaiLevar,
    bool? checkInRealizado,
    DateTime? timestampCheckIn,
  }) =>
      ConfirmacaoUsuario(
        usuarioId: usuarioId,
        nomeUsuario: nomeUsuario,
        materiaisQueVaiLevar:
            materiaisQueVaiLevar ?? this.materiaisQueVaiLevar,
        checkInRealizado: checkInRealizado ?? this.checkInRealizado,
        timestampCheckIn: timestampCheckIn ?? this.timestampCheckIn,
        taxaConfiabilidade: taxaConfiabilidade,
      );
}

class Evento {
  final String id;
  final String atleticaId;
  final String criadoPorId;
  final String criadoPorNome;
  final String nome;
  final String esporte;
  final Local local;
  final DateTime dataHora;
  final int minimoJogadores;
  final RegraAcesso regraAcesso;
  // IDs das atléticas parceiras (além da própria atleticaId) que podem confirmar.
  // Só relevante quando regraAcesso == RegraAcesso.parceiros.
  final List<String> atleticasParceiraIds;
  final List<String> materiaisNecessarios;
  final List<ConfirmacaoUsuario> confirmados;
  final double indiceViabilidade;
  final EventStatus status;
  final List<String> cientesCancelamento;

  const Evento({
    required this.id,
    required this.atleticaId,
    required this.criadoPorId,
    this.criadoPorNome = '',
    required this.nome,
    required this.esporte,
    required this.local,
    required this.dataHora,
    required this.minimoJogadores,
    required this.regraAcesso,
    this.atleticasParceiraIds = const [],
    required this.materiaisNecessarios,
    this.confirmados = const [],
    this.indiceViabilidade = 0.0,
    this.status = EventStatus.aberto,
    this.cientesCancelamento = const [],
  });

  /// Retorna true se o usuário com [userAtleticaId] pode confirmar presença.
  bool podeConfirmar(String userAtleticaId) {
    switch (regraAcesso) {
      case RegraAcesso.aberto:
        return true;
      case RegraAcesso.parceiros:
        return userAtleticaId == atleticaId ||
            atleticasParceiraIds.contains(userAtleticaId);
      case RegraAcesso.somenteAtletica:
        return userAtleticaId == atleticaId;
    }
  }

  factory Evento.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final esporte = data['esporte'] ?? '';
    return Evento(
      id: doc.id,
      atleticaId: data['atleticaId'] ?? '',
      criadoPorId: data['criadoPorId'] ?? '',
      criadoPorNome: data['criadoPorNome'] ?? '',
      nome: (data['nome'] as String?)?.isNotEmpty == true
          ? data['nome'] as String
          : esporte,
      esporte: esporte,
      local: Local.fromMap((data['local'] as Map<String, dynamic>?) ?? {}),
      dataHora: data['dataHora'] != null
          ? (data['dataHora'] as Timestamp).toDate()
          : DateTime.now(),
      minimoJogadores: data['minimoJogadores'] ?? 2,
      regraAcesso: RegraAcesso.values.firstWhere(
        (e) => e.name == data['regraAcesso'],
        orElse: () => RegraAcesso.aberto,
      ),
      atleticasParceiraIds:
          List<String>.from(data['atleticasParceiraIds'] ?? []),
      materiaisNecessarios:
          List<String>.from(data['materiaisNecessarios'] ?? []),
      confirmados: (data['confirmados'] as List<dynamic>? ?? [])
          .map((e) => ConfirmacaoUsuario.fromMap(e as Map<String, dynamic>))
          .toList(),
      indiceViabilidade: (data['indiceViabilidade'] ?? 0.0).toDouble(),
      status: EventStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => EventStatus.aberto,
      ),
      cientesCancelamento:
          List<String>.from(data['cientesCancelamento'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'atleticaId': atleticaId,
        'criadoPorId': criadoPorId,
        'criadoPorNome': criadoPorNome,
        'nome': nome,
        'esporte': esporte,
        'local': local.toMap(),
        'dataHora': Timestamp.fromDate(dataHora),
        'minimoJogadores': minimoJogadores,
        'regraAcesso': regraAcesso.name,
        'atleticasParceiraIds': atleticasParceiraIds,
        'materiaisNecessarios': materiaisNecessarios,
        'confirmados': confirmados.map((c) => c.toMap()).toList(),
        'indiceViabilidade': indiceViabilidade,
        'status': status.name,
        'cientesCancelamento': cientesCancelamento,
      };

  bool get semBola {
    bool ehBola(String m) => m.toLowerCase().contains('bola');
    if (!materiaisNecessarios.any(ehBola)) return false;
    return confirmados.every((c) => !c.materiaisQueVaiLevar.any(ehBola));
  }

  Evento copyWith({
    List<ConfirmacaoUsuario>? confirmados,
    double? indiceViabilidade,
    EventStatus? status,
  }) =>
      Evento(
        id: id,
        atleticaId: atleticaId,
        criadoPorId: criadoPorId,
        criadoPorNome: criadoPorNome,
        nome: nome,
        esporte: esporte,
        local: local,
        dataHora: dataHora,
        minimoJogadores: minimoJogadores,
        regraAcesso: regraAcesso,
        atleticasParceiraIds: atleticasParceiraIds,
        materiaisNecessarios: materiaisNecessarios,
        confirmados: confirmados ?? this.confirmados,
        indiceViabilidade: indiceViabilidade ?? this.indiceViabilidade,
        status: status ?? this.status,
      );
}
