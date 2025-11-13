// flutter_app/lib/riverpod/enquiry_filter_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rule_post/core/models/enquiry_status_filter.dart';


// State provider for the enquiry list filter
final enquiryFilterProvider =
    StateNotifierProvider<EnquiryFilterCtrl, EnquiryFilter>(
  (ref) => EnquiryFilterCtrl(),
);


// Helper classes for the enquiry filter provider
@immutable
class EnquiryFilter {
  final EnquiryStatusFilter status; // e.g. 'all', 'open', 'closed'
  final String query;  // free-text search
  const EnquiryFilter({this.status = const EnquiryStatusFilter.all(), this.query = ''});

  EnquiryFilter copyWith({EnquiryStatusFilter? status, String? query}) =>
      EnquiryFilter(status: status ?? this.status, query: query ?? this.query);
}

class EnquiryFilterCtrl extends StateNotifier<EnquiryFilter> {
  EnquiryFilterCtrl() : super(const EnquiryFilter());

  void setStatus(EnquiryStatusFilter s) => state = state.copyWith(status: s);
  void setQuery(String q) => state = state.copyWith(query: q);
  void clearQuery() => state = state.copyWith(query: '');
  void reset({EnquiryStatusFilter defaultStatus = const EnquiryStatusFilter.all()}) =>
      state = EnquiryFilter(status: defaultStatus, query: '');
}
