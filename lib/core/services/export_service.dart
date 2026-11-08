import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

/// Export data to PDF, Excel, CSV and share
class ExportService {
  static ExportService? _instance;
  static ExportService get instance => _instance ??= ExportService._();
  ExportService._();

  Future<File> exportStudentsToPdf({
    required List<Map<String, dynamic>> students,
    required String libraryName,
    required Directory outputDir,
  }) async {
    final pdf = pw.Document();
    final now = DateFormat('dd MMM yyyy').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(libraryName, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.Text('Student Report - $now', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
            pw.SizedBox(height: 8),
          ],
        ),
        footer: (context) => pw.Text('Page ${context.pageNumber}/${context.pagesCount}', style: const pw.TextStyle(fontSize: 10)),
        build: (context) => [
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellAlignment: pw.Alignment.centerLeft,
            headers: ['#', 'Name', 'Phone', 'Seat', 'Fee Plan', 'Status'],
            data: students.asMap().entries.map((entry) {
              final i = entry.key;
              final s = entry.value;
              return [
                '${i + 1}',
                s['name'] ?? '',
                s['phone'] ?? '',
                s['seat'] ?? '-',
                s['feePlan'] ?? '-',
                s['isActive'] == true ? 'Active' : 'Inactive',
              ];
            }).toList(),
          ),
        ],
      ),
    );

    final file = File('${outputDir.path}/students_report.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  Future<File> exportStudentsToCsv({
    required List<Map<String, dynamic>> students,
    required Directory outputDir,
  }) async {
    final rows = <List<dynamic>>[
      ['Name', 'Phone', 'Parent Phone', 'Seat', 'Fee Plan', 'Fee Amount', 'Status', 'Joining Date'],
    ];
    for (final s in students) {
      rows.add([
        s['name'] ?? '',
        s['phone'] ?? '',
        s['parentPhone'] ?? '',
        s['seat'] ?? '',
        s['feePlan'] ?? '',
        s['feeAmount'] ?? 0,
        s['isActive'] == true ? 'Active' : 'Inactive',
        s['joiningDate'] ?? '',
      ]);
    }

    final csv = const ListToCsvConverter().convert(rows);
    final file = File('${outputDir.path}/students_report.csv');
    await file.writeAsString(csv);
    return file;
  }

  Future<File> exportStudentsToExcel({
    required List<Map<String, dynamic>> students,
    required String libraryName,
    required Directory outputDir,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel['Students'];

    sheet.appendRow([
      TextCellValue('Name'),
      TextCellValue('Phone'),
      TextCellValue('Parent Phone'),
      TextCellValue('Seat'),
      TextCellValue('Fee Plan'),
      TextCellValue('Fee Amount'),
      TextCellValue('Status'),
      TextCellValue('Joining Date'),
    ]);

    for (final s in students) {
      sheet.appendRow([
        TextCellValue(s['name'] ?? ''),
        TextCellValue(s['phone'] ?? ''),
        TextCellValue(s['parentPhone'] ?? ''),
        TextCellValue(s['seat'] ?? ''),
        TextCellValue(s['feePlan'] ?? ''),
        TextCellValue('${s['feeAmount'] ?? 0}'),
        TextCellValue(s['isActive'] == true ? 'Active' : 'Inactive'),
        TextCellValue(s['joiningDate'] ?? ''),
      ]);
    }

    final file = File('${outputDir.path}/students_report.xlsx');
    final bytes = excel.encode();
    if (bytes != null) await file.writeAsBytes(bytes);
    return file;
  }

  Future<Uint8List> getBookReportBytes({
    required List<Map<String, dynamic>> books,
    required String libraryName,
  }) async {
    final pdf = pw.Document();
    final now = DateFormat('dd MMM yyyy').format(DateTime.now());
    final totalBooks = books.length;
    final issuedCount = books.where((b) => b['status'] == 'issued').length;
    final availableCount = books.where((b) => b['status'] == 'available').length;
    final totalCopies = books.fold<int>(0, (s, b) => s + (b['totalCopies'] as num? ?? 1).toInt());
    final totalAvailable = books.fold<int>(0, (s, b) => s + (b['availableCopies'] as num? ?? 1).toInt());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('$libraryName - Book Report', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Text('Generated: $now', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
            pw.SizedBox(height: 8),
            pw.Row(
              children: [
                _pdfStatBox('Total Titles', '$totalBooks'),
                pw.SizedBox(width: 16),
                _pdfStatBox('Issued', '$issuedCount'),
                pw.SizedBox(width: 16),
                _pdfStatBox('Available', '$availableCount'),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Row(
              children: [
                _pdfStatBox('Total Copies', '$totalCopies'),
                pw.SizedBox(width: 16),
                _pdfStatBox('Copies Available', '$totalAvailable'),
              ],
            ),
            pw.SizedBox(height: 12),
          ],
        ),
        footer: (context) => pw.Text('Page ${context.pageNumber}/${context.pagesCount}', style: const pw.TextStyle(fontSize: 10)),
        build: (context) => [
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellAlignment: pw.Alignment.centerLeft,
            headers: ['#', 'Title', 'Author', 'ISBN', 'Category', 'Copies', 'Status'],
            data: books.asMap().entries.map((entry) {
              final i = entry.key;
              final b = entry.value;
              return [
                '${i + 1}',
                b['title'] ?? '',
                b['author'] ?? '-',
                b['isbn'] ?? '-',
                b['category'] ?? '-',
                '${b['availableCopies'] ?? 1}/${b['totalCopies'] ?? 1}',
                (b['status'] ?? '').toString().toUpperCase(),
              ];
            }).toList(),
          ),
        ],
      ),
    );

    return await pdf.save();
  }

  Future<Uint8List> getFeeReportBytes({
    required List<Map<String, dynamic>> fees,
    required String libraryName,
    required String month,
    String currencySymbol = '\$',
  }) async {
    final pdf = pw.Document();
    final totalCollected = fees.where((f) => f['status'] == 'paid').fold<double>(0, (s, f) => s + (f['amount'] ?? 0));
    final totalPending = fees.where((f) => f['status'] != 'paid').fold<double>(0, (s, f) => s + (f['amount'] ?? 0));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('$libraryName - Fee Report', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Text('Month: $month', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
            pw.SizedBox(height: 8),
            pw.Row(
              children: [
                _pdfStatBox('Collected', '$currencySymbol${totalCollected.toStringAsFixed(0)}'),
                pw.SizedBox(width: 16),
                _pdfStatBox('Pending', '$currencySymbol${totalPending.toStringAsFixed(0)}'),
              ],
            ),
            pw.SizedBox(height: 12),
          ],
        ),
        build: (context) => [
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            headers: ['Student', 'Amount', 'Status', 'Due Date', 'Payment Method'],
            data: fees.map((f) => [
              f['studentName'] ?? '',
              '$currencySymbol${f['amount'] ?? 0}',
              (f['status'] ?? '').toString().toUpperCase(),
              f['dueDate'] ?? '',
              f['paymentMethod'] ?? '-',
            ]).toList(),
          ),
        ],
      ),
    );

    return await pdf.save();
  }

  Future<File> exportFeeReport({
    required List<Map<String, dynamic>> fees,
    required String libraryName,
    required String month,
    required Directory outputDir,
    String currencySymbol = '\$',
  }) async {
    final bytes = await getFeeReportBytes(fees: fees, libraryName: libraryName, month: month, currencySymbol: currencySymbol);
    final file = File('${outputDir.path}/fee_report.pdf');
    await file.writeAsBytes(bytes);
    return file;
  }

  pw.Widget _pdfStatBox(String label, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
          pw.SizedBox(height: 4),
          pw.Text(value, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  Future<Uint8List> getStudentReportBytes({
    required Map<String, dynamic> student,
    required List<Map<String, dynamic>> books,
    required List<Map<String, dynamic>> fees,
    required String libraryName,
    String currencySymbol = '\$',
  }) async {
    final pdf = pw.Document();
    final now = DateFormat('dd MMM yyyy').format(DateTime.now());
    final totalDue = fees.where((f) => f['status'] != 'paid').fold<double>(0, (s, f) => s + (f['amount'] as num? ?? 0).toDouble());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(libraryName, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.Text('Student Report - $now', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
            pw.SizedBox(height: 16),
          ],
        ),
        footer: (context) => pw.Text('Page ${context.pageNumber}/${context.pagesCount}', style: const pw.TextStyle(fontSize: 10)),
        build: (context) => [
          // Student Details
          pw.Text('Student Details', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          _pdfInfoRow('Name', student['name'] ?? ''),
          _pdfInfoRow('Phone', student['phone'] ?? ''),
          _pdfInfoRow('Seat', student['seatNumber'] ?? 'Not assigned'),
          _pdfInfoRow('Fee Plan', student['feePlan'] ?? '-'),
          _pdfInfoRow('Fee Amount', '$currencySymbol${student['feeAmount'] ?? 0}'),
          _pdfInfoRow('Status', student['isActive'] == true ? 'Active' : 'Inactive'),
          _pdfInfoRow('Joining Date', student['joiningDate'] ?? '-'),
          pw.SizedBox(height: 16),

          // Books Issued
          pw.Text('Books Issued (${books.length})', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          if (books.isNotEmpty)
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
              headers: ['Title', 'Author', 'Issue Date', 'Status'],
              data: books.map((b) => [
                b['title'] ?? '',
                b['author'] ?? '-',
                b['issueDate'] ?? '-',
                (b['status'] ?? '').toString().toUpperCase(),
              ]).toList(),
            )
          else
            pw.Text('No books issued', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
          pw.SizedBox(height: 16),

          // Fee History
          pw.Text('Fee History (${fees.length})', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          if (fees.isNotEmpty)
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
              headers: ['Month', 'Amount', 'Status', 'Due Date'],
              data: fees.map((f) => [
                f['month'] ?? '',
                '$currencySymbol${f['amount'] ?? 0}',
                (f['status'] ?? '').toString().toUpperCase(),
                f['dueDate'] ?? '-',
              ]).toList(),
            )
          else
            pw.Text('No fee records', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
          pw.SizedBox(height: 16),

          // Summary
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _pdfStatBox('Total Books', '${books.length}'),
                _pdfStatBox('Total Fees Due', '$currencySymbol${totalDue.toStringAsFixed(0)}'),
                _pdfStatBox('Fee Records', '${fees.length}'),
              ],
            ),
          ),
        ],
      ),
    );

    return await pdf.save();
  }

  Future<File> exportStudentReport({
    required Map<String, dynamic> student,
    required List<Map<String, dynamic>> books,
    required List<Map<String, dynamic>> fees,
    required String libraryName,
    required Directory outputDir,
    String currencySymbol = '\$',
  }) async {
    final bytes = await getStudentReportBytes(student: student, books: books, fees: fees, libraryName: libraryName, currencySymbol: currencySymbol);
    final rawName = student['name']?.toString() ?? 'report';
    final name = rawName.replaceAll(RegExp(r'[^\w\s-]'), '_').trim();
    final file = File('${outputDir.path}/student_report_$name.pdf');
    await file.writeAsBytes(bytes);
    return file;
  }

  pw.Widget _pdfInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        children: [
          pw.SizedBox(width: 100, child: pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600))),
          pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  Future<Uint8List> getAttendanceBytes({
    required List<Map<String, dynamic>> records,
    required String libraryName,
    required String date,
  }) async {
    final pdf = pw.Document();
    final presentCount = records.where((r) => r['checkIn'] != null).length;
    final absentCount = records.length - presentCount;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('$libraryName - Attendance Report', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Text('Date: $date', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
            pw.SizedBox(height: 8),
            pw.Row(
              children: [
                _pdfStatBox('Present', '$presentCount'),
                pw.SizedBox(width: 16),
                _pdfStatBox('Absent', '$absentCount'),
                pw.SizedBox(width: 16),
                _pdfStatBox('Total', '${records.length}'),
              ],
            ),
            pw.SizedBox(height: 12),
          ],
        ),
        footer: (context) => pw.Text('Page ${context.pageNumber}/${context.pagesCount}', style: const pw.TextStyle(fontSize: 10)),
        build: (context) => [
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellAlignment: pw.Alignment.centerLeft,
            headers: ['#', 'Student Name', 'Check-in', 'Check-out', 'Status', 'Method'],
            data: records.asMap().entries.map((entry) {
              final i = entry.key;
              final r = entry.value;
              return [
                '${i + 1}',
                r['studentName'] ?? '',
                r['checkIn'] ?? '-',
                r['checkOut'] ?? '-',
                r['status'] ?? 'Absent',
                r['method'] ?? '-',
              ];
            }).toList(),
          ),
        ],
      ),
    );

    return await pdf.save();
  }

  Future<File> exportAttendanceToPdf({
    required List<Map<String, dynamic>> records,
    required String libraryName,
    required String date,
    required Directory outputDir,
  }) async {
    final bytes = await getAttendanceBytes(records: records, libraryName: libraryName, date: date);
    final file = File('${outputDir.path}/attendance_report.pdf');
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<File> exportStaffToPdf({
    required List<Map<String, dynamic>> staff,
    required String libraryName,
    required Directory outputDir,
  }) async {
    final pdf = pw.Document();
    final now = DateFormat('dd MMM yyyy').format(DateTime.now());
    final activeCount = staff.where((s) => s['isActive'] == true).length;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('$libraryName - Staff Report', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Text('Generated: $now', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
            pw.SizedBox(height: 8),
            pw.Row(
              children: [
                _pdfStatBox('Total Staff', '${staff.length}'),
                pw.SizedBox(width: 16),
                _pdfStatBox('Active', '$activeCount'),
              ],
            ),
            pw.SizedBox(height: 12),
          ],
        ),
        footer: (context) => pw.Text('Page ${context.pageNumber}/${context.pagesCount}', style: const pw.TextStyle(fontSize: 10)),
        build: (context) => [
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellAlignment: pw.Alignment.centerLeft,
            headers: ['#', 'Name', 'Email', 'Phone', 'Role', 'Status'],
            data: staff.asMap().entries.map((entry) {
              final i = entry.key;
              final s = entry.value;
              return [
                '${i + 1}',
                s['name'] ?? '',
                s['email'] ?? '',
                s['phone'] ?? '',
                s['role'] ?? '-',
                s['isActive'] == true ? 'Active' : 'Inactive',
              ];
            }).toList(),
          ),
        ],
      ),
    );

    final file = File('${outputDir.path}/staff_report.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  /// Generate a professional fee receipt PDF
  Future<Uint8List> generateFeeReceipt({
    required String studentName,
    required double amount,
    required String currencySymbol,
    required DateTime paymentDate,
    required String paymentMethod,
    required String feePlan,
    required String receiptNumber,
    String libraryName = 'Library Manager and Owner',
  }) async {
    final pdf = pw.Document();
    final dateStr = DateFormat('dd MMM yyyy').format(paymentDate);
    final timeStr = DateFormat('hh:mm a').format(paymentDate);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(libraryName, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  pw.Text('FEE RECEIPT', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
            pw.Divider(thickness: 2),
            pw.SizedBox(height: 12),

            // Receipt info
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Receipt No:', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                pw.Text(receiptNumber, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Date:', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                pw.Text('$dateStr  $timeStr', style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Divider(),
            pw.SizedBox(height: 12),

            // Student info
            pw.Text('Student Details', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            _pdfInfoRow('Name', studentName),
            _pdfInfoRow('Fee Plan', feePlan),
            pw.SizedBox(height: 16),
            pw.Divider(),
            pw.SizedBox(height: 12),

            // Payment info
            pw.Text('Payment Details', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            _pdfInfoRow('Method', paymentMethod),
            pw.SizedBox(height: 16),

            // Amount box
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.green50,
                border: pw.Border.all(color: PdfColors.green300),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                children: [
                  pw.Text('AMOUNT PAID', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    '$currencySymbol${amount.toStringAsFixed(0)}',
                    style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.green800),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 24),

            // Footer
            pw.Divider(),
            pw.SizedBox(height: 8),
            pw.Center(
              child: pw.Text('Thank you for your payment!', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
            ),
            pw.SizedBox(height: 4),
            pw.Center(
              child: pw.Text('This is a computer-generated receipt.', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey400)),
            ),
          ],
        ),
      ),
    );

    return await pdf.save();
  }

  /// Export fees to Excel
  Future<File> exportFeesToExcel({
    required List<Map<String, dynamic>> fees,
    required String libraryName,
    required String month,
    required Directory outputDir,
    String currencySymbol = '\$',
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel['Fees'];

    sheet.appendRow([
      TextCellValue('Student Name'),
      TextCellValue('Amount'),
      TextCellValue('Status'),
      TextCellValue('Due Date'),
      TextCellValue('Payment Method'),
      TextCellValue('Month'),
    ]);

    for (final f in fees) {
      sheet.appendRow([
        TextCellValue(f['studentName'] ?? ''),
        TextCellValue('$currencySymbol${f['amount'] ?? 0}'),
        TextCellValue((f['status'] ?? '').toString().toUpperCase()),
        TextCellValue(f['dueDate'] ?? '-'),
        TextCellValue(f['paymentMethod'] ?? '-'),
        TextCellValue(month),
      ]);
    }

    final file = File('${outputDir.path}/fee_report.xlsx');
    final bytes = excel.encode();
    if (bytes != null) await file.writeAsBytes(bytes);
    return file;
  }

  /// Export attendance to Excel
  Future<File> exportAttendanceToExcel({
    required List<Map<String, dynamic>> records,
    required String libraryName,
    required String date,
    required Directory outputDir,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel['Attendance'];

    sheet.appendRow([
      TextCellValue('#'),
      TextCellValue('Student Name'),
      TextCellValue('Check-in'),
      TextCellValue('Check-out'),
      TextCellValue('Status'),
      TextCellValue('Method'),
    ]);

    for (var i = 0; i < records.length; i++) {
      final r = records[i];
      sheet.appendRow([
        TextCellValue('${i + 1}'),
        TextCellValue(r['studentName'] ?? ''),
        TextCellValue(r['checkIn'] ?? '-'),
        TextCellValue(r['checkOut'] ?? '-'),
        TextCellValue(r['status'] ?? 'Absent'),
        TextCellValue(r['method'] ?? '-'),
      ]);
    }

    final file = File('${outputDir.path}/attendance_report.xlsx');
    final bytes = excel.encode();
    if (bytes != null) await file.writeAsBytes(bytes);
    return file;
  }

  Future<void> shareFile(File file, {String? subject}) async {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], subject: subject ?? 'Library Report'),
    );
  }
}
