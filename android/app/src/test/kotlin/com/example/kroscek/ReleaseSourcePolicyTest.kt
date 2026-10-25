package com.example.kroscek

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ReleaseSourcePolicyTest {
    @Test
    fun acceptsOnlyOfficialReleaseArtifacts() {
        assertTrue(ReleaseSourcePolicy.isTrusted(
            "https://github.com/lemuranonim/KrosCekApps/releases/download/v4.9.9/app-release.apk",
        ))
        for (url in listOf(
            "http://github.com/lemuranonim/KrosCekApps/releases/download/v4/app-release.apk",
            "https://github.com.attacker.test/lemuranonim/KrosCekApps/releases/download/v4/app-release.apk",
            "https://github.com/attacker/KrosCekApps/releases/download/v4/app-release.apk",
            "https://attacker@github.com/lemuranonim/KrosCekApps/releases/download/v4/app-release.apk",
            "https://github.com:444/lemuranonim/KrosCekApps/releases/download/v4/app-release.apk",
            "https://github.com/lemuranonim/KrosCekApps/releases/download/v4/app-release.apk?redirect=evil",
            "https://github.com/lemuranonim/KrosCekApps/releases/download/v4/%61pp-release.apk",
        )) assertFalse(url, ReleaseSourcePolicy.isTrusted(url))
    }
}
