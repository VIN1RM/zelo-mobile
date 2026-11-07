package br.com.zelo.zelo_mobile

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.AtomicFile
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.security.KeyStore
import java.util.UUID
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** Durable encrypted handoff. Events are acknowledged only after a SQLite commit. */
object OperationalJournal {
    private const val ALIAS = "zelo.operational.v1"
    private fun key(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (store.getKey(ALIAS, null) as? SecretKey)?.let { return it }
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        generator.init(KeyGenParameterSpec.Builder(ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build())
        return generator.generateKey()
    }
    private fun file(context: Context) = AtomicFile(File(context.noBackupFilesDir, "operational.v1.enc"))
    @Synchronized fun read(context: Context): JSONObject {
        val file = file(context)
        if (!file.baseFile.exists() && !File(file.baseFile.path+".bak").exists() && !File(file.baseFile.path+".new").exists()) return JSONObject().put("events", JSONArray())
        val bytes = file.openRead().use { it.readBytes() }
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, bytes.copyOfRange(0, 12)))
        return JSONObject(String(cipher.doFinal(bytes.copyOfRange(12, bytes.size)), Charsets.UTF_8))
    }
    @Synchronized fun write(context: Context, data: JSONObject) {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key())
        val bytes = cipher.iv + cipher.doFinal(data.toString().toByteArray(Charsets.UTF_8))
        val file = file(context)
        val output = file.startWrite()
        try { output.write(bytes); file.finishWrite(output) }
        catch (error: Exception) { file.failWrite(output); throw error }
    }
    fun alert(data:JSONObject,uid:String):JSONObject? {
        val owned=data.optJSONObject("alerts")?.optJSONObject(uid)
        if(owned!=null) return owned
        return data.optJSONObject("alert")?.takeIf { it.optString("userId")==uid }
    }
    fun putAlert(data:JSONObject,uid:String,alert:JSONObject) {
        check(alert.optString("userId")==uid)
        val alerts=data.optJSONObject("alerts") ?: JSONObject().also { data.put("alerts",it) }
        alerts.put(uid,alert)
        if(data.optJSONObject("alert")?.optString("userId")==uid) data.remove("alert")
    }
    fun removeAlert(data:JSONObject,uid:String) {
        data.optJSONObject("alerts")?.remove(uid)
        if(data.optJSONObject("alert")?.optString("userId")==uid) data.remove("alert")
    }
    fun event(data: JSONObject, uid: String, type: String, payload: JSONObject) {
        val events = data.optJSONArray("events") ?: JSONArray().also { data.put("events", it) }
        check(events.length() < 10000) { "Operational journal capacity reached" }
        events.put(JSONObject().put("id", UUID.randomUUID().toString()).put("userId", uid)
            .put("type", type).put("data", JSONObject(payload.toString())).put("at", System.currentTimeMillis()))
    }
    @Synchronized fun acknowledge(context: Context, uid: String, ids: Set<String>) {
        val data = read(context)
        val retained = JSONArray()
        val events = data.optJSONArray("events") ?: JSONArray()
        for (i in 0 until events.length()) {
            val event = events.getJSONObject(i)
            if (event.optString("userId") != uid || !ids.contains(event.optString("id"))) retained.put(event)
        }
        data.put("events", retained); write(context, data)
    }
    @Synchronized fun clear(context: Context, uid: String) {
        val data = read(context)
        val ids = mutableSetOf<String>()
        val events = data.optJSONArray("events") ?: JSONArray()
        for (i in 0 until events.length()) if (events.getJSONObject(i).optString("userId") == uid) ids.add(events.getJSONObject(i).getString("id"))
        acknowledge(context, uid, ids)
        val latest = read(context)
        for (name in listOf("session", "alert")) if (latest.optJSONObject(name)?.optString("userId") == uid) latest.remove(name)
        removeAlert(latest,uid)
        write(context, latest)
    }
}
