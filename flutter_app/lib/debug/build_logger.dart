// lib/debug/build_logger.dart
import 'package:flutter/widgets.dart';

import 'package:rule_post/debug/debug.dart';


/// For StatelessWidget _or_ any Widget class you mix this into.
mixin BuildLogger on Widget {
  /// Override if you want a custom tag.
  String get buildTag => runtimeType.toString();

  @protected
  void logBuild([String? tag]) {
    assert(() { d('🔍 ${(tag ?? buildTag)} build'); return true; }());
  }
}

/// For State classes. One mixin covers simple build logs, rebuild counts,
/// and optional lifecycle logging — all toggled by getters.
mixin StateLogger<T extends StatefulWidget> on State<T> {
  int _buildCount = 0;

  /// Override to disable counting/rebuild messages.
  bool get enableRebuildCounting => true;

  /// Override to enable didUpdateWidget / didChangeDependencies logs.
  bool get enableLifecycleLogs => false;

  /// Override for a custom tag.
  String get buildTag => widget.runtimeType.toString();

  @protected
  void logBuild([String? tag]) {
    assert(() {
      final name = tag ?? buildTag;
      if (!enableRebuildCounting) {
        d('🔍 $name build');
      } else {
        d(_buildCount == 0 ? '🆕 $name building ' : '🔁 $name rebuilding');
        _buildCount++;
      }
      return true;
    }());
  }

  @override
  void reassemble() {
    assert(() { _buildCount = 0; return true; }()); // keep sessions meaningful
    super.reassemble();
  }

  @override
  void didUpdateWidget(covariant T oldWidget) {
    assert(() {
      if (enableLifecycleLogs) d('♻️ didUpdateWidget ${widget.runtimeType}');
      return true;
    }());
    super.didUpdateWidget(oldWidget);
  }

  @override
  void didChangeDependencies() {
    assert(() {
      if (enableLifecycleLogs) d('🔗 didChangeDependencies ${widget.runtimeType}');
      return true;
    }());
    super.didChangeDependencies();
  }
}


// // Example use
// class EnquiriesList extends StatelessWidget with BuildLogger {
//   const EnquiriesList({super.key});

//   @override
//   Widget build(BuildContext context) {
//     logBuild();                            <-- call this at start of build
//     // ...build your UI...
//     return Container();
//   }
// }