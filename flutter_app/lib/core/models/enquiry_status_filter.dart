// flutter_app/lib/core/models/enquiry_status_filter.dart
import 'package:flutter/material.dart';

// 1. Define the allowed filters
sealed class EnquiryStatusFilter {
  const EnquiryStatusFilter();

  const factory EnquiryStatusFilter.all() = _All;
  const factory EnquiryStatusFilter.open() = _Open;
  const factory EnquiryStatusFilter.closedAny() = _ClosedAny;

  // Closed sub-states:
  const factory EnquiryStatusFilter.closedAmendment() = _ClosedAmendment;
  const factory EnquiryStatusFilter.closedInterpretation() = _ClosedInterpretation;
  const factory EnquiryStatusFilter.closedNoResult() = _ClosedNoResult;
}

// 2. Private impl types for each variant
class _All extends EnquiryStatusFilter { const _All(); }
class _Open extends EnquiryStatusFilter { const _Open(); }
class _ClosedAny extends EnquiryStatusFilter { const _ClosedAny(); }

class _ClosedAmendment extends EnquiryStatusFilter { const _ClosedAmendment(); }
class _ClosedInterpretation extends EnquiryStatusFilter { const _ClosedInterpretation(); }
class _ClosedNoResult extends EnquiryStatusFilter { const _ClosedNoResult(); }

extension EnquiryStatusFilterInfo on EnquiryStatusFilter {
  String get code => switch (this) {
    _All()                   => 'all',
    _Open()                  => 'open',
    _ClosedAny()             => 'closed',
    _ClosedAmendment()       => 'closed.amendment',
    _ClosedInterpretation()  => 'closed.interpretation',
    _ClosedNoResult()        => 'closed.noResult',
  };

  String get label => switch (this) {
    _All()                   => 'All',
    _Open()                  => 'Open',
    _ClosedAny()             => 'Closed',
    _ClosedAmendment()       => 'Amendment',
    _ClosedInterpretation()  => 'Interpretation',
    _ClosedNoResult()        => 'No Result',
  };

  IconData get icon => switch (this) {
    _All()                   => Icons.filter_alt,
    _Open()                  => Icons.lock_open,
    _ClosedAny()             => Icons.lock,
    _ClosedAmendment()       => Icons.edit_document,
    _ClosedInterpretation()  => Icons.menu_book,
    _ClosedNoResult()        => Icons.do_not_disturb_alt,
  };

  bool get isClosedSubset => switch (this) {
    _ClosedAmendment() ||
    _ClosedInterpretation() ||
    _ClosedNoResult()    => true,
    _ => false,
  };
}
