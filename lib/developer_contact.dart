import 'package:url_launcher/url_launcher.dart';

const developerEmail = 'fastunllocked2017@gmail.com';

Future<bool> contactDeveloper() async {
  final uri = Uri(
    scheme: 'mailto',
    path: developerEmail,
    queryParameters: const {
      'subject': 'ملاحظة حول تطبيق جمعيتي Pro',
      'body': 'مرحبًا،\n\nلدي ملاحظة حول تطبيق جمعيتي Pro:\n\n',
    },
  );
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
