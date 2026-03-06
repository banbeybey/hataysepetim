import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class GizlilikPolitikasiScreen extends StatefulWidget {
  const GizlilikPolitikasiScreen({super.key});

  @override
  State<GizlilikPolitikasiScreen> createState() =>
      _GizlilikPolitikasiScreenState();
}

class _GizlilikPolitikasiScreenState
    extends State<GizlilikPolitikasiScreen> {
  late final WebViewController _controller;
  bool _yukleniyor = true;

  static const String _url =
      'https://hataysepetim.com.tr/privacy-policy.html';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _yukleniyor = true),
          onPageFinished: (_) => setState(() => _yukleniyor = false),
          onWebResourceError: (_) => setState(() => _yukleniyor = false),
        ),
      )
      ..loadRequest(Uri.parse(_url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gizlilik Politikası'),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_yukleniyor)
            const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFF8C00),
              ),
            ),
        ],
      ),
    );
  }
}
