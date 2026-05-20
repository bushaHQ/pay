# Busha Pay SDK — consumer ProGuard/R8 rules.
#
# The public API surface is referenced by name from merchant apps and
# must survive shrinking/obfuscation in release builds.
-keep public class co.busha.pay.BushaPay { public *; }
-keep public class co.busha.pay.BushaPayConfig { public *; }
-keep public class co.busha.pay.BushaPayResult { *; }
-keep public class co.busha.pay.BushaPayResult$* { *; }
-keep public class co.busha.pay.BushaPaySuccess { *; }
-keep public class co.busha.pay.BushaPayError { *; }
-keep public class co.busha.pay.BushaPayCancelled { *; }
-keep public enum co.busha.pay.BushaEnvironment { *; }
-keep public enum co.busha.pay.PaymentMethod { *; }
-keep public enum co.busha.pay.BushaPayCancelledReason { *; }
