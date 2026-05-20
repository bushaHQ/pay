package co.busha.pay.example

import android.app.Application
import co.busha.pay.BushaEnvironment
import co.busha.pay.BushaPay

/** Initializes the Busha Pay SDK once, at app startup. */
class ExampleApp : Application() {

    override fun onCreate() {
        super.onCreate()
        BushaPay.initialize(
            context = this,
            publicKey = PUBLIC_KEY,
            environment = BushaEnvironment.SANDBOX,
        )
    }

    companion object {
        // Replace with your own sandbox public key from
        // https://dash.busha.io → Settings → Developer Tools.
        const val PUBLIC_KEY = "pub_xxx"
    }
}
