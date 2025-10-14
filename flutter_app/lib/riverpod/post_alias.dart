// aliases.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Pretty label for an enquiry id (e.g. "RE#120")
final enquiryAliasProvider =
    StateProvider.family<String?, String>((ref, enquiryId) => null);

/// Pretty label for a response (e.g. "R1.2") keyed by (enquiryId, responseId)
typedef ResponseKey = ({String enquiryId, String responseId});

final responseAliasProvider =
    StateProvider.family<String?, ResponseKey>((ref, key) => null);
