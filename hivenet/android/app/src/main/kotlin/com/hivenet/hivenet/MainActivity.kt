package com.hivenet.hivenet

import android.Manifest
import android.content.pm.PackageManager
import android.content.Intent
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.Signature
import java.security.spec.ECGenParameterSpec
import java.net.NetworkInterface
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val channel = "com.hivenet.hivenet/node"
    private val keyAlias = "hivenet.device.signing.v1"

    private fun devicePublicKey(): String {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        if (!store.containsAlias(keyAlias)) {
            val generator = KeyPairGenerator.getInstance(KeyProperties.KEY_ALGORITHM_EC, "AndroidKeyStore")
            generator.initialize(KeyGenParameterSpec.Builder(keyAlias, KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_VERIFY)
                .setAlgorithmParameterSpec(ECGenParameterSpec("secp256r1"))
                .setDigests(KeyProperties.DIGEST_SHA256).build())
            generator.generateKeyPair()
        }
        return Base64.encodeToString(store.getCertificate(keyAlias).publicKey.encoded, Base64.NO_WRAP)
    }

    private fun sign(payload: String): String {
        devicePublicKey() // Ensures the Android Keystore key exists.
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        val signer = Signature.getInstance("SHA256withECDSA")
        signer.initSign((store.getKey(keyAlias, null) as java.security.PrivateKey))
        signer.update(payload.toByteArray(Charsets.UTF_8))
        return Base64.encodeToString(signer.sign(), Base64.NO_WRAP)
    }
    private fun lanIp(): String? = NetworkInterface.getNetworkInterfaces().toList()
        .flatMap { it.inetAddresses.toList() }
        .firstOrNull { !it.isLoopbackAddress && it.hostAddress.indexOf(':') < 0 }?.hostAddress

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startNode" -> {
                        val id = call.argument<String>("nodeId") ?: "unknown"
                        if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 41)
                        }
                        try {
                            val intent = Intent(this, HiveNodeService::class.java).putExtra("nodeId", id)
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(intent) else startService(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("NODE_START_FAILED", e.message, null)
                        }
                    }
                    "stopNode" -> { stopService(Intent(this, HiveNodeService::class.java)); result.success(true) }
                    "incomingTransfers" -> {
                        result.success(HiveNodeService.incomingTransfers(this))
                    }
                    "deviceName" -> result.success("${Build.MANUFACTURER} ${Build.MODEL}")
                    "devicePublicKey" -> try { result.success(devicePublicKey()) } catch (e: Exception) { result.error("KEYSTORE", e.message, null) }
                    "signDeviceProof" -> try { result.success(sign(call.argument<String>("payload") ?: "")) } catch (e: Exception) { result.error("KEYSTORE", e.message, null) }
                    "localIp" -> result.success(lanIp())
                    "startPairing" -> {
                        @Suppress("UNCHECKED_CAST") val owner = call.argument<Map<String, Any?>>("owner") ?: emptyMap()
                        result.success(HiveNodeService.startPairing(this, owner))
                    }
                    "pairingRequests" -> result.success(HiveNodeService.pairingRequests(this))
                    "approvePairing" -> result.success(HiveNodeService.approvePairing(this, call.argument<String>("deviceId") ?: ""))
                    else -> result.notImplemented()
                }
            }
    }
}
