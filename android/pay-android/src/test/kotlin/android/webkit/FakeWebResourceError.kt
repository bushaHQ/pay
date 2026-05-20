package android.webkit

/**
 * Test double for [WebResourceError].
 *
 * The framework class is abstract with a package-private constructor, so
 * it can only be subclassed from within `android.webkit`. This lives
 * here purely so checkout's `onReceivedError` handler can be unit-tested.
 */
class FakeWebResourceError(
    private val code: Int,
    private val desc: CharSequence,
) : WebResourceError() {
    override fun getErrorCode(): Int = code
    override fun getDescription(): CharSequence = desc
}
