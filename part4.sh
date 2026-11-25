cat << 'EOF' >> app/src/main/java/com/example/xboxmanager/MainActivity.kt
        wv.settings.javaScriptEnabled = true; wv.settings.domStorageEnabled = true; wv.webViewClient = WebViewClient()
        wv.setDownloadListener { url, ua, cd, mime, _ ->
            val name = URLUtil.guessFileName(url, cd, mime)
            val dest = File(getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS), name)
            val req = DownloadManager.Request(Uri.parse(url)).setMimeType(mime).addRequestHeader("User-Agent", ua).setTitle(name).setNotificationVisibility(1).setDestinationUri(Uri.fromFile(dest))
            val id = (getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager).enqueue(req)
            Toast.makeText(this, "Downloading: $name", Toast.LENGTH_SHORT).show()
            val rx = object : BroadcastReceiver() {
                override fun onReceive(c: Context?, i: Intent?) {
                    if (i?.getLongExtra(DownloadManager.EXTRA_DOWNLOAD_ID, -1) == id) { unregisterReceiver(this); askXbox(dest.absolutePath, false) }
                }
            }
            ContextCompat.registerReceiver(this, rx, IntentFilter(DownloadManager.ACTION_DOWNLOAD_COMPLETE), ContextCompat.RECEIVER_NOT_EXPORTED)
        }

        if (DEFAULT_HOME_URL.isNotEmpty()) { urlIn.setText(DEFAULT_HOME_URL); wv.loadUrl(DEFAULT_HOME_URL) }
        go.setOnClickListener { var u = urlIn.text.toString().trim(); if (u.isNotEmpty()) { if (!u.startsWith("http")) u = "https://$u"; wv.loadUrl(u) } }
        dots.setOnClickListener { v ->
            PopupMenu(this, v).apply {
                menu.add(0, 1, 0, "1. Homebrew (/Hdd1/Homebrew)")
                menu.add(0, 2, 1, "2. Games (/Hdd1/Content/0000000000000000)")
                setOnMenuItemClickListener {
                    if (it.itemId == 1) { rPath = "/Hdd1/Homebrew"; badge.text = "HOMEBREW" }
                    else { rPath = "/Hdd1/Content/0000000000000000"; badge.text = "GAMES (GOD)" }
                    true
                }
                show()
            }
        }
        fBtn.setOnClickListener { AlertDialog.Builder(this).setTitle("Send File").setItems(arrayOf("Select File", "Select Folder")) { _, w -> if (w == 0) fPick.launch("*/*") else dPick.launch(null) }.show() }
        rBtn.setOnClickListener {
            val l = cm.getConsoles(); if (l.isEmpty()) { Toast.makeText(this, "Add Xbox first!", Toast.LENGTH_SHORT).show(); return@setOnClickListener }
            AlertDialog.Builder(this).setTitle("Console").setItems(l.map { "${it.name} (${it.ip})" }.toTypedArray()) { _, w ->
                val c = l[w]; val codes = arrayOf("dashboard", "reboot", "shutdown", "opendvd")
                AlertDialog.Builder(this).setTitle(c.name).setItems(arrayOf("🏠 Reload Dashboard", "🔄 Cold Reboot", "⏻ Shutdown", "💿 Eject DVD")) { _, i ->
                    lifecycleScope.launch { Toast.makeText(this@MainActivity, rc.sendXbdmCommand(c, codes[i]).getOrElse { it.message }, Toast.LENGTH_LONG).show() }
                }.show()
            }.show()
        }
        aBtn.setOnClickListener { addDlg(null) }
    }

    private fun btn(t: String, c: String) = Button(this).apply { text = t; textSize = 12f; setTextColor(Color.WHITE); setBackgroundColor(Color.parseColor(c)); layoutParams = LinearLayout.LayoutParams(0, 105, 1f).apply { marginStart = 6; marginEnd = 6 } }
    private fun cpUri(u: Uri) = lifecycleScope.launch(Dispatchers.IO) { val f = File(cacheDir, DocumentFile.fromSingleUri(this@MainActivity, u)?.name ?: "file.zip"); contentResolver.openInputStream(u)?.use { i -> f.outputStream().use { o -> i.copyTo(o) } }; withContext(Dispatchers.Main) { askXbox(f.absolutePath, true) } }
    private fun cpTree(u: Uri) = lifecycleScope.launch(Dispatchers.IO) { val r = DocumentFile.fromTreeUri(this@MainActivity, u) ?: return@launch; val d = File(cacheDir, r.name ?: "Game").apply { deleteRecursively(); mkdirs() }; cpRec(r, d); withContext(Dispatchers.Main) { askXbox(d.absolutePath, true) } }
    private fun cpRec(doc: DocumentFile, t: File) = doc.listFiles().forEach { if (it.isDirectory) cpRec(it, File(t, it.name ?: "s").apply { mkdirs() }) else if (it.isFile) contentResolver.openInputStream(it.uri)?.use { i -> File(t, it.name ?: "f").outputStream().use { o -> i.copyTo(o) } } }
    private fun askXbox(p: String, del: Boolean) { val l = cm.getConsoles(); if (l.isEmpty()) { addDlg { send(p, it, del) }; return }; AlertDialog.Builder(this).setTitle("Send to [$rPath]").setItems(l.map { "${it.name} (${it.ip})" }.toTypedArray()) { _, w -> send(p, l[w], del) }.setPositiveButton("+ New") { _, _ -> addDlg { send(p, it, del) } }.show() }
    private fun addDlg(cb: ((XboxConsole) -> Unit)?) {
        val lay = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; setPadding(48, 24, 48, 12) }
        val n = EditText(this).apply { hint = "Name" }; val ip = EditText(this).apply { hint = "IP (192.168.1.50)" }; val u = EditText(this).apply { setText("xboxftp") }; val p = EditText(this).apply { setText("xboxftp") }
        lay.addView(n); lay.addView(ip); lay.addView(u); lay.addView(p)
        AlertDialog.Builder(this).setTitle("Add Xbox 360").setView(lay).setPositiveButton("Save") { _, _ -> val c = XboxConsole(name = n.text.toString().ifBlank { "Xbox 360" }, ip = ip.text.toString().trim(), user = u.text.toString(), pass = p.text.toString()); if (c.ip.isNotEmpty()) { cm.addConsole(c); cb?.invoke(c) } }.show()
    }
    private fun send(p: String, c: XboxConsole, del: Boolean) {
        val d = workDataOf("FILE_PATH" to p, "XBOX_IP" to c.ip, "XBOX_PORT" to c.ftpPort, "FTP_USER" to c.user, "FTP_PASS" to c.pass, "REMOTE_DIR" to rPath, "DELETE_SOURCE" to del)
        WorkManager.getInstance(this).enqueue(OneTimeWorkRequestBuilder<FtpUploadWorker>().setInputData(d).setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.UNMETERED).build()).build())
        Toast.makeText(this, "Uploading in background...", Toast.LENGTH_LONG).show()
    }
    @Deprecated("Deprecated in Java") override fun onBackPressed() { if (wv.canGoBack()) wv.goBack() else super.onBackPressed() }
}
EOF
