import 'package:flutter_test/flutter_test.dart';
import 'package:quickbill/utils/gst_state_codes.dart';

void main() {
  group('gst_state_codes', () {
    test('contains all 36 states + UTs', () {
      // The official list has 36 entries (with 28 = AP Old and 37 = AP New).
      // We include a few extra historical / territory codes (97 = Other Territory).
      expect(gstStateCodes.length, greaterThanOrEqualTo(36));
    });

    test('known codes map to expected names', () {
      expect(gstStateCodes['07'], 'Delhi');
      expect(gstStateCodes['27'], 'Maharashtra');
      expect(gstStateCodes['29'], 'Karnataka');
      expect(gstStateCodes['33'], 'Tamil Nadu');
      expect(gstStateCodes['36'], 'Telangana');
      expect(gstStateCodes['24'], 'Gujarat');
      expect(gstStateCodes['09'], 'Uttar Pradesh');
    });
  });

  group('stateCodeFromGstin', () {
    test('extracts first 2 chars of a valid GSTIN', () {
      expect(stateCodeFromGstin('27ABCDE1234F1Z5'), '27'); // Maharashtra
      expect(stateCodeFromGstin('07AAACI1234L1ZP'), '07'); // Delhi
      expect(stateCodeFromGstin('29AABCU1234M1Z1'), '29'); // Karnataka
    });

    test('returns null for short input', () {
      expect(stateCodeFromGstin(''), isNull);
      expect(stateCodeFromGstin('2'), isNull);
      expect(stateCodeFromGstin(null), isNull);
    });

    test('returns null for unknown prefix', () {
      expect(stateCodeFromGstin('99ABCDE1234F1Z5'), isNull); // 99 not in list
      expect(stateCodeFromGstin('00ABCDE1234F1Z5'), isNull); // 00 not in list
    });
  });

  group('stateNameForCode', () {
    test('returns the state name for a known code', () {
      expect(stateNameForCode('07'), 'Delhi');
      expect(stateNameForCode('33'), 'Tamil Nadu');
    });

    test('returns null for unknown code', () {
      expect(stateNameForCode('99'), isNull);
      expect(stateNameForCode(null), isNull);
    });
  });
}
