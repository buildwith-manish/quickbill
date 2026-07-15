/// All 36 Indian state / UT GST codes (first 2 digits of any GSTIN).
///
/// Source: GSTN state code list. Used to:
///  - populate state dropdowns
///  - derive a seller/buyer state from the first 2 digits of a GSTIN
///  - render the state name on invoices and PDFs
const Map<String, String> gstStateCodes = {
  '01': 'Jammu and Kashmir',
  '02': 'Himachal Pradesh',
  '03': 'Punjab',
  '04': 'Chandigarh',
  '05': 'Uttarakhand',
  '06': 'Haryana',
  '07': 'Delhi',
  '08': 'Rajasthan',
  '09': 'Uttar Pradesh',
  '10': 'Bihar',
  '11': 'Sikkim',
  '12': 'Arunachal Pradesh',
  '13': 'Nagaland',
  '14': 'Manipur',
  '15': 'Mizoram',
  '16': 'Tripura',
  '17': 'Meghalaya',
  '18': 'Assam',
  '19': 'West Bengal',
  '20': 'Jharkhand',
  '21': 'Odisha',
  '22': 'Chhattisgarh',
  '23': 'Madhya Pradesh',
  '24': 'Gujarat',
  '25': 'Daman and Diu',
  '26': 'Dadra and Nagar Haveli and Daman and Diu',
  '27': 'Maharashtra',
  '28': 'Andhra Pradesh (Old)',
  '29': 'Karnataka',
  '30': 'Goa',
  '31': 'Lakshadweep',
  '32': 'Kerala',
  '33': 'Tamil Nadu',
  '34': 'Puducherry',
  '35': 'Andaman and Nicobar Islands',
  '36': 'Telangana',
  '37': 'Andhra Pradesh',
  '38': 'Ladakh',
  '97': 'Other Territory',
};

/// Returns the state code derived from the first 2 digits of a GSTIN.
/// Returns null if the GSTIN is too short or the prefix is not a known code.
String? stateCodeFromGstin(String? gstin) {
  if (gstin == null || gstin.length < 2) return null;
  final prefix = gstin.substring(0, 2);
  return gstStateCodes.containsKey(prefix) ? prefix : null;
}

/// Returns the state name for a given code, or null if unknown.
String? stateNameForCode(String? code) {
  if (code == null) return null;
  return gstStateCodes[code];
}
