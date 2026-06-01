import 'package:flutter/material.dart';
import 'dart:html';
import 'dart:ui_web' as ui_web;

class GrafanaIframeView extends StatelessWidget {
  final String url;

  const GrafanaIframeView({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    const viewType = 'grafana-iframe';
    ui_web.platformViewRegistry.registerViewFactory(
      viewType,
      (int viewId) => IFrameElement()
        ..src = url
        ..setAttribute('sandbox', 'allow-scripts allow-same-origin')
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%',
    );

    return const HtmlElementView(viewType: viewType);
  }
}
