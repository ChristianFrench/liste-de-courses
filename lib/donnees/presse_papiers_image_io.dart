import 'dart:io';
import 'dart:typed_data';

/// L'image du presse-papiers de Windows, en PNG : une image copiée (capture, image d'une page web…) ou un fichier
/// image copié dans l'explorateur. Null s'il n'y en a pas (ou hors de Windows).
Future<Uint8List?> imageDuPressePapiers() async {
  if (!Platform.isWindows) return null;
  final dossier = await Directory.systemTemp.createTemp('emplettes-image');
  final sortie = '${dossier.path}\\image.png';
  final script = '''
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
\$i = [System.Windows.Forms.Clipboard]::GetImage()
if (\$i -ne \$null) { \$i.Save('$sortie', [System.Drawing.Imaging.ImageFormat]::Png); exit 0 }
\$f = [System.Windows.Forms.Clipboard]::GetFileDropList()
if (\$f -ne \$null -and \$f.Count -gt 0) { Copy-Item -LiteralPath \$f[0] -Destination '$sortie'; exit 0 }
exit 1
''';
  try {
    final r = await Process.run('powershell', ['-NoProfile', '-STA', '-NonInteractive', '-Command', script]);
    final f = File(sortie);
    if (r.exitCode != 0 || !await f.exists()) return null;
    return await f.readAsBytes();
  } catch (_) {
    return null;
  } finally {
    try {
      await dossier.delete(recursive: true);
    } catch (_) {}
  }
}
