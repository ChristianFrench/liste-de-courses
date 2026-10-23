package fr.listecourses.liste_de_courses

import android.content.Intent
import android.net.Uri
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

// Ticket de caisse reçu d'une autre application : « Partager » (ACTION_SEND) ou « Ouvrir avec » (ACTION_VIEW)
// d'un PDF. Le fichier est copié dans le cache de l'application, puis son chemin est remis à Flutter
// (canal « fr.listecourses/ticket ») : « ticketRecu » au démarrage, « ticket » si l'application était déjà ouverte.
// Copié dans le projet Android par outils/preparer.py.
class MainActivity : FlutterActivity() {
    private var canal: MethodChannel? = null
    private var enAttente: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        canal = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "fr.listecourses/ticket").also {
            it.setMethodCallHandler { appel, resultat ->
                if (appel.method == "ticketRecu") {
                    resultat.success(enAttente)
                    enAttente = null
                } else {
                    resultat.notImplemented()
                }
            }
        }
        enAttente = copier(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val chemin = copier(intent) ?: return
        val c = canal
        if (c == null) enAttente = chemin else c.invokeMethod("ticket", chemin)
    }

    private fun copier(intent: Intent?): String? {
        if (intent == null) return null
        val uri: Uri = when (intent.action) {
            Intent.ACTION_SEND ->
                if (Build.VERSION.SDK_INT >= 33) intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
                else @Suppress("DEPRECATION") intent.getParcelableExtra(Intent.EXTRA_STREAM)
            Intent.ACTION_VIEW -> intent.data
            else -> null
        } ?: return null
        // Une seule lecture par réception (pas de nouvelle copie au retour dans l'application).
        intent.action = Intent.ACTION_MAIN
        return try {
            val f = File(cacheDir, "ticket-recu-${System.currentTimeMillis()}.pdf")
            contentResolver.openInputStream(uri)?.use { entree -> f.outputStream().use { entree.copyTo(it) } } ?: return null
            f.absolutePath
        } catch (e: Exception) {
            null
        }
    }
}
