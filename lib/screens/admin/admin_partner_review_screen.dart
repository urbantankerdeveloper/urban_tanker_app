import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/providers.dart';
import '../../core/design_system/design_system.dart';
import '../../models/account.dart';
import '../../services/friendly_error.dart';

const _reviewTabs = ['Review', 'Documents', 'History'];

class AdminPartnerReviewScreen extends ConsumerStatefulWidget {
  const AdminPartnerReviewScreen({
    required this.application,
    this.initialTab = 0,
    super.key,
  });

  final AccountRecord application;
  final int initialTab;

  @override
  ConsumerState<AdminPartnerReviewScreen> createState() =>
      _AdminPartnerReviewScreenState();
}

class _AdminPartnerReviewScreenState
    extends ConsumerState<AdminPartnerReviewScreen> {
  late final TextEditingController _reviewNote = TextEditingController(
    text: (widget.application.data['review_note'] ?? '').toString(),
  );
  late String _status = _validStatus(widget.application.status);
  late int _tab = widget.initialTab.clamp(0, _reviewTabs.length - 1).toInt();
  late Future<List<AccountRecord>> _documents;
  late Future<List<AccountRecord>> _history;
  bool _saving = false;

  String get _id => widget.application.id;

  @override
  void initState() {
    super.initState();
    _loadRelated();
  }

  @override
  void dispose() {
    _reviewNote.dispose();
    super.dispose();
  }

  static String _validStatus(String status) =>
      const {
        'submitted',
        'under_review',
        'additional_info_required',
        'approved',
        'rejected',
      }.contains(status)
      ? status
      : 'submitted';

  void _loadRelated() {
    final api = ref.read(appControllerProvider).api;
    _documents = api.partnerApplicationDocuments(_id);
    _history = api.partnerApplicationHistory(_id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppScaffold(
      title: 'Review partner application',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.lg,
              AppSpace.md,
              AppSpace.lg,
              0,
            ),
            child: SegmentedTabs(
              labels: _reviewTabs,
              selectedIndex: _tab,
              onChanged: (value) => setState(() => _tab = value),
            ),
          ),
          Expanded(
            child: switch (_tab) {
              0 => _reviewContent(theme),
              1 => _documentsContent(),
              _ => _historyContent(),
            },
          ),
        ],
      ),
    );
  }

  Widget _reviewContent(ThemeData theme) {
    final data = widget.application.data;
    final details = <(String, String)>[
      ('Applicant', widget.application.title),
      ('Business name', _value(data['business_name'])),
      ('Email', _value(data['email'])),
      ('Phone', _value(data['phone_e164'] ?? data['phone'])),
      ('Service area', _value(data['service_zone'])),
      ('Submitted', _date(data['created_at'])),
    ];
    return ListView(
      padding: AppPageInsets.withSafeAreaBottom(
        context,
        AppPageInsets.standard,
      ),
      children: [
        GradientCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.fact_check_outlined,
                size: 40,
                color: Colors.white,
              ),
              const SizedBox(height: AppSpace.md),
              Text(
                widget.application.title,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: AppSpace.sm),
              StatusChip(
                label: StatusChip.statusLabel(widget.application.status),
                tone: context.colors.warning,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.xl),
        Text('Application details', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpace.md),
        SurfaceCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var index = 0; index < details.length; index++) ...[
                AppListRow(
                  title: details[index].$1,
                  subtitle: details[index].$2,
                ),
                if (index < details.length - 1) const Divider(height: 1),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpace.xl),
        Text('Decision', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpace.md),
        DropdownButtonFormField<String>(
          initialValue: _status,
          decoration: const InputDecoration(labelText: 'Application status'),
          items: const [
            DropdownMenuItem(value: 'submitted', child: Text('Submitted')),
            DropdownMenuItem(
              value: 'under_review',
              child: Text('Under review'),
            ),
            DropdownMenuItem(
              value: 'additional_info_required',
              child: Text('Request more documents'),
            ),
            DropdownMenuItem(value: 'approved', child: Text('Approved')),
            DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
          ],
          onChanged: _saving
              ? null
              : (value) {
                  if (value != null) setState(() => _status = value);
                },
        ),
        const SizedBox(height: AppSpace.md),
        AppTextField(
          controller: _reviewNote,
          label: _status == 'rejected' ? 'Rejection reason' : 'Review note',
          helper: _status == 'additional_info_required'
              ? 'Tell the applicant which documents or details are needed.'
              : null,
          minLines: 3,
          maxLines: 5,
          maxLength: 2000,
          enabled: !_saving,
        ),
        const SizedBox(height: AppSpace.lg),
        PrimaryButton(
          label: _saving ? 'Saving review...' : 'Save review',
          icon: Icons.save_outlined,
          loading: _saving,
          onPressed: _saving ? null : _saveReview,
        ),
      ],
    );
  }

  Widget _documentsContent() => FutureBuilder<List<AccountRecord>>(
    future: _documents,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const LoadingState(message: 'Loading submitted documents...');
      }
      if (snapshot.hasError) {
        return ErrorState(
          error: snapshot.error!,
          onRetry: () => setState(_loadRelated),
        );
      }
      final documents = snapshot.data ?? const <AccountRecord>[];
      if (documents.isEmpty) {
        return const NewUiEmptyState(
          icon: Icons.description_outlined,
          title: 'No documents submitted',
          message: 'Documents attached to this application will appear here.',
        );
      }
      return ListView(
        padding: AppPageInsets.withSafeAreaBottom(
          context,
          AppPageInsets.standard,
        ),
        children: [
          for (final document in documents)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.md),
              child: SurfaceCard(
                padding: EdgeInsets.zero,
                child: AppListRow(
                  leading: const Icon(Icons.description_outlined),
                  title: document.title,
                  subtitle: _value(
                    document.data['documentType'] ??
                        document.data['document_type'],
                  ),
                  trailing: IconButton(
                    tooltip: 'Open document',
                    icon: const Icon(Icons.open_in_new),
                    onPressed: () => _openDocument(document),
                  ),
                  onTap: () => _openDocument(document),
                ),
              ),
            ),
        ],
      );
    },
  );

  Widget _historyContent() => FutureBuilder<List<AccountRecord>>(
    future: _history,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const LoadingState(message: 'Loading approval history...');
      }
      if (snapshot.hasError) {
        return ErrorState(
          error: snapshot.error!,
          onRetry: () => setState(_loadRelated),
        );
      }
      final entries = snapshot.data ?? const <AccountRecord>[];
      if (entries.isEmpty) {
        return const NewUiEmptyState(
          icon: Icons.history_outlined,
          title: 'No review history yet',
          message: 'Review decisions and notes will be listed here.',
        );
      }
      return ListView(
        padding: AppPageInsets.withSafeAreaBottom(
          context,
          AppPageInsets.standard,
        ),
        children: [
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.md),
              child: SurfaceCard(
                child: Timeline(
                  steps: [
                    TimelineStep(
                      title: StatusChip.statusLabel(
                        (entry.data['new_status'] ?? '').toString(),
                      ),
                      subtitle: [
                        _date(entry.data['created_at']),
                        if ((entry.data['review_note'] ?? '')
                            .toString()
                            .trim()
                            .isNotEmpty)
                          entry.data['review_note'].toString(),
                      ].join('\n'),
                      state: TimelineState.done,
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );

  Future<void> _openDocument(AccountRecord document) async {
    try {
      final refreshedDocuments = await ref
          .read(appControllerProvider)
          .api
          .partnerApplicationDocuments(_id);
      AccountRecord? refreshed;
      for (final item in refreshedDocuments) {
        if (item.id == document.id) {
          refreshed = item;
          break;
        }
      }
      final rawUrl = refreshed?.data['downloadUrl']?.toString() ?? '';
      final uri = Uri.tryParse(rawUrl);
      if (uri == null || uri.scheme != 'https') {
        throw const FormatException(
          'The document link is unavailable or invalid.',
        );
      }
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        showAppSnack(
          context,
          'The document could not be opened.',
          variant: AppSnackVariant.error,
        );
      }
    } catch (error) {
      if (mounted) {
        showAppSnack(
          context,
          'The document could not be opened: ${friendlyError(error)}',
          variant: AppSnackVariant.error,
        );
      }
    }
  }

  Future<void> _saveReview() async {
    final note = _reviewNote.text.trim();
    if (note.isEmpty &&
        const {'rejected', 'additional_info_required'}.contains(_status)) {
      showAppSnack(
        context,
        _status == 'rejected'
            ? 'Add a reason before rejecting this application.'
            : 'Describe which documents or details are needed.',
        variant: AppSnackVariant.error,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(appControllerProvider)
          .api
          .reviewPartnerApplication(
            _id,
            status: _status,
            reviewNote: note.isEmpty ? null : note,
          );
      if (!mounted) return;
      showAppSnack(
        context,
        'Application review saved.',
        variant: AppSnackVariant.success,
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      showAppSnack(
        context,
        'Could not save the review: ${friendlyError(error)}',
        variant: AppSnackVariant.error,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _value(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? 'Not provided' : text;
  }

  String _date(Object? value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    return parsed == null ? 'Date unavailable' : parsed.toLocal().toString();
  }
}
