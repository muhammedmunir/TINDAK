package my.tindak.app

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Receives Android share intents and hands the text to Dart.
 *
 * Implemented natively with no third-party package (ADR-017). The share intent
 * is the single entry point of the whole product, and cold start is where share
 * receivers usually fail, so this stays under our control.
 *
 * Two delivery paths:
 *
 *  - Cold start. The intent exists before Dart is running, so it is held in
 *    [pendingShare] and collected when Dart asks via [METHOD_INITIAL_SHARE].
 *  - Already running. [onNewIntent] pushes straight down the channel. If the
 *    channel is somehow not ready it falls back to [pendingShare].
 *
 * Every payload carries a monotonic [sequence] so Dart can discard a repeat.
 * The intent is also stamped consumed, so the same Intent object redelivered by
 * a lifecycle event is not processed twice.
 */
class MainActivity : FlutterActivity() {

    private var channel: MethodChannel? = null
    private var pendingShare: Map<String, Any?>? = null
    private var sequence = 0L

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_NAME,
        )
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                METHOD_INITIAL_SHARE -> {
                    // Handed over exactly once. A second call returns null
                    // rather than replaying the same share.
                    result.success(pendingShare)
                    pendingShare = null
                }
                else -> result.notImplemented()
            }
        }
        channel = methodChannel
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        // super.onCreate attaches the engine, which calls
        // configureFlutterEngine, so the channel exists by the time we return.
        // Dart cannot have called getInitialShare yet: both this and the method
        // handler run on the UI thread.
        super.onCreate(savedInstanceState)
        readShare(intent)?.let { pendingShare = it }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Keep getIntent() in step, so a later lifecycle event sees the intent
        // that is actually on screen.
        setIntent(intent)

        val payload = readShare(intent) ?: return
        val ready = channel
        if (ready != null) {
            ready.invokeMethod(METHOD_SHARE_RECEIVED, payload)
        } else {
            pendingShare = payload
        }
    }

    /**
     * Turns an intent into a payload, or null when there is nothing usable.
     *
     * Everything here is attacker-controlled: any app on the device can send an
     * ACTION_SEND intent with any contents. Rejecting quietly and landing on
     * Home is the safe failure (docs/12_SECURITY.md section 7).
     */
    private fun readShare(intent: Intent?): Map<String, Any?>? {
        if (intent == null) return null

        // ACTION_SEND only. ACTION_SEND_MULTIPLE is not declared and not V1.
        if (intent.action != Intent.ACTION_SEND) return null

        // A redelivered Intent object must not produce a second share.
        if (intent.getBooleanExtra(EXTRA_CONSUMED, false)) return null

        val type = intent.type
        if (type == null || !type.startsWith(MIME_TEXT_PLAIN)) {
            // Not declared in the manifest, so this only arrives from an app
            // that built the intent by hand. Mark it consumed so it is not
            // re-examined, and drop it.
            intent.putExtra(EXTRA_CONSUMED, true)
            return null
        }

        // getCharSequenceExtra rather than getStringExtra: EXTRA_TEXT may carry
        // styled text. toString() flattens it to plain characters, which is all
        // TINDAK ever renders. No HTML, no markup, no WebView.
        val text = intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString()

        intent.putExtra(EXTRA_CONSUMED, true)

        // Blank, not merely empty: a share of nothing but whitespace must not
        // produce a result screen. Dart enforces the same rule, so the two
        // layers cannot drift apart.
        if (text.isNullOrBlank()) return null

        sequence += 1
        return mapOf(
            KEY_SEQUENCE to sequence,
            KEY_TEXT to text,
            KEY_SOURCE_APP to callingPackageName(),
            KEY_RECEIVED_AT to System.currentTimeMillis(),
        )
    }

    /**
     * The package that started the share, when Android is willing to say.
     *
     * Best effort and often null. It is stored for product analytics later, is
     * never trusted, and never drives behaviour.
     */
    private fun callingPackageName(): String? = referrer?.host

    private companion object {
        const val CHANNEL_NAME = "my.tindak.app/share"
        const val METHOD_INITIAL_SHARE = "getInitialShare"
        const val METHOD_SHARE_RECEIVED = "onShareReceived"
        const val MIME_TEXT_PLAIN = "text/plain"
        const val EXTRA_CONSUMED = "my.tindak.app.SHARE_CONSUMED"
        const val KEY_SEQUENCE = "sequence"
        const val KEY_TEXT = "text"
        const val KEY_SOURCE_APP = "sourceApp"
        const val KEY_RECEIVED_AT = "receivedAt"
    }
}
