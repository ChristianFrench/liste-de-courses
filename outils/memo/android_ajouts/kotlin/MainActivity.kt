package fr.listecourses.memo_emplettes

import android.content.Context
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// Le mémo est rangé dans les préférences « memo » : l'application l'écrit, le widget le lit.
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(moteur: FlutterEngine) {
        super.configureFlutterEngine(moteur)
        MethodChannel(moteur.dartExecutor.binaryMessenger, "memo").setMethodCallHandler { appel, resultat ->
            val prefs = getSharedPreferences("memo", Context.MODE_PRIVATE)
            when (appel.method) {
                "lire" -> resultat.success(prefs.getString("memo", null))
                "ecrire" -> {
                    prefs.edit().putString("memo", appel.arguments as String).commit()
                    MemoWidget.rafraichir(this)
                    resultat.success(true)
                }
                "ouvrir" -> resultat.success(try {
                    startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(appel.arguments as String)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                    true
                } catch (e: Exception) { false })
                else -> resultat.notImplemented()
            }
        }
    }
}
