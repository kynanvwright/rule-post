import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

Map<String, String> currentQuery(BuildContext context, {GoRouterState? state}) {
  // Prefer the state if you already have it (e.g., passed into your widget)
  final uri = state?.uri
      ?? Uri.parse(GoRouter.of(context).routeInformationProvider.value.location);
  return uri.queryParameters;
}

Map<String, String> _sanitiseQuery(Map<String, String> qp) {
  final m = Map<String, String>.from(qp);
  m.removeWhere((k, v) => v.trim().isEmpty);
  return m;
}

void goWithQuery(BuildContext context, String path, {GoRouterState? state}) {
  final qp = _sanitiseQuery(currentQuery(context, state: state));
  final uri = Uri(path: path, queryParameters: qp.isEmpty ? null : qp);
  context.push(uri.toString());
}