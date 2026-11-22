package com.hivenet.hivenet

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.content.Context
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import org.json.JSONArray
import org.json.JSONObject
import java.io.*
import java.net.ServerSocket
import java.net.Socket
import java.net.URLDecoder
import java.security.MessageDigest
import java.security.KeyFactory
import java.security.Signature
import java.security.spec.X509EncodedKeySpec
import android.util.Base64
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/** A small dependency-free HTTP server. It owns the on-device replica files. */
class HiveNodeService : Service() {
    companion object {
        private const val transferKey = "incomingTransfers"

        /** A small persisted event feed for Flutter. No event is invented: each
         * transition is written from the HTTP receiver while it handles bytes. */
        fun incomingTransfers(context: Context): List<Map<String, Any?>> {
            val raw = context.getSharedPreferences("hivenet", Context.MODE_PRIVATE)
                .getString(transferKey, "[]") ?: "[]"
            return try {
                val array = JSONArray(raw)
                (0 until array.length()).map { index ->
                    val item = array.getJSONObject(index)
                    mapOf<String, Any?>(
                        "id" to item.optString("id"),
                        "sender" to item.optString("sender", "Unknown device"),
                        "originalName" to item.optString("originalName", "image.jpg"),
                        "storedName" to item.optString("storedName", "encryptedImage"),
                        "receivedBytes" to item.optLong("receivedBytes"),
                        "totalBytes" to item.optLong("totalBytes"),
                        "stage" to item.optString("stage", "Incoming"),
                        "updatedAt" to item.optLong("updatedAt"),
                        "error" to item.optString("error").takeIf { it.isNotEmpty() },
                    )
                }
            } catch (_: Exception) { emptyList() }
        }
        fun startPairing(context: Context, owner: Map<String, Any?>): Map<String, Any?> {
            val token = Base64.encodeToString(ByteArray(24).also { java.security.SecureRandom().nextBytes(it) }, Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING)
            val session = JSONObject(owner).put("token", token).put("expiresAt", System.currentTimeMillis() + 5 * 60 * 1000L).put("state", "waiting")
            context.getSharedPreferences("hivenet", Context.MODE_PRIVATE).edit().putString("pairSession", session.toString()).apply()
            return mapOf("token" to token, "expiresAt" to session.getLong("expiresAt"))
        }
        fun pairingRequests(context: Context): List<Map<String, Any?>> {
            val session = session(context) ?: return emptyList()
            val pending = session.optJSONObject("pending") ?: return emptyList()
            return listOf(mapOf("deviceId" to pending.optString("deviceId"), "deviceName" to pending.optString("deviceName"), "ownerName" to pending.optString("ownerName"), "publicKey" to pending.optString("publicKey")))
        }
        fun approvePairing(context: Context, deviceId: String): Boolean {
            val session = session(context) ?: return false
            val pending = session.optJSONObject("pending") ?: return false
            if (pending.optString("deviceId") != deviceId || expired(session)) return false
            session.put("state", "approved").put("approvedDeviceId", deviceId).put("used", true)
            context.getSharedPreferences("hivenet", Context.MODE_PRIVATE).edit().putString("pairSession", session.toString()).apply()
            return true
        }
        private fun session(context: Context): JSONObject? = try { JSONObject(context.getSharedPreferences("hivenet", Context.MODE_PRIVATE).getString("pairSession", null) ?: return null) } catch (_: Exception) { null }
        private fun expired(session: JSONObject) = System.currentTimeMillis() > session.optLong("expiresAt")
    }
    private val port = 8765
    @Volatile private var running = false
    private var server: ServerSocket? = null
    // Accepting a connection must happen once in the server thread.  The prior
    // implementation submitted accept() itself to an unbounded pool, creating
    // thousands of blocking threads and crashing the app with OOM.
    private val workers: ExecutorService = Executors.newFixedThreadPool(4)
    private var nodeId = ""
    private lateinit var root: File

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val prefs = getSharedPreferences("hivenet", MODE_PRIVATE)
        nodeId = intent?.getStringExtra("nodeId") ?: prefs.getString("nodeId", nodeId) ?: "unknown"
        prefs.edit().putString("nodeId", nodeId).apply()
        root = File(filesDir, "hivenet").also { it.mkdirs() }
        if (Build.VERSION.SDK_INT >= 26) {
            (getSystemService(NotificationManager::class.java)).createNotificationChannel(
                NotificationChannel("hivenet_node", "HiveNet node", NotificationManager.IMPORTANCE_LOW))
        }
        startForeground(41, notification())
        if (!running) {
            running = true
            Thread { serve() }.start()
        }
        return START_STICKY
    }

    private fun notification() = NotificationCompat.Builder(this, "hivenet_node")
        .setSmallIcon(android.R.drawable.stat_sys_upload)
        .setContentTitle("HiveNet node active")
        .setContentText("Accepting LAN replicas on port $port")
        .setOngoing(true).build()

    private fun serve() {
        try {
            server = ServerSocket(port, 16)
            while (running) {
                val socket = server?.accept() ?: break
                workers.execute { handle(socket) }
            }
        } catch (_: IOException) {
            // Expected when onDestroy closes the listening socket. A later
            // sticky-service restart will construct a fresh accept loop.
        }
    }

    private fun handle(socket: Socket) {
        socket.use { s ->
            try {
                s.soTimeout = 30000
                val input = BufferedInputStream(s.getInputStream())
                val output = BufferedOutputStream(s.getOutputStream())
                val request = readRequest(input) ?: return
                when {
                    request.method == "OPTIONS" -> corsPreflight(output)
                    request.method == "GET" && request.path == "/v1/info" -> info(output)
                    request.method == "POST" && request.path.startsWith("/v1/pair/") && request.path.endsWith("/request") -> pairRequest(input, output, request, request.path.removePrefix("/v1/pair/").removeSuffix("/request"))
                    request.method == "GET" && request.path.startsWith("/v1/pair/") && request.path.endsWith("/status") -> pairStatus(output, request, request.path.removePrefix("/v1/pair/").removeSuffix("/status"))
                    request.method == "GET" && request.path == "/v1/files" -> listFiles(output)
                    request.method == "GET" && request.path.startsWith("/v1/files/") && request.path.endsWith("/meta") -> meta(output, idFromPath(request.path))
                    request.method == "GET" && request.path.startsWith("/v1/files/") -> download(output, idFromPath(request.path))
                    request.method == "PUT" && request.path.startsWith("/v1/files/") -> put(input, output, request, idFromPath(request.path))
                    request.method == "DELETE" && request.path.startsWith("/v1/files/") -> delete(output, request, idFromPath(request.path))
                    else -> response(output, 404, "application/json", "{\"error\":\"not found\"}".toByteArray())
                }
            } catch (_: Exception) { }
        }
    }

    private data class Request(val method: String, val path: String, val headers: Map<String, String>)
    private fun readRequest(input: InputStream): Request? {
        val first = line(input) ?: return null
        val parts = first.split(" ")
        if (parts.size < 2) return null
        val headers = mutableMapOf<String, String>()
        while (true) {
            val h = line(input) ?: return null
            if (h.isEmpty()) break
            val at = h.indexOf(':'); if (at > 0) headers[h.substring(0, at).lowercase()] = h.substring(at + 1).trim()
        }
        return Request(parts[0], parts[1].substringBefore('?'), headers)
    }
    private fun line(input: InputStream): String? {
        val out = ByteArrayOutputStream(); var b: Int
        while (true) { b = input.read(); if (b < 0) return if (out.size() == 0) null else out.toString("UTF-8"); if (b == 10) break; if (b != 13) out.write(b); if (out.size() > 16384) return null }
        return out.toString("UTF-8")
    }

    private fun put(input: InputStream, out: OutputStream, r: Request, id: String) {
        if (!id.matches(Regex("[a-f0-9]{64}"))) return response(out, 400, "application/json", "{\"error\":\"invalid id\"}".toByteArray())
        val length = r.headers["content-length"]?.toLongOrNull() ?: return response(out, 411, "application/json", ByteArray(0))
        if (length < 1 || length > 50L * 1024 * 1024) return response(out, 413, "application/json", ByteArray(0))
        val expected = r.headers["x-hivenet-sha256"] ?: return response(out, 400, "application/json", ByteArray(0))
        val deleteHash = r.headers["x-hivenet-delete-token-hash"]
            ?: return response(out, 400, "application/json", "{\"error\":\"missing delete capability\"}".toByteArray())
        if (!deleteHash.matches(Regex("[a-f0-9]{64}"))) return response(out, 400, "application/json", ByteArray(0))
        val dir = File(root, "files").also { it.mkdirs() }
        val originalName = decodedHeader(r.headers["x-hivenet-name-b64"], r.headers["x-hivenet-name"] ?: "image.jpg")
        val sender = decodedHeader(r.headers["x-hivenet-sender-b64"], r.headers["x-hivenet-sender"] ?: "Unknown device")
        // The sender supplies a content-derived opaque name. It never contains
        // the gallery filename, and the receiver rejects unsafe filesystem names.
        val storedName = (r.headers["x-hivenet-stored-name"] ?: "encryptedImage_${id.take(12)}")
            .takeIf { it.matches(Regex("encryptedImage_[a-zA-Z0-9_-]{4,80}")) }
            ?: "encryptedImage_${id.take(12)}"
        val tmp = File(dir, "$storedName.part"); val digest = MessageDigest.getInstance("SHA-256")
        transfer(id, sender, originalName, storedName, 0, length, "Incoming")
        FileOutputStream(tmp).use { file ->
            var remaining = length; val buffer = ByteArray(32 * 1024)
            while (remaining > 0) {
                val count = input.read(buffer, 0, minOf(buffer.size.toLong(), remaining).toInt())
                if (count < 0) {
                    transfer(id, sender, originalName, storedName, length - remaining, length, "Failed", "Connection ended before all bytes arrived")
                    throw EOFException()
                }
                file.write(buffer, 0, count); digest.update(buffer, 0, count); remaining -= count
                transfer(id, sender, originalName, storedName, length - remaining, length, "Receiving")
            }
            file.fd.sync()
        }
        transfer(id, sender, originalName, storedName, length, length, "Verifying")
        val actual = digest.digest().joinToString("") { "%02x".format(it) }
        if (actual != expected.lowercase()) { tmp.delete(); transfer(id, sender, originalName, storedName, length, length, "Failed", "Checksum mismatch"); return response(out, 422, "application/json", "{\"error\":\"checksum mismatch\"}".toByteArray()) }
        val target = File(dir, "$storedName.bin"); if (!tmp.renameTo(target)) { tmp.copyTo(target, true); tmp.delete() }
        File(dir, "$id.json").writeText(JSONObject().put("id", id).put("name", originalName).put("storedName", storedName).put("mime", "application/octet-stream").put("sha256", actual).put("bytes", length).put("originalBytes", r.headers["x-hivenet-original-bytes"]?.toLongOrNull() ?: length).put("deleteTokenHash", deleteHash).put("createdAt", System.currentTimeMillis()).toString())
        transfer(id, sender, originalName, storedName, length, length, "Stored Successfully")
        response(out, 201, "application/json", JSONObject().put("stored", true).put("id", id).put("sha256", actual).toString().toByteArray())
    }
    private fun pairRequest(input: InputStream, out: OutputStream, r: Request, token: String) {
        val session = session(this) ?: return response(out, 404, "application/json", "{\"error\":\"no pairing session\"}".toByteArray())
        if (session.optString("token") != token || expired(session) || session.optBoolean("used")) return response(out, 410, "application/json", "{\"error\":\"pairing session expired\"}".toByteArray())
        val length = r.headers["content-length"]?.toIntOrNull() ?: return response(out, 411, "application/json", ByteArray(0))
        if (length !in 2..16384) return response(out, 413, "application/json", ByteArray(0))
        val bytes = input.readNBytes(length); val request = try { JSONObject(String(bytes, Charsets.UTF_8)) } catch (_: Exception) { return response(out, 400, "application/json", "{\"error\":\"invalid pairing request\"}".toByteArray()) }
        val deviceId = request.optString("deviceId"); val publicKey = request.optString("publicKey"); val proof = request.optString("proof")
        if (deviceId.isEmpty() || !verifyProof(publicKey, "$token|$deviceId", proof)) return response(out, 401, "application/json", "{\"error\":\"device proof rejected\"}".toByteArray())
        session.put("pending", request).put("state", "pending")
        getSharedPreferences("hivenet", MODE_PRIVATE).edit().putString("pairSession", session.toString()).apply()
        response(out, 202, "application/json", "{\"state\":\"pending_approval\"}".toByteArray())
    }
    private fun pairStatus(out: OutputStream, r: Request, token: String) {
        val session = session(this) ?: return response(out, 404, "application/json", "{\"error\":\"no pairing session\"}".toByteArray())
        if (session.optString("token") != token || expired(session)) return response(out, 410, "application/json", "{\"state\":\"expired\"}".toByteArray())
        val requestedId = r.headers["x-hivenet-device-id"] ?: ""
        if (session.optString("state") == "approved" && session.optString("approvedDeviceId") == requestedId) {
            val owner = JSONObject(session.toString())
            owner.remove("pending")
            owner.remove("token")
            response(out, 200, "application/json", JSONObject().put("state", "approved").put("owner", owner).toString().toByteArray())
        } else response(out, 200, "application/json", "{\"state\":\"${session.optString("state", "waiting")}\"}".toByteArray())
    }
    private fun verifyProof(publicKey: String, payload: String, proof: String): Boolean = try {
        val key = KeyFactory.getInstance("EC").generatePublic(X509EncodedKeySpec(Base64.decode(publicKey, Base64.NO_WRAP)))
        Signature.getInstance("SHA256withECDSA").run { initVerify(key); update(payload.toByteArray(Charsets.UTF_8)); verify(Base64.decode(proof, Base64.NO_WRAP)) }
    } catch (_: Exception) { false }
    private fun transfer(id: String, sender: String, originalName: String, storedName: String, receivedBytes: Long, totalBytes: Long, stage: String, error: String? = null) {
        val prefs = getSharedPreferences("hivenet", MODE_PRIVATE)
        val events = try { JSONArray(prefs.getString(transferKey, "[]")) } catch (_: Exception) { JSONArray() }
        val item = JSONObject().put("id", id).put("sender", sender).put("originalName", originalName).put("storedName", storedName).put("receivedBytes", receivedBytes).put("totalBytes", totalBytes).put("stage", stage).put("updatedAt", System.currentTimeMillis())
        if (error != null) item.put("error", error)
        var replaced = false
        for (index in 0 until events.length()) if (events.getJSONObject(index).optString("id") == id) { events.put(index, item); replaced = true; break }
        if (!replaced) events.put(item)
        while (events.length() > 12) events.remove(0)
        prefs.edit().putString(transferKey, events.toString()).apply()
    }
    private fun decodedHeader(encoded: String?, fallback: String): String = try {
        if (encoded == null) URLDecoder.decode(fallback, "UTF-8") else String(Base64.decode(encoded, Base64.URL_SAFE or Base64.NO_WRAP), Charsets.UTF_8)
    } catch (_: Exception) { fallback }
    private fun info(out: OutputStream) = response(out, 200, "application/json", JSONObject().put("nodeId", nodeId).put("port", port).put("freeBytes", root.usableSpace).put("totalBytes", root.totalSpace).toString().toByteArray())
    private fun listFiles(out: OutputStream) {
        val a = JSONArray(); File(root, "files").listFiles { f -> f.extension == "json" }?.forEach { a.put(JSONObject(it.readText())) }; response(out, 200, "application/json", a.toString().toByteArray())
    }
    private fun meta(out: OutputStream, id: String) { val f = File(root, "files/$id.json"); if (!f.exists()) response(out, 404, "application/json", ByteArray(0)) else response(out, 200, "application/json", f.readBytes()) }
    private fun download(out: OutputStream, id: String) { val metadata = File(root, "files/$id.json"); val stored = if (metadata.exists()) JSONObject(metadata.readText()).optString("storedName", "encryptedImage_${id.take(12)}") else ""; val current = File(root, "files/$stored.bin"); val legacy = File(root, "files/$id.jpg"); val f = if (current.exists()) current else legacy; if (!f.exists()) response(out, 404, "application/json", ByteArray(0)) else response(out, 200, "application/octet-stream", f.readBytes()) }
    private fun delete(out: OutputStream, r: Request, id: String) {
        if (!id.matches(Regex("[a-f0-9]{64}"))) return response(out, 400, "application/json", ByteArray(0))
        val metadata = File(root, "files/$id.json")
        if (!metadata.exists()) return response(out, 404, "application/json", ByteArray(0))
        val supplied = r.headers["x-hivenet-delete-token"] ?: return response(out, 401, "application/json", ByteArray(0))
        val expected = JSONObject(metadata.readText()).optString("deleteTokenHash")
        val actual = MessageDigest.getInstance("SHA-256").digest(supplied.toByteArray()).joinToString("") { "%02x".format(it) }
        if (expected != actual) return response(out, 403, "application/json", ByteArray(0))
        val stored = JSONObject(metadata.readText()).optString("storedName", "encryptedImage_${id.take(12)}")
        File(root, "files/$stored.bin").delete(); File(root, "files/$id.jpg").delete(); metadata.delete(); File(root, "files/$stored.part").delete(); File(root, "files/$id.part").delete()
        response(out, 200, "application/json", "{\"deleted\":true,\"id\":\"$id\"}".toByteArray())
    }
    private fun idFromPath(path: String) = path.removePrefix("/v1/files/").removeSuffix("/meta")
    // Chrome's Local Network Access / Private Network Access preflight asks
    // for this explicit opt-in before a public page may contact a LAN peer.
    // Older browsers safely ignore the extra CORS response header.
    private fun corsPreflight(out: OutputStream) { out.write("HTTP/1.1 204 No Content\r\nAccess-Control-Allow-Origin: *\r\nAccess-Control-Allow-Methods: GET, PUT, DELETE, OPTIONS\r\nAccess-Control-Allow-Headers: Content-Type, X-HiveNet-Sha256, X-HiveNet-Name, X-HiveNet-Name-B64, X-HiveNet-Mime, X-HiveNet-Original-Bytes, X-HiveNet-Delete-Token-Hash, X-HiveNet-Delete-Token, X-HiveNet-Sender, X-HiveNet-Sender-B64, X-HiveNet-Stored-Name\r\nAccess-Control-Allow-Private-Network: true\r\nAccess-Control-Max-Age: 600\r\nContent-Length: 0\r\nConnection: close\r\n\r\n".toByteArray()); out.flush() }
    private fun response(out: OutputStream, status: Int, type: String, body: ByteArray) { val text = if (status in 200..299) "OK" else "Error"; out.write("HTTP/1.1 $status $text\r\nContent-Type: $type\r\nContent-Length: ${body.size}\r\nAccess-Control-Allow-Origin: *\r\nAccess-Control-Allow-Private-Network: true\r\nConnection: close\r\n\r\n".toByteArray()); out.write(body); out.flush() }
    override fun onDestroy() { running = false; server?.close(); workers.shutdownNow(); super.onDestroy() }
    override fun onBind(intent: Intent?): IBinder? = null
}
