package fr.listecourses.memo_emplettes

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONArray

// Widget d'écran d'accueil : les rubriques cochées « dans le widget » de l'application, liens à toucher.
class MemoWidget : AppWidgetProvider() {
    override fun onUpdate(contexte: Context, gestionnaire: AppWidgetManager, ids: IntArray) {
        for (id in ids) gestionnaire.updateAppWidget(id, vues(contexte, id))
    }

    companion object {
        fun vues(contexte: Context, id: Int): RemoteViews {
            val v = RemoteViews(contexte.packageName, R.layout.memo_widget)
            val service = Intent(contexte, MemoService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id)
                data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
            }
            @Suppress("DEPRECATION")
            v.setRemoteAdapter(R.id.liste, service)
            v.setEmptyView(R.id.liste, R.id.vide)
            val ouvrir = PendingIntent.getActivity(contexte, 1, Intent(Intent.ACTION_VIEW),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE)
            v.setPendingIntentTemplate(R.id.liste, ouvrir)
            val appli = PendingIntent.getActivity(contexte, 2,
                Intent(contexte, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            v.setOnClickPendingIntent(R.id.titre, appli)
            v.setOnClickPendingIntent(R.id.vide, appli)
            return v
        }

        fun rafraichir(contexte: Context) {
            val g = AppWidgetManager.getInstance(contexte)
            val ids = g.getAppWidgetIds(ComponentName(contexte, MemoWidget::class.java))
            for (id in ids) g.updateAppWidget(id, vues(contexte, id))
            @Suppress("DEPRECATION")
            g.notifyAppWidgetViewDataChanged(ids, R.id.liste)
        }
    }
}

class MemoService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory = Fabrique(applicationContext)
}

private class Ligne(val rubrique: Boolean, val nom: String, val adresse: String)

private class Fabrique(val contexte: Context) : RemoteViewsService.RemoteViewsFactory {
    private var lignes = listOf<Ligne>()

    override fun onCreate() {}
    override fun onDestroy() {}

    override fun onDataSetChanged() {
        val texte = contexte.getSharedPreferences("memo", Context.MODE_PRIVATE).getString("memo", null) ?: ""
        val l = mutableListOf<Ligne>()
        try {
            val rubriques = JSONArray(texte)
            for (i in 0 until rubriques.length()) {
                val r = rubriques.getJSONObject(i)
                if (!r.optBoolean("widget", true)) continue
                l.add(Ligne(true, r.optString("titre"), ""))
                val liens = r.optJSONArray("liens") ?: JSONArray()
                for (j in 0 until liens.length()) {
                    val e = liens.getJSONObject(j)
                    l.add(Ligne(false, e.optString("nom"), e.optString("adresse")))
                }
            }
        } catch (e: Exception) {
            // Pas encore de mémo : l'application l'écrit à sa première ouverture.
        }
        lignes = l
    }

    override fun getCount() = lignes.size
    override fun getViewTypeCount() = 2
    override fun getItemId(position: Int) = position.toLong()
    override fun hasStableIds() = false
    override fun getLoadingView(): RemoteViews? = null

    override fun getViewAt(position: Int): RemoteViews {
        val e = lignes[position]
        if (e.rubrique) {
            return RemoteViews(contexte.packageName, R.layout.memo_rubrique).apply { setTextViewText(R.id.texte, e.nom) }
        }
        return RemoteViews(contexte.packageName, R.layout.memo_lien).apply {
            setTextViewText(R.id.nom, e.nom)
            setTextViewText(R.id.adresse, e.adresse)
            if (e.adresse.startsWith("http")) {
                setOnClickFillInIntent(R.id.nom, Intent().setData(Uri.parse(e.adresse)))
                setOnClickFillInIntent(R.id.adresse, Intent().setData(Uri.parse(e.adresse)))
            }
        }
    }
}
