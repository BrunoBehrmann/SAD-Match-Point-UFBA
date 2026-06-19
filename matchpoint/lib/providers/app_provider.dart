import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_user.dart';
import '../models/atletica.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class AppProvider extends ChangeNotifier {
  final AuthService _auth = AuthService();
  final FirestoreService _db = FirestoreService();

  AppUser? _usuario;
  Atletica? _atletica;
  bool _carregando = false;
  String? _erro;

  AppUser? get usuario => _usuario;
  Atletica? get atletica => _atletica;
  bool get carregando => _carregando;
  String? get erro => _erro;
  bool get isGestor =>
      _atletica?.gestoresIds.contains(_usuario?.id) ?? false;

  void init() {
    _auth.authStateChanges.listen(
      (user) async {
        if (user == null) {
          _usuario = null;
          _atletica = null;
          notifyListeners();
          return;
        }
        await _carregarPerfil(user.uid);
      },
      onError: (e) {
        _erro = e.toString();
        notifyListeners();
      },
    );
  }

  Future<void> _carregarPerfil(String uid) async {
    _carregando = true;
    notifyListeners();
    try {
      _usuario = await _db.getUsuario(uid);
      if (_usuario != null && _usuario!.atleticaId.isNotEmpty) {
        _atletica = await _db.getAtletica(_usuario!.atleticaId);
      }
      _db.encerrarEventosExpirados(); // fire-and-forget: cobre períodos offline
    } catch (e) {
      _erro = e.toString();
    } finally {
      _carregando = false;
      notifyListeners();
    }
  }

  Future<User?> signInWithGoogle() async {
    _carregando = true;
    _erro = null;
    notifyListeners();
    try {
      final result = await _auth.signInWithGoogle();
      return result.user;
    } catch (e) {
      _erro = e.toString();
      return null;
    } finally {
      _carregando = false;
      notifyListeners();
    }
  }

  Future<bool> cadastrarPerfil({
    required String nome,
    required String curso,
    required String atleticaId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return false;
    _carregando = true;
    _erro = null;
    notifyListeners();
    try {
      await _auth.criarPerfil(
        uid: user.uid,
        nome: nome,
        email: user.email ?? '',
        curso: curso,
        atleticaId: atleticaId,
      );
      await _carregarPerfil(user.uid);
      return true;
    } catch (e) {
      _erro = e.toString();
      return false;
    } finally {
      _carregando = false;
      notifyListeners();
    }
  }

  Future<void> atualizarPerfil({
    String? nome,
    String? curso,
    String? atleticaId,
  }) async {
    if (_usuario == null) return;
    final dados = <String, dynamic>{};
    if (nome != null) dados['nome'] = nome;
    if (curso != null) dados['curso'] = curso;
    if (atleticaId != null) dados['atleticaId'] = atleticaId;
    await _db.atualizarPerfil(_usuario!.id, dados);
    await _carregarPerfil(_usuario!.id);
  }

  /// Tenta ativar o código de gestor. Retorna null se ok, ou mensagem de erro.
  Future<String?> ativarCodigoGestor(String codigo) async {
    if (_usuario == null || _atletica == null) return 'Perfil não carregado.';
    _carregando = true;
    _erro = null;
    notifyListeners();
    try {
      final sucesso = await _db.ativarCodigoGestor(
        atleticaId: _atletica!.id,
        codigo: codigo,
        userId: _usuario!.id,
      );
      if (!sucesso) return 'Código inválido. Verifique com o administrador.';
      await _carregarPerfil(_usuario!.id);
      return null;
    } catch (e) {
      return 'Erro ao ativar código: $e';
    } finally {
      _carregando = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    _usuario = null;
    _atletica = null;
    notifyListeners();
  }

  bool get autenticado => _auth.currentUser != null;
  bool get perfilCompleto => _usuario != null;
  String? get currentUid => _auth.currentUser?.uid;
  String? get currentEmail => _auth.currentUser?.email;
  String? get currentNome => _auth.currentUser?.displayName;
}
