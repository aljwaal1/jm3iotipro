import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

const developerEmail = 'fastunllocked2017@gmail.com';

// file_picker 12 returns the selected platform files directly.
// Keep the existing restore flow source-compatible without changing user data logic.
extension FilePickerResultCompatibility on List<PlatformFile> {
  List<PlatformFile> get files => this;
}

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
