import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';

/// Import student data from CSV/Excel files
class ImportService {
  static ImportService? _instance;
  static ImportService get instance => _instance ??= ImportService._();
  ImportService._();

  /// Pick and parse a CSV or Excel file
  Future<ImportResult> pickAndImport() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx', 'xls'],
    );

    if (result == null || result.files.isEmpty) {
      return ImportResult.error('No file selected');
    }

    final filePath = result.files.single.path;
    if (filePath == null) {
      return ImportResult.error('Could not read file path');
    }

    final file = File(filePath);
    final ext = result.files.single.extension?.toLowerCase();

    if (ext == 'csv') {
      return _parseCsv(file);
    } else if (ext == 'xlsx' || ext == 'xls') {
      return _parseExcel(file);
    }

    return ImportResult.error('Unsupported file format. Use CSV or Excel (.xlsx)');
  }

  Future<ImportResult> _parseCsv(File file) async {
    try {
      final content = await file.readAsString();
      final rows = const CsvToListConverter().convert(content);
      return _processRows(rows);
    } catch (e) {
      return ImportResult.error('Failed to parse CSV. Please ensure the file is a valid CSV file.');
    }
  }

  Future<ImportResult> _parseExcel(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final excel = Excel.decodeBytes(bytes);
      if (excel.tables.isEmpty) return ImportResult.error('Excel file is empty or corrupted');
      final sheet = excel.tables[excel.tables.keys.first];
      if (sheet == null) return ImportResult.error('Empty Excel file');

      final rows = <List<dynamic>>[];
      for (final row in sheet.rows) {
        rows.add(row.map((cell) => cell?.value ?? '').toList());
      }
      return _processRows(rows);
    } catch (e) {
      return ImportResult.error('Failed to parse Excel. Please ensure the file is a valid Excel file.');
    }
  }

  ImportResult _processRows(List<List<dynamic>> rows) {
    if (rows.length < 2) return ImportResult.error('File must have a header row and at least one data row');

    final header = rows.first.map((h) => h.toString().toLowerCase().trim()).toList();
    final nameIdx = header.indexWhere((h) => h.contains('name'));
    final phoneIdx = header.indexWhere((h) => h.contains('phone'));
    final parentPhoneIdx = header.indexWhere((h) => h.contains('parent') && h.contains('phone'));
    final seatIdx = header.indexWhere((h) => h.contains('seat'));
    final feePlanIdx = header.indexWhere((h) => h.contains('plan') || h.contains('fee'));
    final feeAmountIdx = header.indexWhere((h) => h.contains('amount'));

    if (nameIdx == -1 || phoneIdx == -1) {
      return ImportResult.error('File must have "Name" and "Phone" columns');
    }

    final students = <Map<String, dynamic>>[];
    int skipped = 0;

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length <= nameIdx || row[nameIdx].toString().trim().isEmpty) {
        skipped++;
        continue;
      }

      students.add({
        'name': row[nameIdx].toString().trim(),
        'phone': phoneIdx < row.length ? row[phoneIdx].toString().trim() : '',
        'parentPhone': parentPhoneIdx >= 0 && parentPhoneIdx < row.length ? row[parentPhoneIdx].toString().trim() : null,
        'seatNumber': seatIdx >= 0 && seatIdx < row.length ? row[seatIdx].toString().trim() : null,
        'feePlan': feePlanIdx >= 0 && feePlanIdx < row.length ? row[feePlanIdx].toString().trim() : 'Monthly',
        'feeAmount': feeAmountIdx >= 0 && feeAmountIdx < row.length ? double.tryParse(row[feeAmountIdx].toString()) ?? 0 : 0,
        'isActive': true,
      });
    }

    if (students.isEmpty) return ImportResult.error('No valid student records found');

    return ImportResult.success(
      students: students,
      totalRows: rows.length - 1,
      imported: students.length,
      skipped: skipped,
    );
  }
}

class ImportResult {
  final bool success;
  final String? error;
  final List<Map<String, dynamic>>? students;
  final int? totalRows;
  final int? imported;
  final int? skipped;

  ImportResult.success({
    required this.students,
    required this.totalRows,
    required this.imported,
    required this.skipped,
  }) : success = true, error = null;

  ImportResult.error(this.error)
      : success = false,
        students = null,
        totalRows = null,
        imported = null,
        skipped = null;
}
