package fr.listecourses.liste_de_courses

import android.content.ComponentName
import android.content.ContentUris
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import androidx.core.content.FileProvider
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
                } else if (appel.method == "ouvrirPdf") {
                    resultat.success(ouvrirPdf(appel.arguments as String))
                } else if (appel.method == "copieDocuments") {
                    resultat.success(copieDocuments(appel.argument<String>("nom")!!, appel.argument<String>("chemin")!!))
                } else if (appel.method == "effacerDocument") {
                    resultat.success(effacerDocument(appel.argument<String>("nom")!!))
                } else if (appel.method == "partagerFichier") {
                    resultat.success(partagerFichier(appel.argument<String>("chemin")!!, appel.argument<String>("titre") ?: ""))
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

    // Ticket rangé dans les fichiers de l'application : prêté au lecteur de PDF (FileProvider
    // « <application>.tickets », déclaré par outils/preparer.py).
    private fun ouvrirPdf(chemin: String): Boolean {
        return try {
            val uri = FileProvider.getUriForFile(this, "$packageName.tickets", File(chemin))
            val voir = Intent(Intent.ACTION_VIEW).setDataAndType(uri, "application/pdf")
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            // L'application elle-même sait recevoir un PDF : on l'écarte, pour ne proposer que les lecteurs.
            val choix = Intent.createChooser(voir, "Ouvrir le ticket").addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            if (Build.VERSION.SDK_INT >= 24) {
                choix.putExtra(Intent.EXTRA_EXCLUDE_COMPONENTS, arrayOf(ComponentName(this, MainActivity::class.java)))
            }
            startActivity(choix)
            true
        } catch (e: Exception) {
            false
        }
    }

    // Sauvegardes (03/11/2026) : chaque copie est aussi déposée dans Documents/Emplettes du téléphone
    // (MediaStore, Android 10 et suivants, sans autorisation) ; elle y reste après une désinstallation.
    private val dossierDocuments = "Documents/Emplettes/"

    private fun trouverDocument(nom: String): Uri? {
        if (Build.VERSION.SDK_INT < 29) return null
        val table = MediaStore.Files.getContentUri("external")
        contentResolver.query(
            table, arrayOf(MediaStore.MediaColumns._ID),
            "${MediaStore.MediaColumns.RELATIVE_PATH} = ? AND ${MediaStore.MediaColumns.DISPLAY_NAME} = ?",
            arrayOf(dossierDocuments, nom), null
        )?.use { c -> if (c.moveToFirst()) return ContentUris.withAppendedId(table, c.getLong(0)) }
        return null
    }

    private fun copieDocuments(nom: String, chemin: String): Boolean {
        if (Build.VERSION.SDK_INT < 29) return false
        return try {
            val uri = trouverDocument(nom) ?: contentResolver.insert(
                MediaStore.Files.getContentUri("external"),
                ContentValues().apply {
                    put(MediaStore.MediaColumns.DISPLAY_NAME, nom)
                    put(MediaStore.MediaColumns.MIME_TYPE, "application/octet-stream")
                    put(MediaStore.MediaColumns.RELATIVE_PATH, dossierDocuments)
                }
            ) ?: return false
            contentResolver.openOutputStream(uri, "wt")?.use { sortie -> File(chemin).inputStream().use { it.copyTo(sortie) } }
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun effacerDocument(nom: String): Boolean {
        return try {
            val uri = trouverDocument(nom) ?: return false
            contentResolver.delete(uri, null, null) > 0
        } catch (e: Exception) {
            false
        }
    }

    // « Sauvegarder maintenant » : le fichier est proposé aux autres applications (Drive, mail, Fichiers…).
    private fun partagerFichier(chemin: String, titre: String): Boolean {
        return try {
            val uri = FileProvider.getUriForFile(this, "$packageName.tickets", File(chemin))
            val envoi = Intent(Intent.ACTION_SEND).setType("application/octet-stream")
                .putExtra(Intent.EXTRA_STREAM, uri)
                .putExtra(Intent.EXTRA_SUBJECT, titre)
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            val choix = Intent.createChooser(envoi, titre).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            if (Build.VERSION.SDK_INT >= 24) {
                choix.putExtra(Intent.EXTRA_EXCLUDE_COMPONENTS, arrayOf(ComponentName(this, MainActivity::class.java)))
            }
            startActivity(choix)
            true
        } catch (e: Exception) {
            false
        }
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
