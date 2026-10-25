package com.example.kroscek

import java.net.URI

object ReleaseSourcePolicy {
    private val releasePath = Regex(
        "/lemuranonim/KrosCekApps/releases/download/v[0-9][0-9A-Za-z._+\\-]*/app-release\\.apk",
    )

    fun isTrusted(url: String): Boolean = runCatching {
        val uri = URI(url)
        uri.scheme == "https" && uri.host.equals("github.com", ignoreCase = true) &&
            uri.userInfo == null && (uri.port == -1 || uri.port == 443) &&
            uri.rawQuery == null && uri.rawFragment == null &&
            !url.contains('%') && releasePath.matches(uri.rawPath ?: "")
    }.getOrDefault(false)
}
