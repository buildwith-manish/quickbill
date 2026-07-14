import 'package:flutter_test/flutter_test.dart';
import 'package:quickbill/utils/validators.dart';

void main() {
  group('validateGstin', () {
    test('valid GSTIN passes', () {
      // 27 = Maharashtra; this is a structurally-valid GSTIN.
      expect(validateGstin('27ABCDE1234F1Z5', allowEmpty: false), isNull);
    });

    test('lowercase gets uppercased and still valid', () {
      expect(validateGstin('27abcde1234f1z5', allowEmpty: false), isNull);
    });

    test('too short rejects', () {
      expect(validateGstin('27ABCDE1234F', allowEmpty: false), isNotNull);
    });

    test('empty allowed when allowEmpty=true', () {
      expect(validateGstin('', allowEmpty: true), isNull);
      expect(validateGstin(null, allowEmpty: true), isNull);
    });

    test('empty rejected when allowEmpty=false', () {
      expect(validateGstin('', allowEmpty: false), isNotNull);
    });

    test('invalid checksum chars rejected', () {
      expect(validateGstin('27ABCDE1234F1Z!', allowEmpty: false), isNotNull);
    });
  });

  group('validatePan', () {
    test('valid PAN passes', () {
      expect(validatePan('ABCDE1234F'), isNull);
    });

    test('invalid format rejected', () {
      expect(validatePan('ABCDE1234'), isNotNull); // too short (9 chars)
      expect(validatePan('12345ABCDE'), isNotNull); // wrong pattern (digits first)
      expect(validatePan('ABCDE12345'), isNotNull); // 10 chars but ends with digit
    });

    test('lowercase input is normalised and passes when valid', () {
      // The validator uppercases input before checking the regex, so a
      // structurally-valid lowercase PAN should pass.
      expect(validatePan('abcde1234f'), isNull);
    });

    test('empty allowed', () {
      expect(validatePan(''), isNull);
      expect(validatePan(null), isNull);
    });
  });

  group('validateIfsc', () {
    test('valid IFSC passes', () {
      expect(validateIfsc('HDFC0001234'), isNull);
    });

    test('5th char must be 0', () {
      expect(validateIfsc('HDFC1001234'), isNotNull);
    });

    test('too short rejected', () {
      expect(validateIfsc('HDFC01234'), isNotNull);
    });
  });

  group('validateUpi', () {
    test('valid UPI ID passes', () {
      expect(validateUpi('anjali@oksbi'), isNull);
      expect(validateUpi('anjali.sharma@paytm'), isNull);
      expect(validateUpi('a-b_c.123@ybl'), isNull);
    });

    test('missing @ rejected', () {
      expect(validateUpi('anjali'), isNotNull);
    });

    test('empty allowed', () {
      expect(validateUpi(''), isNull);
    });
  });

  group('validateEmail', () {
    test('valid emails pass', () {
      expect(validateEmail('anjali@example.com'), isNull);
      expect(validateEmail('a.b+tag@sub.example.co.in'), isNull);
    });

    test('invalid emails rejected', () {
      expect(validateEmail('anjali'), isNotNull);
      expect(validateEmail('anjali@'), isNotNull);
      expect(validateEmail('anjali@example'), isNotNull);
    });
  });

  group('validatePhone', () {
    test('valid 10-digit passes', () {
      expect(validatePhone('9876543210'), isNull);
      expect(validatePhone('98765 43210'), isNull); // spaces stripped, 10 digits remain
    });

    test('wrong length rejected', () {
      expect(validatePhone('987654321'), isNotNull); // 9 digits
      expect(validatePhone('98765432101'), isNotNull); // 11 digits
      expect(validatePhone('+91 98765 43210'), isNotNull); // 12 digits after strip
    });
  });
}
