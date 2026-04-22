/// Official Busha Pay SDK for Flutter.
///
/// Accept crypto payments in your app with a single integration.
///
/// ```dart
/// import 'package:busha_pay/busha_pay.dart';
///
/// // Initialize once (e.g., in main)
/// await BushaPay.init(publicKey: 'pub_xxx');
///
/// // Launch checkout
/// BushaPay.checkout(
///   context: context,
///   config: BushaPayConfig(
///     quoteAmount: '10000',
///     quoteCurrency: 'NGN',
///     targetCurrency: 'NGN',
///     sourceCurrency: 'USDT',
///   ),
///   onComplete: (result) {
///     switch (result) {
///       case BushaPaySuccess():
///         print('Paid: ${result.paymentId}');
///       case BushaPayCancelled():
///         print('Cancelled');
///       case BushaPayError():
///         print('Error: ${result.message}');
///     }
///   },
/// );
/// ```
library;

export 'busha_pay_config.dart';
export 'busha_pay_result.dart';
export 'busha_pay_button.dart';
export 'src/busha_pay_sdk.dart';
