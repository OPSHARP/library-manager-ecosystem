class DashboardStatsModel {
  final int totalStudents;
  final int activeStudents;
  final int totalSeats;
  final int occupiedSeats;
  final int availableSeats;
  final int reservedSeats;
  final int todayPresent;
  final int todayAbsent;
  final double attendanceRate;
  final double monthlyRevenue;
  final double monthlyExpenses;
  final double pendingFees;
  final double collectedFees;
  final List<double> weeklyAttendance;
  final List<double> monthlyRevenueHistory;
  final double occupancyRate;

  double get netProfit => monthlyRevenue - monthlyExpenses;

  const DashboardStatsModel({
    this.totalStudents = 0,
    this.activeStudents = 0,
    this.totalSeats = 0,
    this.occupiedSeats = 0,
    this.availableSeats = 0,
    this.reservedSeats = 0,
    this.todayPresent = 0,
    this.todayAbsent = 0,
    this.attendanceRate = 0,
    this.monthlyRevenue = 0,
    this.monthlyExpenses = 0,
    this.pendingFees = 0,
    this.collectedFees = 0,
    this.weeklyAttendance = const [],
    this.monthlyRevenueHistory = const [],
    this.occupancyRate = 0,
  });

  factory DashboardStatsModel.fromData({
    required int totalStudents,
    required int activeStudents,
    required int totalSeats,
    required int occupiedSeats,
    required int availableSeats,
    required int reservedSeats,
    required int todayPresent,
    required int todayAbsent,
    required double monthlyRevenue,
    double monthlyExpenses = 0,
    required double pendingFees,
    required double collectedFees,
    List<double> weeklyAttendance = const [],
    List<double> monthlyRevenueHistory = const [],
  }) {
    final totalToday = todayPresent + todayAbsent;
    return DashboardStatsModel(
      totalStudents: totalStudents,
      activeStudents: activeStudents,
      totalSeats: totalSeats,
      occupiedSeats: occupiedSeats,
      availableSeats: availableSeats,
      reservedSeats: reservedSeats,
      todayPresent: todayPresent,
      todayAbsent: todayAbsent,
      attendanceRate: totalToday > 0 ? (todayPresent / totalToday) * 100 : 0,
      monthlyRevenue: monthlyRevenue,
      monthlyExpenses: monthlyExpenses,
      pendingFees: pendingFees,
      collectedFees: collectedFees,
      weeklyAttendance: weeklyAttendance,
      monthlyRevenueHistory: monthlyRevenueHistory,
      occupancyRate: totalSeats > 0 ? (occupiedSeats / totalSeats) * 100 : 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DashboardStatsModel &&
          runtimeType == other.runtimeType &&
          totalStudents == other.totalStudents &&
          activeStudents == other.activeStudents &&
          totalSeats == other.totalSeats &&
          occupiedSeats == other.occupiedSeats &&
          availableSeats == other.availableSeats &&
          reservedSeats == other.reservedSeats &&
          todayPresent == other.todayPresent &&
          todayAbsent == other.todayAbsent &&
          attendanceRate == other.attendanceRate &&
          monthlyRevenue == other.monthlyRevenue &&
          monthlyExpenses == other.monthlyExpenses &&
          pendingFees == other.pendingFees &&
          collectedFees == other.collectedFees &&
          _listEquals(weeklyAttendance, other.weeklyAttendance) &&
          _listEquals(monthlyRevenueHistory, other.monthlyRevenueHistory);

  @override
  int get hashCode => Object.hash(
        totalStudents,
        activeStudents,
        totalSeats,
        occupiedSeats,
        availableSeats,
        reservedSeats,
        todayPresent,
        todayAbsent,
        attendanceRate,
        monthlyRevenue,
        monthlyExpenses,
        pendingFees,
        collectedFees,
        Object.hashAll(weeklyAttendance),
        Object.hashAll(monthlyRevenueHistory),
      );

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
