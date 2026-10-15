/// Who is using the app right now. Local data (history, vocabulary, sync
/// queue) is namespaced by [userKey] so a guest and each account on the same
/// device never see each other's data.
class AppSession {
  AppSession._();

  static bool isGuest = false;
  static String userKey = 'anon';

  static void setUser(String id) {
    isGuest = false;
    userKey = id;
  }

  static void setGuest() {
    isGuest = true;
    userKey = guestKey;
  }

  static void clear() {
    isGuest = false;
    userKey = 'anon';
  }

  static const guestKey = 'guest';

  /// `scope('history')` -> `history_<userKey>`.
  static String scope(String base) => '${base}_$userKey';
}
