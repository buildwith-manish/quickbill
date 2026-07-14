/// Lightweight validators for Indian tax / banking identifiers.
///
/// All functions return `null` when the input is valid, or a human-readable
/// error string otherwise. This signature works directly as a `FormField`
/// validator in Flutter.
library;

/// GSTIN format: 15 chars
///   2-digit state code
///   10-char PAN (5 letters + 4 digits + 1 letter)
///   1 entity code (alphanumeric)
///   'Z' default
///   1 checksum (alphanumeric)
final RegExp _gstinRegex = RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$');

String? validateGstin(String? value, {bool allowEmpty = true}) {
  final v = value?.trim().toUpperCase() ?? '';
  if (v.isEmpty) {
    return allowEmpty ? null : 'GSTIN is required';
  }
  if (v.length != 15) {
    return 'GSTIN must be 15 characters';
  }
  if (!_gstinRegex.hasMatch(v)) {
    return 'Invalid GSTIN format';
  }
  return null;
}

/// PAN format: 5 letters + 4 digits + 1 letter (10 chars total).
final RegExp _panRegex = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$');

String? validatePan(String? value) {
  final v = value?.trim().toUpperCase() ?? '';
  if (v.isEmpty) return null;
  if (v.length != 10 || !_panRegex.hasMatch(v)) {
    return 'Invalid PAN format (AAAAA9999A)';
  }
  return null;
}

/// IFSC: 4 letters + '0' + 6 alphanumeric (11 chars total).
final RegExp _ifscRegex = RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$');

String? validateIfsc(String? value) {
  final v = value?.trim().toUpperCase() ?? '';
  if (v.isEmpty) return null;
  if (!_ifscRegex.hasMatch(v)) {
    return 'Invalid IFSC (e.g. HDFC0001234)';
  }
  return null;
}

/// UPI ID: name@handle. Permissive — doesn't enforce bank-side rules.
final RegExp _upiRegex = RegExp(r'^[A-Za-z0-9.\-_]{2,}@[A-Za-z]{2,}$');

String? validateUpi(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return null;
  if (!_upiRegex.hasMatch(v)) {
    return 'Invalid UPI ID (e.g. name@oksbi)';
  }
  return null;
}

String? validateEmail(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return null;
  final regex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  if (!regex.hasMatch(v)) return 'Invalid email address';
  return null;
}

String? validatePhone(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return null;
  final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length != 10) return 'Phone must be 10 digits';
  return null;
}

String? validateRequired(String? value, String fieldName) {
  if (value == null || value.trim().isEmpty) {
    return '$fieldName is required';
  }
  return null;
}

String? validateStateCode(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'State is required';
  }
  return null;
}
