/// Builds the text encoded in the Hub's "scan to join" QR codes.
library;

class JoinQrPayload {
  const JoinQrPayload._();

  /// Standard Wi-Fi join code understood by Android and iOS cameras:
  /// `WIFI:T:WPA;S:<ssid>;P:<password>;;`. An empty password produces an
  /// open-network code (`T:nopass`).
  static String wifi({required String ssid, String? password}) {
    final String safeSsid = _escape(ssid);
    final String pass = password ?? '';
    if (pass.isEmpty) {
      return 'WIFI:T:nopass;S:$safeSsid;;';
    }
    return 'WIFI:T:WPA;S:$safeSsid;P:${_escape(pass)};;';
  }

  /// Hub address opened by the second QR (`http://192.168.43.1:8080`).
  static String hubUrl({required String ip, required int port}) {
    return 'http://$ip:$port';
  }

  /// Escapes the characters that are special in the Wi-Fi QR format.
  static String _escape(String value) {
    final StringBuffer out = StringBuffer();
    for (final int rune in value.runes) {
      final String ch = String.fromCharCode(rune);
      if (ch == r'\' || ch == ';' || ch == ',' || ch == ':' || ch == '"') {
        out.write(r'\');
      }
      out.write(ch);
    }
    return out.toString();
  }
}
