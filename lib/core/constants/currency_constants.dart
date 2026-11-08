/// Shared currency data used by settings screen and auth screen.
const List<Map<String, String>> kCurrencies = [
  {'symbol': '\$', 'code': 'USD', 'locale': 'en_US', 'name': 'US Dollar'},
  {'symbol': '\u20ac', 'code': 'EUR', 'locale': 'en_US', 'name': 'Euro'},
  {'symbol': '\u00a3', 'code': 'GBP', 'locale': 'en_GB', 'name': 'British Pound'},
  {'symbol': '\u20b9', 'code': 'INR', 'locale': 'en_IN', 'name': 'Indian Rupee'},
  {'symbol': '\u00a5', 'code': 'JPY', 'locale': 'ja_JP', 'name': 'Japanese Yen'},
  {'symbol': 'A\$', 'code': 'AUD', 'locale': 'en_AU', 'name': 'Australian Dollar'},
  {'symbol': 'C\$', 'code': 'CAD', 'locale': 'en_CA', 'name': 'Canadian Dollar'},
  {'symbol': 'R\$', 'code': 'BRL', 'locale': 'pt_BR', 'name': 'Brazilian Real'},
  {'symbol': '\u20a9', 'code': 'KRW', 'locale': 'ko_KR', 'name': 'South Korean Won'},
  {'symbol': '\u00a5', 'code': 'CNY', 'locale': 'zh_CN', 'name': 'Chinese Yuan'},
  {'symbol': '\u20bd', 'code': 'RUB', 'locale': 'ru_RU', 'name': 'Russian Ruble'},
  {'symbol': 'CHF', 'code': 'CHF', 'locale': 'de_CH', 'name': 'Swiss Franc'},
  {'symbol': 'R', 'code': 'ZAR', 'locale': 'en_ZA', 'name': 'South African Rand'},
  {'symbol': '\u20ba', 'code': 'TRY', 'locale': 'tr_TR', 'name': 'Turkish Lira'},
  {'symbol': '\u20ab', 'code': 'VND', 'locale': 'vi_VN', 'name': 'Vietnamese Dong'},
  {'symbol': 'RM', 'code': 'MYR', 'locale': 'ms_MY', 'name': 'Malaysian Ringgit'},
  {'symbol': '\u20b1', 'code': 'PHP', 'locale': 'en_PH', 'name': 'Philippine Peso'},
  {'symbol': '\u0e3f', 'code': 'THB', 'locale': 'th_TH', 'name': 'Thai Baht'},
  {'symbol': 'SAR', 'code': 'SAR', 'locale': 'ar_SA', 'name': 'Saudi Riyal'},
  {'symbol': '\u062f.\u0625', 'code': 'AED', 'locale': 'ar_AE', 'name': 'UAE Dirham'},
];

/// Maps a currency code to its primary country dial code.
const Map<String, String> kCurrencyDialCodes = {
  'USD': '+1',
  'EUR': '+49',
  'GBP': '+44',
  'INR': '+91',
  'JPY': '+81',
  'AUD': '+61',
  'CAD': '+1',
  'BRL': '+55',
  'KRW': '+82',
  'CNY': '+86',
  'RUB': '+7',
  'CHF': '+41',
  'ZAR': '+27',
  'TRY': '+90',
  'VND': '+84',
  'MYR': '+60',
  'PHP': '+63',
  'THB': '+66',
  'SAR': '+966',
  'AED': '+971',
};

/// Returns the dial code for a currency code, defaulting to '+1'.
String dialCodeForCurrency(String currencyCode) {
  return kCurrencyDialCodes[currencyCode] ?? '+1';
}
