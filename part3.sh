cat << 'EOF' > app/src/main/java/com/example/xboxmanager/MainActivity.kt
package com.example.xboxmanager
import android.Manifest; import android.animation.*; import android.app.*; import android.content.*
import android.content.pm.PackageManager; import android.graphics.Color; import android.graphics.drawable.GradientDrawable
import android.net.Uri; import android.os.*; import android.text.InputType; import android.view.*; import android.webkit.*
import android.widget.*; import androidx.activity.ComponentActivity; import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat; import androidx.documentfile.provider.DocumentFile
import androidx.lifecycle.lifecycleScope; import androidx.work.*; import kotlinx.coroutines.*; import java.io.File

class MainActivity : ComponentActivity() {
    companion object { const val DEFAULT_HOME_URL = "" }
    private lateinit var cm: ConsoleManager; private val rc = XboxRemoteController(); private lateinit var wv: WebView; private lateinit var badge: TextView
    private var rPath = "/Hdd1/Homebrew"
    private val fPick = registerForActivityResult(ActivityResultContracts.GetContent()) { u -> if (u != null) cpUri(u) }
    private val dPick = registerForActivityResult(ActivityResultContracts.OpenDocumentTree()) { u -> if (u != null) cpTree(u) }
    private val pReq = registerForActivityResult(ActivityResultContracts.RequestPermission()) {}

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= 33 && ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) pReq.launch(Manifest.permission.POST_NOTIFICATIONS)
        cm = ConsoleManager(this)
        val root = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; layoutParams = ViewGroup.LayoutParams(-1, -1) }
        val grad = GradientDrawable(GradientDrawable.Orientation.TL_BR, intArrayOf(Color.parseColor("#0D1F12"), Color.parseColor("#107C10")))
        root.background = grad
        ValueAnimator.ofObject(ArgbEvaluator(), Color.parseColor("#107C10"), Color.parseColor("#0A290D"), Color.parseColor("#1DB954")).apply { duration = 4000; repeatCount = -1; repeatMode = ValueAnimator.REVERSE; addUpdateListener { grad.colors = intArrayOf(Color.parseColor("#0A0A0A"), it.animatedValue as Int) }; start() }

        val top = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL; gravity = Gravity.CENTER_VERTICAL; setPadding(16, 16, 16, 8); setBackgroundColor(Color.parseColor("#CC121212")) }
        val urlIn = EditText(this).apply { hint = "Enter URL..."; setTextColor(Color.WHITE); setHintTextColor(Color.GRAY); setBackgroundColor(Color.parseColor("#262626")); setPadding(24, 18, 24, 18); inputType = InputType.TYPE_TEXT_VARIATION_URI; isSingleLine = true; layoutParams = LinearLayout.LayoutParams(0, -2, 1f) }
        val go = Button(this).apply { text = "GO"; setTextColor(Color.WHITE); setBackgroundColor(Color.parseColor("#107C10")); layoutParams = LinearLayout.LayoutParams(-2, -2).apply { marginStart = 12 } }
        val dots = Button(this).apply { text = "⋮"; textSize = 18f; setTextColor(Color.WHITE); setBackgroundColor(Color.parseColor("#262626")); layoutParams = LinearLayout.LayoutParams(120, -2).apply { marginStart = 8 } }
        top.addView(urlIn); top.addView(go); top.addView(dots)

        val act = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL; gravity = Gravity.CENTER_VERTICAL; setPadding(16, 8, 16, 16); setBackgroundColor(Color.parseColor("#CC121212")) }
        badge = TextView(this).apply { text = "HOMEBREW"; setTextColor(Color.parseColor("#4CAF50")); textSize = 12f; setPadding(0, 0, 16, 0) }
        val fBtn = btn("📂 File", "#262626"); val rBtn = btn("🎮 Remote", "#262626"); val aBtn = btn("+ Xbox", "#107C10")
        act.addView(badge); act.addView(fBtn); act.addView(rBtn); act.addView(aBtn)

        wv = WebView(this).apply { setBackgroundColor(Color.parseColor("#121212")); layoutParams = LinearLayout.LayoutParams(-1, 0, 1f) }
        root.addView(top); root.addView(act); root.addView(wv); setContentView(root)
EOF
bash part4.sh
