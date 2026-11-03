import 'package:flutter/material.dart';

import '../../../core/design_system/design_system.dart';
import '../../../models/account.dart';
import '../../../services/friendly_error.dart';

/// A record from the admin lists. Tapping it opens the details sheet.
class AdminRecordRow extends StatelessWidget {
  const AdminRecordRow({
    required this.record,
    super.key,
    this.trailing,
    this.onTap,
  });

  final AccountRecord record;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => SurfaceCard(
        padding: EdgeInsets.zero,
        child: AppListRow(
          title: record.title,
          subtitle: record.detail,
          trailing: trailing ??
              (record.status.isEmpty
                  ? null
                  : Text(
                      StatusChip.statusLabel(record.status),
                      style: Theme.of(context).textTheme.labelLarge,
                    )),
          onTap: onTap ?? () => showAdminRecordSheet(context, record),
        ),
      );
}

/// Details of one record, as "key: value" lines, in a bottom sheet.
Future<void> showAdminRecordSheet(
  BuildContext context,
  AccountRecord record,
) =>
    showDetailSheet(
      context,
      title: record.title,
      message: record.data.entries
          .map((entry) => '${entry.key}: ${entry.value}')
          .join('\n'),
    );

/// A titled block of text in a bottom sheet, with optional actions below.
Future<T?> showDetailSheet<T>(
  BuildContext context, {
  required String title,
  required String message,
  List<Widget> actions = const [],
}) =>
    showAppBottomSheet<T>(
      context,
      builder: (sheetContext) => SingleChildScrollView(
        padding:
            const EdgeInsets.fromLTRB(AppSpace.xl, 0, AppSpace.xl, AppSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(sheetContext).textTheme.titleLarge),
            const SizedBox(height: AppSpace.md),
            Text(message, style: Theme.of(sheetContext).textTheme.bodyLarge),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: AppSpace.xl),
              ...actions,
            ],
          ],
        ),
      ),
    );

/// Search box for the lists in the admin sections.
class AdminSearchField extends StatelessWidget {
  const AdminSearchField({
    required this.controller,
    required this.onChanged,
    required this.label,
    super.key,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) => AppTextField(
        controller: controller,
        label: label,
        prefix: const Icon(Icons.search),
        suffix: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
                icon: const Icon(Icons.clear),
              ),
        onChanged: onChanged,
      );
}

/// Previous and next page controls with the page number between them.
class AdminPager extends StatelessWidget {
  const AdminPager({
    required this.page,
    required this.hasNext,
    required this.onPage,
    super.key,
  });

  final int page;
  final bool hasNext;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            tooltip: 'Previous page',
            onPressed: page > 1 ? () => onPage(page - 1) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Text('Page $page', style: Theme.of(context).textTheme.labelLarge),
          IconButton(
            tooltip: 'Next page',
            onPressed: hasNext ? () => onPage(page + 1) : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      );
}

/// Fields whose labels mention a password are hidden and never suggested.
bool isPasswordLabel(String label) => label.toLowerCase().contains('password');

/// Create-record form in a bottom sheet. Every field must have text. On save
/// it shows "<title> completed successfully."
Future<void> adminForm(
  BuildContext context, {
  required String title,
  required List<(String, TextEditingController)> fields,
  required Future<void> Function() submit,
}) async {
  final saved = await showAppBottomSheet<bool>(
    context,
    builder: (_) => _AdminFormSheet(
      title: title,
      fields: fields,
      submit: submit,
    ),
  );
  if (saved == true && context.mounted) {
    showAppSnack(
      context,
      '$title completed successfully.',
      variant: AppSnackVariant.success,
    );
  }
}

class _AdminFormSheet extends StatefulWidget {
  const _AdminFormSheet({
    required this.title,
    required this.fields,
    required this.submit,
  });

  final String title;
  final List<(String, TextEditingController)> fields;
  final Future<void> Function() submit;

  @override
  State<_AdminFormSheet> createState() => _AdminFormSheetState();
}

class _AdminFormSheetState extends State<_AdminFormSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.submit();
      if (mounted) Navigator.pop(context, true);
    } catch (value) {
      if (mounted) {
        setState(() {
          _error = friendlyError(value);
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpace.xl, 0, AppSpace.xl, AppSpace.xl),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpace.lg),
                for (final field in widget.fields) ...[
                  AppTextField(
                    controller: field.$2,
                    label: field.$1,
                    obscureText: isPasswordLabel(field.$1),
                    // Password fields are never suggested or autocorrected.
                    enableSuggestions: !isPasswordLabel(field.$1),
                    autocorrect: !isPasswordLabel(field.$1),
                    validator: (value) => value?.trim().isNotEmpty == true
                        ? null
                        : 'Enter ${field.$1.toLowerCase()}.',
                  ),
                  const SizedBox(height: AppSpace.md),
                ],
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.md),
                    child: Text(
                      _error!,
                      style: TextStyle(color: context.colors.danger.fg),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: SecondaryButton(
                        label: 'Cancel',
                        onPressed: _saving
                            ? null
                            : () => Navigator.pop(context, false),
                      ),
                    ),
                    const SizedBox(width: AppSpace.md),
                    Expanded(
                      child: PrimaryButton(
                        label: 'Save',
                        loading: _saving,
                        onPressed: _saving ? null : _save,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}
