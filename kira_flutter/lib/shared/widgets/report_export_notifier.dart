/// Report Export Notifier
///
/// A simple global ValueNotifier that allows the ReportsScreen to expose
/// its export callback to the MainScaffold, so the export button
/// can live beside the AI chatbot button.
library;

import 'package:flutter/foundation.dart';

/// Global notifier holding the export callback.
/// - null = not on reports page (button hidden)
/// - non-null = on reports page (button shown, calls this on tap)
final reportExportNotifier = ValueNotifier<VoidCallback?>(null);

/// Whether an export is currently in progress
final reportExportingNotifier = ValueNotifier<bool>(false);
