/// A lightweight view of the signed-in account for the UI layer.
///
/// Built from Firebase's `User` inside [GameState] so screens don't need to
/// import `firebase_auth` directly. `uid` is the Firebase user id; `email` is
/// the account email (empty string if the provider didn't supply one).
class AppUser {
  final String uid;
  final String email;

  const AppUser({
    required this.uid,
    required this.email,
  });
}
