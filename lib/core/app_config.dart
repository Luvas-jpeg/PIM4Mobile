import 'package:flutter/foundation.dart';

class AppConfig {
  static const apiUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://pim4-api-demo.onrender.com/',
  );
  static const siteUrl = String.fromEnvironment(
    'WEB_BASE_URL',
    defaultValue: 'https://pim4front.onrender.com/',
  );

  static Uri get api => validate(apiUrl);
  static Uri get site => validate(siteUrl);

  static Uri validate(String value, {bool release = kReleaseMode}) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !uri.hasAuthority ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.userInfo.isNotEmpty ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException('Informe a URL raiz válida do servidor.');
    }
    if (release &&
        (uri.scheme != 'https' ||
            ['localhost', '127.0.0.1', '10.0.2.2', '::1'].contains(uri.host))) {
      throw const FormatException(
        'Configure os endereços HTTPS de produção antes de gerar o aplicativo.',
      );
    }
    return uri.replace(path: '/');
  }
}
