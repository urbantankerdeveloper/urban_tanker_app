import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/design_system/design_system.dart';
import '../../models/workspace_navigation.dart';
import 'operations/finance_section.dart';
import 'operations/orders_section.dart';
import 'operations/people_section.dart';
import 'operations/setup_section.dart';

const _sections = ['Orders', 'People', 'Finance', 'Setup'];

/// Admin operations: four sections behind one switcher. The Menu tab's
/// drawer-style items open the matching section through [focus].
class AdminOperationsScreen extends StatefulWidget {
  const AdminOperationsScreen({super.key, this.focus});

  /// Posting a new [OperationsFocus] switches to its section.
  final ValueListenable<OperationsFocus?>? focus;

  @override
  State<AdminOperationsScreen> createState() => _AdminOperationsScreenState();
}

class _AdminOperationsScreenState extends State<AdminOperationsScreen> {
  int _section = 0;

  @override
  void initState() {
    super.initState();
    widget.focus?.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(covariant AdminOperationsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focus != widget.focus) {
      oldWidget.focus?.removeListener(_onFocus);
      widget.focus?.addListener(_onFocus);
    }
  }

  @override
  void dispose() {
    widget.focus?.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() {
    final request = widget.focus?.value;
    if (request == null) return;
    setState(() => _section = _sectionIndex(request.section));
  }

  static int _sectionIndex(OperationsSection section) => switch (section) {
        OperationsSection.orders => 0,
        OperationsSection.people => 1,
        OperationsSection.finance => 2,
        OperationsSection.setup => 3,
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.gutter,
            AppSpace.md,
            AppSpace.gutter,
            0,
          ),
          child: SegmentedTabs(
            labels: _sections,
            selectedIndex: _section,
            onChanged: (index) => setState(() => _section = index),
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _section,
            children: const [
              AdminOrdersSection(),
              AdminPeopleSection(),
              AdminFinanceSection(),
              AdminSetupSection(),
            ],
          ),
        ),
      ],
    );
  }
}
