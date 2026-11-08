import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for the seat layout grid configuration stored in Firestore.
class SeatLayoutModel {
  final String layoutId;
  final String libraryId;
  final int rows;
  final int cols;
  final List<SeatLayoutCell> cells;
  final DateTime? updatedAt;

  const SeatLayoutModel({
    required this.layoutId,
    required this.libraryId,
    required this.rows,
    required this.cols,
    required this.cells,
    this.updatedAt,
  });

  factory SeatLayoutModel.fromJson(Map<String, dynamic> json) {
    return SeatLayoutModel(
      layoutId: json['layoutId'] ?? '',
      libraryId: json['libraryId'] ?? '',
      rows: json['rows'] ?? 6,
      cols: json['cols'] ?? 5,
      cells: (json['cells'] as List<dynamic>? ?? [])
          .map((e) => SeatLayoutCell.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      updatedAt: _parseTimestamp(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'layoutId': layoutId,
      'libraryId': libraryId,
      'rows': rows,
      'cols': cols,
      'cells': cells.map((c) => c.toJson()).toList(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    if (value is DateTime) return value;
    return null;
  }

  factory SeatLayoutModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      return SeatLayoutModel(layoutId: doc.id, libraryId: '', rows: 6, cols: 5, cells: []);
    }
    return SeatLayoutModel(
      layoutId: data['layoutId'] ?? doc.id,
      libraryId: data['libraryId'] ?? '',
      rows: data['rows'] ?? 6,
      cols: data['cols'] ?? 5,
      cells: (data['cells'] as List<dynamic>? ?? [])
          .map((e) => SeatLayoutCell.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      updatedAt: _parseTimestamp(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'layoutId': layoutId,
      'libraryId': libraryId,
      'rows': rows,
      'cols': cols,
      'cells': cells.map((c) => c.toJson()).toList(),
      'updatedAt': updatedAt,
    };
  }

  SeatLayoutModel copyWith({
    String? layoutId,
    String? libraryId,
    int? rows,
    int? cols,
    List<SeatLayoutCell>? cells,
    DateTime? updatedAt,
  }) {
    return SeatLayoutModel(
      layoutId: layoutId ?? this.layoutId,
      libraryId: libraryId ?? this.libraryId,
      rows: rows ?? this.rows,
      cols: cols ?? this.cols,
      cells: cells ?? this.cells,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Single cell in the layout grid.
class SeatLayoutCell {
  final String id;
  final String label;
  final String category;
  final String status; // 'available', 'maintenance', 'removed'

  const SeatLayoutCell({
    required this.id,
    required this.label,
    required this.category,
    required this.status,
  });

  factory SeatLayoutCell.fromJson(Map<String, dynamic> json) {
    return SeatLayoutCell(
      id: json['id'] ?? '',
      label: json['label'] ?? '',
      category: json['category'] ?? 'Normal',
      status: json['status'] ?? 'available',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'category': category,
      'status': status,
    };
  }

  SeatLayoutCell copyWith({
    String? category,
    String? status,
  }) {
    return SeatLayoutCell(
      id: id,
      label: label,
      category: category ?? this.category,
      status: status ?? this.status,
    );
  }
}
