package com.ngamepad.ngamepad

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothHidDevice
import android.bluetooth.BluetoothHidDeviceAppQosSettings
import android.bluetooth.BluetoothHidDeviceAppSdpSettings
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.ScheduledFuture
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong

/**
 * Manages the Android [BluetoothHidDevice] profile, registration lifecycle,
 * host connections, OEM HID support diagnostics, and steady-rate HID report transmission.
 */
class BluetoothHidManager(
    private val context: Context,
    private val onStatusChanged: (Map<String, Any?>) -> Unit,
) {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val bluetoothManager: BluetoothManager? =
        context.getSystemService(BluetoothManager::class.java)
    private val bluetoothAdapter: BluetoothAdapter? = bluetoothManager?.adapter

    private val executor: ScheduledExecutorService = Executors.newSingleThreadScheduledExecutor { r ->
        Thread(r, "nGamepad-HidWorker").apply { isDaemon = true }
    }

    private var hidDevice: BluetoothHidDevice? = null
    private var connectedHost: BluetoothDevice? = null
    private var pollingTask: ScheduledFuture<*>? = null
    private var proxyTimeoutRunnable: Runnable? = null

    private val stateLock = Any()
    private val currentState = HidDescriptor.GamepadInputState()
    private val reportBuffer = ByteArray(HidDescriptor.REPORT_SIZE)
    private val lastSentReport = ByteArray(HidDescriptor.REPORT_SIZE)
    private val hasDirtyReport = AtomicBoolean(false)
    private val lastSendNanos = AtomicLong(0L)

    @Volatile
    private var isProxyRequested = false

    @Volatile
    private var isAppRegistered = false

    @Volatile
    private var hidSupported: Boolean = true

    @Volatile
    private var connectionState: String = "disconnected"

    @Volatile
    private var diagnosticMessage: String = "Initializing Bluetooth HID..."

    @Volatile
    private var pollingHz: Int = 120

    private val profileListener = object : BluetoothProfile.ServiceListener {
        override fun onServiceConnected(profile: Int, proxy: BluetoothProfile) {
            if (profile != BluetoothProfile.HID_DEVICE) return
            cancelProxyTimeout()
            val device = proxy as? BluetoothHidDevice
            if (device == null) {
                hidSupported = false
                diagnosticMessage = "Device returned an invalid BluetoothHidDevice proxy."
                emitStatus()
                return
            }
            hidDevice = device
            hidSupported = true
            diagnosticMessage = "HID profile proxy connected. Registering gamepad..."
            emitStatus()
            registerHidApp(device)
        }

        override fun onServiceDisconnected(profile: Int) {
            if (profile != BluetoothProfile.HID_DEVICE) return
            cancelProxyTimeout()
            stopPollingLoop()
            hidDevice = null
            connectedHost = null
            isAppRegistered = false
            isProxyRequested = false
            connectionState = "disconnected"
            diagnosticMessage = "Bluetooth HID system service disconnected."
            emitStatus()
        }
    }

    private val hidCallback = object : BluetoothHidDevice.Callback() {
        override fun onAppStatusChanged(pluggedDevice: BluetoothDevice?, registered: Boolean) {
            isAppRegistered = registered
            if (registered) {
                diagnosticMessage = if (pluggedDevice != null) {
                    "HID gamepad registered. Ready for ${safeDeviceName(pluggedDevice)}."
                } else {
                    "HID gamepad registered. Ready to pair or connect."
                }
                if (pluggedDevice != null && connectedHost == null) {
                    connectedHost = pluggedDevice
                }
            } else {
                stopPollingLoop()
                connectedHost = null
                connectionState = "disconnected"
                diagnosticMessage = "HID app unregistered by Bluetooth stack."
            }
            emitStatus()
        }

        override fun onConnectionStateChanged(device: BluetoothDevice?, state: Int) {
            when (state) {
                BluetoothProfile.STATE_CONNECTED -> {
                    connectedHost = device
                    connectionState = "connected"
                    diagnosticMessage = "Connected to ${safeDeviceName(device)}"
                    startPollingLoop()
                }
                BluetoothProfile.STATE_CONNECTING -> {
                    connectedHost = device
                    connectionState = "connecting"
                    diagnosticMessage = "Connecting to ${safeDeviceName(device)}..."
                }
                BluetoothProfile.STATE_DISCONNECTED -> {
                    stopPollingLoop()
                    connectedHost = null
                    connectionState = "disconnected"
                    diagnosticMessage = if (isAppRegistered) {
                        "Host disconnected. Ready to reconnect."
                    } else {
                        "Disconnected."
                    }
                }
                BluetoothProfile.STATE_DISCONNECTING -> {
                    connectionState = "disconnecting"
                    diagnosticMessage = "Disconnecting from ${safeDeviceName(device)}..."
                }
            }
            emitStatus()
        }

        override fun onGetReport(device: BluetoothDevice?, type: Byte, id: Byte, bufferSize: Int) {
            val hid = hidDevice ?: return
            if (!hasBluetoothConnectPermission() || device == null) return
            val snapshot = ByteArray(HidDescriptor.REPORT_SIZE)
            synchronized(stateLock) {
                currentState.packInto(snapshot)
            }
            @SuppressLint("MissingPermission")
            hid.replyReport(device, type, id, snapshot)
        }

        override fun onSetProtocol(device: BluetoothDevice?, protocol: Byte) {
            // Standard report protocol acknowledged automatically by Android BT stack.
        }
    }

    fun hasRequiredPermissions(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            hasPermission(Manifest.permission.BLUETOOTH_CONNECT) &&
                hasPermission(Manifest.permission.BLUETOOTH_ADVERTISE) &&
                hasPermission(Manifest.permission.BLUETOOTH_SCAN)
        } else {
            hasPermission(Manifest.permission.BLUETOOTH) &&
                hasPermission(Manifest.permission.BLUETOOTH_ADMIN)
        }
    }

    private fun hasBluetoothConnectPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            hasPermission(Manifest.permission.BLUETOOTH_CONNECT)
        } else {
            hasPermission(Manifest.permission.BLUETOOTH)
        }
    }

    private fun hasPermission(permission: String): Boolean {
        return context.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED
    }

    /**
     * Performs startup diagnostics and binds the [BluetoothProfile.HID_DEVICE] proxy.
     */
    fun initialize() {
        val adapter = bluetoothAdapter
        if (adapter == null) {
            hidSupported = false
            diagnosticMessage = "This device has no Bluetooth hardware."
            emitStatus()
            return
        }
        if (!hasRequiredPermissions()) {
            diagnosticMessage = "Bluetooth permissions required to start HID gamepad."
            emitStatus()
            return
        }
        if (!adapter.isEnabled) {
            diagnosticMessage = "Bluetooth is turned off. Enable Bluetooth to bridge."
            emitStatus()
            return
        }
        if (hidDevice != null) {
            if (!isAppRegistered) {
                registerHidApp(hidDevice!!)
            } else {
                emitStatus()
            }
            return
        }
        if (isProxyRequested) {
            emitStatus()
            return
        }

        isProxyRequested = true
        diagnosticMessage = "Checking OEM Bluetooth HID Device support..."
        emitStatus()

        val requested = try {
            adapter.getProfileProxy(context, profileListener, BluetoothProfile.HID_DEVICE)
        } catch (e: SecurityException) {
            isProxyRequested = false
            diagnosticMessage = "Bluetooth permission denied: ${e.message}"
            emitStatus()
            return
        }

        if (!requested) {
            isProxyRequested = false
            hidSupported = false
            diagnosticMessage =
                "OEM ROM does not support Bluetooth HID Device profile (getProfileProxy returned false)."
            emitStatus()
            return
        }

        // Guard against OEM ROMs that silently drop the HID_DEVICE proxy callback.
        val timeout = Runnable {
            if (hidDevice == null && isProxyRequested) {
                isProxyRequested = false
                hidSupported = false
                diagnosticMessage =
                    "Bluetooth HID Device service timed out. Your OEM ROM may disable HID peripheral mode."
                emitStatus()
            }
        }
        proxyTimeoutRunnable = timeout
        mainHandler.postDelayed(timeout, 4000L)
    }

    private fun cancelProxyTimeout() {
        proxyTimeoutRunnable?.let { mainHandler.removeCallbacks(it) }
        proxyTimeoutRunnable = null
    }

    @SuppressLint("MissingPermission")
    private fun registerHidApp(device: BluetoothHidDevice) {
        if (!hasBluetoothConnectPermission()) return

        val sdp = BluetoothHidDeviceAppSdpSettings(
            "nGamepad Pro",
            "USB-C to Bluetooth HID Gamepad",
            "nGamepad",
            BluetoothHidDevice.SUBCLASS2_GAMEPAD,
            HidDescriptor.DESCRIPTOR,
        )

        val qosOut = BluetoothHidDeviceAppQosSettings(
            BluetoothHidDeviceAppQosSettings.SERVICE_BEST_EFFORT,
            800,
            HidDescriptor.REPORT_SIZE,
            0,
            8000, // ~8ms target latency
            BluetoothHidDeviceAppQosSettings.MAX,
        )

        val ok = try {
            device.registerApp(sdp, null, qosOut, executor, hidCallback)
        } catch (e: SecurityException) {
            diagnosticMessage = "Failed to register HID app: ${e.message}"
            emitStatus()
            false
        }

        if (!ok) {
            hidSupported = false
            diagnosticMessage =
                "registerApp() rejected by Bluetooth stack. Another HID app may be active or OEM ROM blocks HID."
            emitStatus()
        }
    }

    /**
     * Updates the native gamepad state directly from [MainActivity] and triggers an immediate
     * HID report send if a host is connected (avoiding any Dart-to-Native round-trip).
     */
    fun updateInputState(
        buttons: Int,
        hat: Int,
        lx: Int,
        ly: Int,
        rx: Int,
        ry: Int,
        l2: Int,
        r2: Int,
    ) {
        synchronized(stateLock) {
            currentState.buttons = buttons
            currentState.hat = hat
            currentState.lx = lx
            currentState.ly = ly
            currentState.rx = rx
            currentState.ry = ry
            currentState.l2 = l2
            currentState.r2 = r2
        }
        hasDirtyReport.set(true)

        if (connectedHost != null) {
            executor.execute { sendReportIfConnected(force = false) }
        }
    }

    fun setPollingRateHz(hz: Int) {
        val clamped = hz.coerceIn(30, 250)
        if (pollingHz == clamped) return
        pollingHz = clamped
        if (connectedHost != null) {
            startPollingLoop()
        }
        emitStatus()
    }

    @SuppressLint("MissingPermission")
    fun getPairedDevices(): List<Map<String, Any?>> {
        val adapter = bluetoothAdapter ?: return emptyList()
        if (!hasBluetoothConnectPermission() || !adapter.isEnabled) return emptyList()
        return try {
            adapter.bondedDevices
                ?.map { dev ->
                    mapOf(
                        "name" to (dev.name?.takeIf { it.isNotBlank() } ?: "Unknown Device"),
                        "address" to dev.address,
                        "isConnected" to (connectedHost?.address == dev.address),
                    )
                }
                ?.sortedBy { (it["name"] as String).lowercase() }
                ?: emptyList()
        } catch (_: SecurityException) {
            emptyList()
        }
    }

    @SuppressLint("MissingPermission")
    fun connectHost(address: String): Boolean {
        val adapter = bluetoothAdapter ?: return false
        val hid = hidDevice ?: return false
        if (!hasBluetoothConnectPermission() || !isAppRegistered) return false

        val target = try {
            adapter.getRemoteDevice(address)
        } catch (_: IllegalArgumentException) {
            return false
        }

        connectionState = "connecting"
        diagnosticMessage = "Connecting to ${safeDeviceName(target)}..."
        emitStatus()

        return try {
            hid.connect(target)
        } catch (e: SecurityException) {
            diagnosticMessage = "Connect permission error: ${e.message}"
            emitStatus()
            false
        }
    }

    @SuppressLint("MissingPermission")
    fun disconnectHost(): Boolean {
        val hid = hidDevice ?: return false
        val host = connectedHost ?: return false
        if (!hasBluetoothConnectPermission()) return false
        return try {
            hid.disconnect(host)
        } catch (_: SecurityException) {
            false
        }
    }

    fun getStatusSnapshot(): Map<String, Any?> {
        val adapter = bluetoothAdapter
        return mapOf(
            "bluetoothAvailable" to (adapter != null),
            "bluetoothEnabled" to (adapter?.isEnabled == true),
            "permissionsGranted" to hasRequiredPermissions(),
            "hidSupported" to hidSupported,
            "appRegistered" to isAppRegistered,
            "connectionState" to connectionState,
            "connectedHostName" to connectedHost?.let { safeDeviceName(it) },
            "connectedHostAddress" to connectedHost?.address,
            "pollingHz" to pollingHz,
            "diagnosticMessage" to diagnosticMessage,
            "pairedDevices" to getPairedDevices(),
        )
    }

    private fun startPollingLoop() {
        stopPollingLoop()
        val periodUs = (1_000_000L / pollingHz.coerceIn(30, 250)).coerceAtLeast(4000L)
        pollingTask = executor.scheduleAtFixedRate(
            { sendReportIfConnected(force = true) },
            0L,
            periodUs,
            TimeUnit.MICROSECONDS,
        )
    }

    private fun stopPollingLoop() {
        pollingTask?.cancel(false)
        pollingTask = null
    }

    @SuppressLint("MissingPermission")
    private fun sendReportIfConnected(force: Boolean) {
        val hid = hidDevice ?: return
        val host = connectedHost ?: return
        if (!isAppRegistered || !hasBluetoothConnectPermission()) return

        synchronized(stateLock) {
            currentState.packInto(reportBuffer)
        }

        val dirty = hasDirtyReport.getAndSet(false)
        val changed = !reportBuffer.contentEquals(lastSentReport)

        // Avoid flooding BT stack with identical reports faster than ~30Hz idle keepalive
        val now = System.nanoTime()
        val elapsedMs = (now - lastSendNanos.get()) / 1_000_000L
        if (!dirty && !changed && (!force || elapsedMs < 33L)) {
            return
        }

        try {
            val sent = hid.sendReport(host, HidDescriptor.REPORT_ID, reportBuffer)
            if (sent) {
                System.arraycopy(reportBuffer, 0, lastSentReport, 0, HidDescriptor.REPORT_SIZE)
                lastSendNanos.set(now)
            }
        } catch (_: SecurityException) {
            // Permission revoked mid-session
        }
    }

    @SuppressLint("MissingPermission")
    private fun safeDeviceName(device: BluetoothDevice?): String {
        if (device == null) return "Unknown Host"
        return if (hasBluetoothConnectPermission()) {
            device.name?.takeIf { it.isNotBlank() } ?: device.address
        } else {
            device.address
        }
    }

    private fun emitStatus() {
        val snapshot = getStatusSnapshot()
        mainHandler.post { onStatusChanged(snapshot) }
    }

    @SuppressLint("MissingPermission")
    fun shutdown() {
        cancelProxyTimeout()
        stopPollingLoop()
        val hid = hidDevice
        val adapter = bluetoothAdapter
        if (hid != null) {
            if (hasBluetoothConnectPermission()) {
                try {
                    connectedHost?.let { hid.disconnect(it) }
                    if (isAppRegistered) {
                        hid.unregisterApp()
                    }
                } catch (_: SecurityException) {
                }
            }
            adapter?.closeProfileProxy(BluetoothProfile.HID_DEVICE, hid)
        }
        hidDevice = null
        connectedHost = null
        isAppRegistered = false
        isProxyRequested = false
        executor.shutdownNow()
    }
}
