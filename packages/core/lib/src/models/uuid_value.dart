import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart' as uuid_lib;

/// Unique identifier value object
@immutable
class UuidValue {
  final String value;

  const UuidValue._(this.value);

  /// Create a new random UUID (v4)
  factory UuidValue.generate() {
    return UuidValue._(const uuid_lib.Uuid().v4());
  }

  /// Create from existing string (validates format)
  factory UuidValue.fromString(String value) {
    if (!_isValidUuid(value)) {
      throw FormatException('Invalid UUID format: $value');
    }
    return UuidValue._(value.toLowerCase());
  }

  /// Try to create from string, returns null if invalid
  static UuidValue? tryFromString(String? value) {
    if (value == null || !_isValidUuid(value)) {
      return null;
    }
    return UuidValue._(value.toLowerCase());
  }

  /// Zero UUID (nil UUID)
  static const UuidValue zero = UuidValue._(
    '00000000-0000-0000-0000-000000000000',
  );

  /// Check if this is the zero/nil UUID
  bool get isZero => value == zero.value;

  /// Check if this is a valid non-zero UUID
  bool get isValid => !isZero;

  static bool _isValidUuid(String value) {
    final pattern = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    return pattern.hasMatch(value);
  }

  @override
  String toString() => value;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UuidValue && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;

  /// Compare two UUIDs
  int compareTo(UuidValue other) => value.compareTo(other.value);
}

/// Extension to generate UUID strings easily
extension UuidGenerator on Never {
  /// Generate a new UUID string
  static String generateUuid() => const uuid_lib.Uuid().v4();
}
