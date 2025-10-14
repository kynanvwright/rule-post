// enquiry_filter_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class EnquiryFilter {
  final String status; // e.g. 'all', 'open', 'closed'
  final String query;  // free-text search
  const EnquiryFilter({this.status = 'all', this.query = ''});

  EnquiryFilter copyWith({String? status, String? query}) =>
      EnquiryFilter(status: status ?? this.status, query: query ?? this.query);
}

class EnquiryFilterCtrl extends StateNotifier<EnquiryFilter> {
  EnquiryFilterCtrl() : super(const EnquiryFilter());

  void setStatus(String s) => state = state.copyWith(status: s);
  void setQuery(String q) => state = state.copyWith(query: q);
  void clearQuery() => state = state.copyWith(query: '');
  void reset({String defaultStatus = 'all'}) =>
      state = EnquiryFilter(status: defaultStatus, query: '');
}

final enquiryFilterProvider =
    StateNotifierProvider<EnquiryFilterCtrl, EnquiryFilter>(
  (ref) => EnquiryFilterCtrl(),
);
