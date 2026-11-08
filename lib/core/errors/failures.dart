/// Custom failure classes for error handling
abstract class Failure {
  final String message;
  final String? code;

  const Failure({required this.message, this.code});

  @override
  String toString() => message;
}

class AuthFailure extends Failure {
  const AuthFailure({required super.message, super.code});

  factory AuthFailure.fromCode(String code) {
    switch (code) {
      case 'user-not-found':
        return const AuthFailure(message: 'No account found with this email');
      case 'wrong-password':
        return const AuthFailure(message: 'Incorrect password');
      case 'email-already-in-use':
        return const AuthFailure(message: 'An account already exists with this email');
      case 'weak-password':
        return const AuthFailure(message: 'Password is too weak');
      case 'invalid-email':
        return const AuthFailure(message: 'Invalid email address');
      case 'too-many-requests':
        return const AuthFailure(message: 'Too many attempts. Please try again later');
      case 'user-disabled':
        return const AuthFailure(message: 'This account has been disabled');
      case 'operation-not-allowed':
        return const AuthFailure(message: 'This sign-in method is not enabled');
      case 'invalid-verification-code':
        return const AuthFailure(message: 'Invalid OTP code');
      case 'invalid-verification-id':
        return const AuthFailure(message: 'Verification session expired. Please try again');
      default:
        return AuthFailure(message: 'Authentication error: $code');
    }
  }
}

class FirestoreFailure extends Failure {
  const FirestoreFailure({required super.message, super.code});
}

class StorageFailure extends Failure {
  const StorageFailure({required super.message, super.code});
}

class NetworkFailure extends Failure {
  const NetworkFailure({
    super.message = 'No internet connection. Please check your network.',
    super.code,
  });
}

class PaymentFailure extends Failure {
  const PaymentFailure({required super.message, super.code});
}

class UnknownFailure extends Failure {
  const UnknownFailure({
    super.message = 'An unexpected error occurred. Please try again.',
    super.code,
  });
}
