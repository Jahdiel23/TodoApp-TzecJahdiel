import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService extends GetxService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> loginWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    await _saveUserData(
      user: credential.user!,
      nombre: credential.user?.displayName,
      foto: credential.user?.photoURL,
      updateCreationDate: false,
    );

    return credential;
  }

  Future<UserCredential> registerWithEmail({
    required String nombre,
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    await credential.user?.updateDisplayName(nombre.trim());
    await credential.user?.reload();
    final updatedUser = _auth.currentUser;

    await _saveUserData(
      user: updatedUser ?? credential.user!,
      nombre: nombre.trim(),
      foto: updatedUser?.photoURL,
      updateCreationDate: true,
    );

    return credential;
  }

  Future<UserCredential> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw Exception('Inicio de sesión con Google cancelado');
    }

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);

    await _saveUserData(
      user: userCredential.user!,
      nombre: userCredential.user?.displayName,
      foto: userCredential.user?.photoURL,
      updateCreationDate: userCredential.additionalUserInfo?.isNewUser ?? false,
    );

    return userCredential;
  }

  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
  }

  Future<void> _saveUserData({
    required User user,
    required String? nombre,
    required String? foto,
    required bool updateCreationDate,
  }) async {
    final docRef = _firestore.collection('users').doc(user.uid);

    final data = <String, dynamic>{
      'nombre': (nombre != null && nombre.trim().isNotEmpty)
          ? nombre.trim()
          : (user.displayName ?? ''),
      'email': user.email ?? '',
      'foto': foto ?? '',
      'ultimaVezInicioSesion': FieldValue.serverTimestamp(),
      'estadoActivo': true,
    };

    if (updateCreationDate) {
      data['fechaCreacion'] = FieldValue.serverTimestamp();
    }

    await docRef.set(data, SetOptions(merge: true));
  }
}