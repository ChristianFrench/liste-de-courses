package fr.listecourses.liste_de_courses

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

// Notifications du foyer par Firebase (06/11/2026, Aristide) : le serveur ntfy d'Emplettes (ntfy.<domaine>)
// publie chaque message aussi sur le sujet Firebase du même nom ; le téléphone s'y abonne (MainActivity,
// canal « fr.listecourses/notifications ») et ce service l'affiche, même application fermée, sans l'appli ntfy.
// Copié dans le projet Android par outils/preparer.py.
class NotificationsEmplettes : FirebaseMessagingService() {
    override fun onMessageReceived(message: RemoteMessage) {
        val d = message.data
        // ntfy envoie aussi des « keepalive » et des « poll_request » : seuls les messages s'affichent.
        if ((d["event"] ?: "message") != "message") return
        val texte = d["message"] ?: message.notification?.body ?: return
        val titre = d["title"]?.takeIf { it.isNotEmpty() } ?: message.notification?.title ?: "Emplettes"
        afficher(this, titre, texte, (d["id"] ?: texte).hashCode())
    }

    override fun onNewToken(token: String) {
        // Rien à faire : les abonnements aux sujets suivent le jeton tout seuls.
    }

    companion object {
        const val CANAL = "messages-foyer"

        fun afficher(context: Context, titre: String, texte: String, id: Int) {
            val gestion = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (Build.VERSION.SDK_INT >= 26 && gestion.getNotificationChannel(CANAL) == null) {
                gestion.createNotificationChannel(
                    NotificationChannel(CANAL, "Messages du foyer", NotificationManager.IMPORTANCE_HIGH)
                )
            }
            val ouvrir = PendingIntent.getActivity(
                context, 0,
                Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            val n = NotificationCompat.Builder(context, CANAL)
                .setSmallIcon(R.drawable.ic_notification)
                .setColor(0xFF3F7D5A.toInt())
                .setContentTitle(titre)
                .setContentText(texte)
                .setStyle(NotificationCompat.BigTextStyle().bigText(texte))
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setAutoCancel(true)
                .setContentIntent(ouvrir)
                .build()
            try {
                NotificationManagerCompat.from(context).notify(id, n)
            } catch (e: SecurityException) {
                // Notifications refusées par l'utilisateur : rien à afficher.
            }
        }
    }
}
