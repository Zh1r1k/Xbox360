cat << 'EOF' > app/src/main/java/com/example/xboxmanager/ConsoleManager.kt
package com.example.xboxmanager
import android.content.Context; import com.google.gson.Gson; import com.google.gson.reflect.TypeToken
data class XboxConsole(val id: String = System.currentTimeMillis().toString(), val name: String, val ip: String, val ftpPort: Int = 21, val user: String = "xboxftp", val pass: String = "xboxftp")
class ConsoleManager(context: Context) {
    private val prefs = context.getSharedPreferences("xbox_consoles_prefs", Context.MODE_PRIVATE); private val gson = Gson()
    fun getConsoles(): MutableList<XboxConsole> = prefs.getString("consoles_list", null)?.let { gson.fromJson(it, object : TypeToken<MutableList<XboxConsole>>() {}.type) } ?: mutableListOf()
    fun addConsole(c: XboxConsole) { val l = getConsoles(); l.add(c); prefs.edit().putString("consoles_list", gson.toJson(l)).apply() }
}
EOF

cat << 'EOF' > app/src/main/java/com/example/xboxmanager/XboxRemoteController.kt
package com.example.xboxmanager
import kotlinx.coroutines.Dispatchers; import kotlinx.coroutines.withContext; import java.io.*; import java.net.*
class XboxRemoteController {
    suspend fun sendXbdmCommand(c: XboxConsole, act: String): Result<String> = withContext(Dispatchers.IO) {
        val s = Socket()
        try {
            s.connect(InetSocketAddress(c.ip, 730), 5000)
            val r = BufferedReader(InputStreamReader(s.getInputStream())); val w = PrintWriter(s.getOutputStream(), true)
            if (r.readLine()?.startsWith("201") != true) return@withContext Result.failure(Exception("XBDM rejected"))
            val cmd = when (act) { "reboot" -> "magicboot cold"; "dashboard" -> "magicboot"; "shutdown" -> "shutdown"; "opendvd" -> "dvdeject"; else -> act }
            w.print("$cmd\r\n"); w.flush(); Result.success("OK: ${r.readLine() ?: "Sent"}")
        } catch (e: Exception) { Result.failure(Exception("No XBDM (${c.ip}:730)")) } finally { try { s.close() } catch (_: Exception) {} }
    }
}
EOF

cat << 'EOF' > app/src/main/java/com/example/xboxmanager/FtpUploadWorker.kt
package com.example.xboxmanager
import android.app.*; import android.content.Context; import android.content.pm.ServiceInfo; import android.os.Build
import androidx.core.app.NotificationCompat; import androidx.work.*; import org.apache.commons.net.ftp.*
import java.io.*; import java.util.zip.ZipInputStream
class FtpUploadWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {
    private val chId = "xbox_ftp"
    override suspend fun doWork(): Result {
        val path = inputData.getString("FILE_PATH") ?: return Result.failure()
        val host = inputData.getString("XBOX_IP") ?: return Result.failure()
        val dir = inputData.getString("REMOTE_DIR") ?: "/Hdd1/Homebrew"
        val src = File(path); if (!src.exists()) return Result.failure()
        if (Build.VERSION.SDK_INT >= 26) (applicationContext.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).createNotificationChannel(NotificationChannel(chId, "Xbox FTP", NotificationManager.IMPORTANCE_LOW))
        setForeground(mkInfo("Extracting...", 0))
        val workDir = if (src.extension.equals("zip", true)) File(applicationContext.cacheDir, src.nameWithoutExtension).also { unzip(src, it) } else src
        val total = sizeOf(workDir); var sent = 0L; val ftp = FTPClient()
        return try {
            ftp.connectTimeout = 15000; ftp.connect(host, inputData.getInt("XBOX_PORT", 21))
            if (!ftp.login(inputData.getString("FTP_USER") ?: "xboxftp", inputData.getString("FTP_PASS") ?: "xboxftp")) return Result.failure()
            ftp.setFileType(FTP.BINARY_FILE_TYPE); ftp.enterLocalPassiveMode(); ftp.makeDirectory(dir)
            upRec(ftp, workDir, "$dir/${workDir.name}") { b, n -> sent += b; setForegroundAsync(mkInfo("$n (${if (total > 0) (sent * 100 / total).toInt() else 0}%)", if (total > 0) (sent * 100 / total).toInt() else 0)) }
            ftp.logout(); if (workDir != src) workDir.deleteRecursively(); if (inputData.getBoolean("DELETE_SOURCE", false)) src.deleteRecursively()
            done("Completed! ${workDir.name} sent."); Result.success()
        } catch (e: Exception) { done("Error: ${e.localizedMessage}"); Result.failure() } finally { if (ftp.isConnected) try { ftp.disconnect() } catch (_: Exception) {} }
    }
    private fun upRec(ftp: FTPClient, f: File, rem: String, cb: (Long, String) -> Unit) {
        if (f.isDirectory) { ftp.makeDirectory(rem); f.listFiles()?.forEach { upRec(ftp, it, "$rem/${it.name}", cb) } }
        else FileInputStream(f).use { fis -> ftp.storeFileStream(rem)?.use { out -> val buf = ByteArray(16384); var r: Int; while (fis.read(buf).also { r = it } != -1) { out.write(buf, 0, r); cb(r.toLong(), f.name) }; out.flush() }; ftp.completePendingCommand() }
    }
    private fun unzip(z: File, d: File) { d.deleteRecursively(); d.mkdirs(); ZipInputStream(FileInputStream(z)).use { s -> var e = s.nextEntry; while (e != null) { val f = File(d, e.name); if (e.isDirectory) f.mkdirs() else { f.parentFile?.mkdirs(); f.outputStream().use { s.copyTo(it) } }; e = s.nextEntry } } }
    private fun sizeOf(f: File): Long = if (f.isFile) f.length() else f.listFiles()?.sumOf { sizeOf(it) } ?: 0L
    private fun mkInfo(t: String, p: Int): ForegroundInfo {
        val n = NotificationCompat.Builder(applicationContext, chId).setContentTitle("Xbox FTP").setContentText(t).setSmallIcon(android.R.drawable.stat_sys_upload).setOngoing(true).setProgress(100, p, false).build()
        return if (Build.VERSION.SDK_INT >= 29) ForegroundInfo(1001, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC) else ForegroundInfo(1001, n)
    }
    private fun done(m: String) { (applicationContext.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).notify(1002, NotificationCompat.Builder(applicationContext, chId).setContentTitle("Xbox FTP").setContentText(m).setSmallIcon(android.R.drawable.stat_sys_upload_done).build()) }
}
EOF
