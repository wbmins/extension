package eu.kanade.tachiyomi.extension.all.ehentai

import android.app.Application
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import uy.kohesive.injekt.Injekt
import uy.kohesive.injekt.api.get
import java.io.File
import java.util.Locale

object ETagTranslations {
    private const val DB_NAME = "etag.db"
    private const val EXTENSION_PACKAGE = "eu.kanade.tachiyomi.extension.all.ehentai"

    private val cache = mutableMapOf<Pair<String, String>, String?>()

    private val database: SQLiteDatabase by lazy {
        SQLiteDatabase.openDatabase(databaseFile().path, null, SQLiteDatabase.OPEN_READONLY)
    }

    fun translate(tags: Map<String, List<Tag>>): Map<Pair<String, String>, String> = runCatching {
        val keys = tags.flatMap { (namespace, tags) ->
            tags.map { tag -> namespace.toTranslationKey() to tag.name.toTranslationKey() }
        }.distinct()

        val missingKeys = synchronized(cache) {
            keys.filterNot(cache::containsKey)
        }

        if (missingKeys.isNotEmpty()) {
            val queriedTranslations = queryTranslations(missingKeys)
            synchronized(cache) {
                missingKeys.forEach { key ->
                    cache[key] = queriedTranslations[key]
                }
            }
        }

        synchronized(cache) {
            keys.mapNotNull { key ->
                cache[key]?.let { translation -> key to translation }
            }.toMap()
        }
    }.getOrDefault(emptyMap())

    private fun queryTranslations(keys: List<Pair<String, String>>): Map<Pair<String, String>, String> {
        val translations = mutableMapOf<Pair<String, String>, String>()
        val clauses = mutableListOf<String>()
        val args = mutableListOf<String>()

        fun flushQuery() {
            if (clauses.isEmpty()) return

            database.rawQuery(
                "SELECT namespace, en, zh FROM tags WHERE ${clauses.joinToString(" OR ")}",
                args.toTypedArray(),
            ).use { cursor ->
                while (cursor.moveToNext()) {
                    val namespace = cursor.getString(0).toTranslationKey()
                    val tag = cursor.getString(1).toTranslationKey()
                    val translation = cursor.getString(2)?.takeIf(String::isNotBlank)
                    if (translation != null) {
                        translations[namespace to tag] = translation
                    }
                }
            }

            clauses.clear()
            args.clear()
        }

        keys.groupBy({ it.first }, { it.second }).forEach { (namespace, tags) ->
            tags.distinct().chunked(SQLITE_MAX_VARIABLE_NUMBER - 1).forEach { chunk ->
                if (args.size + chunk.size + 1 > SQLITE_MAX_VARIABLE_NUMBER) {
                    flushQuery()
                }

                val placeholders = chunk.joinToString(",") { "?" }
                clauses += "(namespace = ? AND en IN ($placeholders))"
                args += namespace
                args += chunk
            }
        }

        flushQuery()

        return translations
    }

    private fun databaseFile(): File {
        val application = Injekt.get<Application>()
        val target = File(application.cacheDir, DB_NAME)
        val temp = File(application.cacheDir, "$DB_NAME.tmp")
        val extensionContext = application.createPackageContext(
            EXTENSION_PACKAGE,
            Context.CONTEXT_IGNORE_SECURITY,
        )

        extensionContext.assets.open(DB_NAME).use { input ->
            temp.outputStream().use { output ->
                input.copyTo(output)
            }
        }

        if (!target.exists() || target.length() != temp.length()) {
            if (target.exists()) {
                target.delete()
            }
            if (!temp.renameTo(target)) {
                temp.copyTo(target, overwrite = true)
                temp.delete()
            }
        } else {
            temp.delete()
        }

        return target
    }

    private fun String.toTranslationKey() = trim().lowercase(Locale.US)

    private const val SQLITE_MAX_VARIABLE_NUMBER = 999
}
