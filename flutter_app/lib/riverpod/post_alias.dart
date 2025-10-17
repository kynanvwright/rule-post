// aliases.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'doc_providers.dart';

/// Pretty label for an enquiry id (e.g. "RE#120")
final enquiryAliasProvider = Provider.family<String?, String>((ref, id) {
  final n = ref.watch(
    enquiryDocProvider(id).select(
      (a) => (a.value?['enquiryNumber'] as num?)?.toInt(),
    ),
  );
  return n == null ? null : 'RE #$n';
});

/// Pretty label for a response (e.g. "Response 1.2") keyed by (enquiryId, responseId)
final responseAliasProvider = Provider.family<String?, ({String enquiryId, String responseId})>((ref, ids) {
  return ref.watch(
    responseDocProvider(ids).select((a) {
      final d = a.value;
      final round = (d?['roundNumber'] as num?)?.toInt();
      final resp = (d?['responseNumber'] as num?)?.toInt();
      if (round == null || resp == null) return null;
      return 'Response $round.$resp'; // customise format
    }),
  );
});
