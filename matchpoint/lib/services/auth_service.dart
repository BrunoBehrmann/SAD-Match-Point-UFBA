import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signInWithEmailPassword(
      String email, String password) async {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) throw Exception('Login cancelado');

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    return _auth.signInWithCredential(credential);
  }

  Future<bool> usuarioCadastrado(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.exists;
  }

  Future<void> criarPerfil({
    required String uid,
    required String nome,
    required String email,
    required String curso,
    required String atleticaId,
  }) async {
    final user = AppUser(
      id: uid,
      nome: nome,
      email: email,
      curso: curso,
      atleticaId: atleticaId,
    );
    // merge: true preserva campos existentes (stats, taxaConfiabilidade, streak)
    // caso o usuário chegue aqui por redirect falso durante carregamento do perfil
    await _db.collection('users').doc(uid).set(
          user.toFirestore(),
          SetOptions(merge: true),
        );
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
