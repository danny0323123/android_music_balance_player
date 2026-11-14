package com.musicbalance.balance_native

import android.content.ContentProvider
import android.content.ContentValues
import android.database.Cursor
import android.net.Uri
import android.os.ParcelFileDescriptor
import java.io.FileNotFoundException

/**
 * 提供專輯封面給 Android Auto。Auto 在別的程序裡，讀不到 app 的快取檔案，
 * 也沒有讀取音樂的權限，所以由這裡把封面開給它。
 *
 * 網址格式：content://<applicationId>.art/<albumId>/<songId>
 */
class ArtProvider : ContentProvider() {
    override fun onCreate() = true

    override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor {
        val segments = uri.pathSegments
        val albumId = segments.getOrNull(0)?.toLongOrNull()
        val songId = segments.getOrNull(1)?.toLongOrNull()
        if (albumId == null || songId == null || mode != "r") throw FileNotFoundException(uri.toString())
        val file = AlbumArt.file(context!!, albumId, songId) ?: throw FileNotFoundException(uri.toString())
        return ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
    }

    override fun getType(uri: Uri) = "image/jpeg"

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        selection: String?,
        selectionArgs: Array<out String>?,
        sortOrder: String?,
    ): Cursor? = null

    override fun insert(uri: Uri, values: ContentValues?): Uri? = null

    override fun update(
        uri: Uri,
        values: ContentValues?,
        selection: String?,
        selectionArgs: Array<out String>?,
    ) = 0

    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?) = 0
}
