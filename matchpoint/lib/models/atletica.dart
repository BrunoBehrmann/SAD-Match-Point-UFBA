import 'package:cloud_firestore/cloud_firestore.dart';

class GradeHoraria {
  final String diaSemana;
  final String horaInicio;
  final String horaFim;
  final String local;

  const GradeHoraria({
    required this.diaSemana,
    required this.horaInicio,
    required this.horaFim,
    required this.local,
  });

  factory GradeHoraria.fromMap(Map<String, dynamic> m) => GradeHoraria(
        diaSemana: m['diaSemana'] ?? '',
        horaInicio: m['horaInicio'] ?? '',
        horaFim: m['horaFim'] ?? '',
        local: m['local'] ?? '',
      );

  Map<String, dynamic> toMap() => {
        'diaSemana': diaSemana,
        'horaInicio': horaInicio,
        'horaFim': horaFim,
        'local': local,
      };
}

class Atletica {
  final String id;
  final String nome;
  final String curso;
  final List<GradeHoraria> gradeHoraria;
  final int faltasConsecutivas;
  final List<String> gestoresIds;
  final String codigoGestor;

  const Atletica({
    required this.id,
    required this.nome,
    this.curso = '',
    this.gradeHoraria = const [],
    this.faltasConsecutivas = 0,
    this.gestoresIds = const [],
    this.codigoGestor = '',
  });

  factory Atletica.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Atletica(
      id: doc.id,
      nome: data['nome'] ?? '',
      curso: data['curso'] ?? '',
      gradeHoraria: (data['gradeHoraria'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(GradeHoraria.fromMap)
          .toList(),
      faltasConsecutivas: data['faltasConsecutivas'] ?? 0,
      gestoresIds: List<String>.from(data['gestoresIds'] ?? []),
      codigoGestor: data['codigoGestor'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'nome': nome,
        'curso': curso,
        'gradeHoraria': gradeHoraria.map((g) => g.toMap()).toList(),
        'faltasConsecutivas': faltasConsecutivas,
        'gestoresIds': gestoresIds,
        'codigoGestor': codigoGestor,
      };
}
