import 'account.dart';

class AdminEnquiryPage {
  const AdminEnquiryPage({
    required this.rows,
    required this.page,
    required this.pageSize,
    required this.total,
  });

  final List<AccountRecord> rows;
  final int page;
  final int pageSize;
  final int total;

  bool get hasNextPage => page * pageSize < total;

  factory AdminEnquiryPage.fromJson(Map<String, dynamic> json) {
    final rows = json['rows'];
    if (rows is! List) {
      throw const FormatException('The admin enquiries response was invalid.');
    }

    int readInt(String key, {required int minimum}) {
      final value = json[key];
      if (value is! num ||
          !value.isFinite ||
          value % 1 != 0 ||
          value < minimum) {
        throw const FormatException(
          'The admin enquiries response was invalid.',
        );
      }
      return value.toInt();
    }

    return AdminEnquiryPage(
      rows: rows
          .whereType<Map<String, dynamic>>()
          .map(AccountRecord.new)
          .toList(growable: false),
      page: readInt('page', minimum: 1),
      pageSize: readInt('pageSize', minimum: 1),
      total: readInt('total', minimum: 0),
    );
  }
}
