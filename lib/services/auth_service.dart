import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:firebase_ui_auth/firebase_ui_auth.dart' show AuthProvider;
import 'package:firebase_ui_oauth_apple/firebase_ui_oauth_apple.dart';
import 'package:firebase_ui_oauth_google/firebase_ui_oauth_google.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../firebase_options.dart';

/// 認証状態を Riverpod で観測する Stream Provider。
/// User? が null なら未ログイン、それ以外はログイン中。
final authStateProvider = StreamProvider<User?>(
  (ref) => FirebaseAuth.instance.authStateChanges(),
);

/// Firebase UI Auth が要求する OAuth プロバイダ一覧。
/// MemolettApp 起動時に FirebaseUIAuth.configureProviders で登録する。
List<AuthProvider> authProviders() {
  // GoogleProvider の clientId は iOS で必要。Android は google-services.json
  // から自動取得されるので空でも動く。Web は Firebase Hosting 経由でのみ動く。
  final iosClientId =
      DefaultFirebaseOptions.currentPlatform.iosClientId ?? '';
  return [
    GoogleProvider(clientId: iosClientId),
    AppleProvider(),
  ];
}

class AuthService {
  static FirebaseAuth get auth => FirebaseAuth.instance;
  static User? get currentUser => auth.currentUser;
  static bool get isLoggedIn => auth.currentUser != null;

  /// Google + Apple 関係の状態をまとめてリセット。
  /// 完全ログアウト用（FirebaseAuth.signOut だけでは Google/Apple のキャッシュが残る）。
  static Future<void> signOut() async {
    await auth.signOut();
    // 各プロバイダ側のサインアウト（必要に応じて）
    // firebase_ui_oauth_google が内部で google_sign_in を扱うので、
    // FirebaseAuth.signOut() に任せれば十分なケースが多い。
  }
}
