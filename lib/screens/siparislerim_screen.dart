import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';

class SiparislerimScreen extends StatefulWidget {
  final String phone;
  const SiparislerimScreen({super.key, required this.phone});

  @override
  State<SiparislerimScreen> createState() => _SiparislerimScreenState();
}

class _SiparislerimScreenState extends State<SiparislerimScreen> {
  WebViewController? _controller;
  bool _yukleniyor = true;
  bool _tokenHazir = false;
  String? _token;

  static const _baseHost = 'reyhanli.hataysepetim.com.tr';
  static const _izinliPathler = [
    '/app/siparislerim.php',
    '/app/havaleeftbilgileri.php',
  ];

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final token = await ApiService.getToken();
    if (token == null || !mounted) return;
    _token = token;

    final url = 'https://$_baseHost/app/siparislerim.php'
        '?token=${Uri.encodeComponent(token)}';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'FlutterFilePicker',
        onMessageReceived: (msg) => _dosyaSec(msg.message),
      )
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _yukleniyor = true),
        onPageFinished: (url) {
          setState(() => _yukleniyor = false);
          // Dosya input'u tıklandığında Flutter'a haber ver
          _controller?.runJavaScript('''
            document.querySelectorAll('input[type="file"]').forEach(function(input) {
              input.addEventListener('click', function(e) {
                e.preventDefault();
                e.stopPropagation();
                FlutterFilePicker.postMessage(
                  input.closest('form') ? input.closest('form').action : ''
                );
              }, true);
            });
          ''');
        },
        onNavigationRequest: (request) {
          final uri = Uri.parse(request.url);
          if (uri.host != _baseHost) return NavigationDecision.prevent;
          final izinli = _izinliPathler.any((p) => uri.path == p);
          if (!izinli) return NavigationDecision.prevent;
          if (request.isMainFrame &&
              !uri.queryParameters.containsKey('token') &&
              _token != null) {
            final yeniUrl = uri.replace(queryParameters: {
              ...uri.queryParameters,
              'token': _token!,
            }).toString();
            _controller!.loadRequest(Uri.parse(yeniUrl));
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse(url));

    setState(() => _tokenHazir = true);
  }

  Future<void> _dosyaSec(String formAction) async {
    File? secilen;

    // Seçim modalı göster
    final tip = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('Dekont Seç', style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFFFF8C00)),
              title: const Text('Fotoğraf Çek'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFFFF8C00)),
              title: const Text('Galeriden Seç'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Color(0xFFFF8C00)),
              title: const Text('PDF Seç'),
              onTap: () => Navigator.pop(context, 'pdf'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (tip == null) return;

    if (tip == 'camera') {
      final picked = await ImagePicker().pickImage(source: ImageSource.camera);
      if (picked != null) secilen = File(picked.path);
    } else if (tip == 'gallery') {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked != null) secilen = File(picked.path);
    } else if (tip == 'pdf') {
      final result = await FilePicker.platform.pickFiles(
          type: FileType.custom, allowedExtensions: ['pdf']);
      if (result != null) secilen = File(result.files.single.path!);
    }

    if (secilen == null) return;

    // Mevcut URL'den order_id ve token al
    final currentUrl = await _controller?.currentUrl() ?? '';
    final uri = Uri.parse(currentUrl);
    final orderId = uri.queryParameters['id'] ?? '';
    final token = uri.queryParameters['token'] ?? _token ?? '';

    if (orderId.isEmpty) return;

    setState(() => _yukleniyor = true);

    try {
      final result = await ApiService.dekontYukle(
        orderId: orderId,
        dosya: secilen!,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        // Başarılı — uploaded=1 ile sayfayı yenile
        final yeniUrl =
            'https://$_baseHost/app/havaleeftbilgileri.php'
            '?id=$orderId&uploaded=1&token=${Uri.encodeComponent(token)}';
        _controller?.loadRequest(Uri.parse(yeniUrl));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Hata oluştu'),
              backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bağlantı hatası'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Siparişlerim')),
      body: !_tokenHazir
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF8C00)))
          : Stack(
              children: [
                WebViewWidget(controller: _controller!),
                if (_yukleniyor)
                  const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFFFF8C00))),
              ],
            ),
    );
  }
}
