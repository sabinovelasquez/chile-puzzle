package com.pairip.licensecheck

import android.content.ContentProvider
import android.content.ContentValues
import android.database.Cursor
import android.net.Uri

/**
 * Stub provider to satisfy Google Play App Integrity's injected manifest entry.
 * Play Store injects com.pairip.licensecheck.LicenseContentProvider into the package
 * manager, but debug builds don't include the actual library — causing a ClassNotFoundException.
 */
class LicenseContentProvider : ContentProvider() {
    override fun onCreate(): Boolean = true
    override fun query(uri: Uri, proj: Array<String>?, sel: String?, args: Array<String>?, sort: String?): Cursor? = null
    override fun getType(uri: Uri): String? = null
    override fun insert(uri: Uri, values: ContentValues?): Uri? = null
    override fun delete(uri: Uri, sel: String?, args: Array<String>?): Int = 0
    override fun update(uri: Uri, values: ContentValues?, sel: String?, args: Array<String>?): Int = 0
}
