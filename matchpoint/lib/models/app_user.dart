import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { atleta, gestor }

class AppUser {
  final String id;
  final String nome;
  final String email;
  final String curso;
  final String atleticaId;
  final UserRole role;
  final double taxaConfiabilidade;
  final int streakPresencas;
  final int totalComparecimentos;
  final int totalConfirmacoes;
  final double pontuacaoRanking;

  const AppUser({
    required this.id,
    required this.nome,
    required this.email,
    required this.curso,
    required this.atleticaId,
    this.role = UserRole.atleta,
    this.taxaConfiabilidade = 0.5,
    this.streakPresencas = 0,
    this.totalComparecimentos = 0,
    this.totalConfirmacoes = 0,
    this.pontuacaoRanking = 0.0,
  });

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppUser(
      id: doc.id,
      nome: data['nome'] ?? '',
      email: data['email'] ?? '',
      curso: data['curso'] ?? '',
      atleticaId: data['atleticaId'] ?? '',
      role: UserRole.values.firstWhere(
        (r) => r.name == data['role'],
        orElse: () => UserRole.atleta,
      ),
      taxaConfiabilidade: (data['taxaConfiabilidade'] ?? 0.5).toDouble(),
      streakPresencas: data['streakPresencas'] ?? 0,
      totalComparecimentos: data['totalComparecimentos'] ?? 0,
      totalConfirmacoes: data['totalConfirmacoes'] ?? 0,
      pontuacaoRanking: (data['pontuacaoRanking'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'nome': nome,
        'email': email,
        'curso': curso,
        'atleticaId': atleticaId,
        'role': role.name,
        'taxaConfiabilidade': taxaConfiabilidade,
        'streakPresencas': streakPresencas,
        'totalComparecimentos': totalComparecimentos,
        'totalConfirmacoes': totalConfirmacoes,
        'pontuacaoRanking': pontuacaoRanking,
      };

  AppUser copyWith({
    String? nome,
    String? curso,
    String? atleticaId,
    UserRole? role,
    double? taxaConfiabilidade,
    int? streakPresencas,
    int? totalComparecimentos,
    int? totalConfirmacoes,
    double? pontuacaoRanking,
  }) =>
      AppUser(
        id: id,
        nome: nome ?? this.nome,
        email: email,
        curso: curso ?? this.curso,
        atleticaId: atleticaId ?? this.atleticaId,
        role: role ?? this.role,
        taxaConfiabilidade: taxaConfiabilidade ?? this.taxaConfiabilidade,
        streakPresencas: streakPresencas ?? this.streakPresencas,
        totalComparecimentos: totalComparecimentos ?? this.totalComparecimentos,
        totalConfirmacoes: totalConfirmacoes ?? this.totalConfirmacoes,
        pontuacaoRanking: pontuacaoRanking ?? this.pontuacaoRanking,
      );
}
