import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

// Conditional import: stub on native, real iframe implementation on web
import 'grafana_webview_stub.dart' if (dart.library.html) 'grafana_webview_web.dart';

class GrafanaWebViewScreen extends StatefulWidget {
  const GrafanaWebViewScreen({super.key});

  @override
  State<GrafanaWebViewScreen> createState() => _GrafanaWebViewScreenState();
}

class _GrafanaWebViewScreenState extends State<GrafanaWebViewScreen> {
  static String get _grafanaUrl {
    const url = String.fromEnvironment('GRAFANA_URL');
    if (url.isNotEmpty) return url;
    return 'http://localhost:3000/d/lanwash-api';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Grafana'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: kIsWeb
          ? GrafanaIframeView(url: _grafanaUrl)
          : InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(_grafanaUrl)),
            ),
    );
  }
}
