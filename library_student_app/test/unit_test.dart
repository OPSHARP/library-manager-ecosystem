import 'package:flutter_test/flutter_test.dart';
import 'package:library_student_app/features/dashboard/data/models/seat_model.dart';

void main() {
  group('SeatModel Shift Tests in Student App', () {
    test('isShiftAvailable correctly checks shifts', () {
      final seat = SeatModel(
        seatId: 'S-01',
        seatNumber: '1',
        status: 'available',
        shifts: {
          'Morning (6 AM - 12 PM)': const ShiftAssignment(
            studentId: 'std_1',
            studentName: 'Rahul',
          ),
        },
      );

      // Morning is occupied
      expect(seat.isShiftAvailable('Morning (6 AM - 12 PM)'), isFalse);

      // Evening and Night are available
      expect(seat.isShiftAvailable('Evening (12 PM - 6 PM)'), isTrue);
      expect(seat.isShiftAvailable('Night (6 PM - 12 AM)'), isTrue);

      // Full day is not available if any shift is taken
      expect(seat.isShiftAvailable('Full Day'), isFalse);
    });

    test('Fully vacant seat allows Full Day and all shifts', () {
      final seat = SeatModel(
        seatId: 'S-02',
        seatNumber: '2',
        status: 'available',
        shifts: {},
      );

      expect(seat.isShiftAvailable('Full Day'), isTrue);
      expect(seat.isShiftAvailable('Morning (6 AM - 12 PM)'), isTrue);
      expect(seat.isShiftAvailable('Evening (12 PM - 6 PM)'), isTrue);
      expect(seat.isShiftAvailable('Night (6 PM - 12 AM)'), isTrue);
    });
  });
}
