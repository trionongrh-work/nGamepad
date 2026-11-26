package com.ngamepad.ngamepad

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.input.InputManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.InputDevice
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.math.hypot

class MainActivity : FlutterActivity(), InputManager.InputDeviceListener {

    companion object {
        private const val METHOD_CHANNEL = "com.ngamepad.ngamepad/control"
        private const val STATUS_EVENT_CHANNEL = "com.ngamepad.ngamepad/status"
        private const val TELEMETRY_EVENT_CHANNEL = "com.ngamepad.ngamepad/telemetry"
        private const val REQ_BT_PERMISSIONS = 1001
        private const val REQ_DISCOVERABLE = 1002
    }

    private lateinit var hidManager: BluetoothHidManager
    private lateinit var inputManager: InputManager
    private val mainHandler = Handler(Looper.getMainLooper())

    private var statusSink: EventChannel.EventSink? = null
    private var telemetrySink: EventChannel.EventSink? = null
    private var pendingPermissionResult: MethodChannel.Result? = null

    private var deadzone: Float = 0.08f
    private var keepScreenOn: Boolean = true
    private var oledDimEnabled: Boolean = false

    // Live hardware input state (updated on UI thread by InputDispatcher)
    private var buttonsMask: Int = 0
    private var hatX: Int = 0
    private var hatY: Int = 0
    private var dpadLeftDown = false
    private var dpadRightDown = false
    private var dpadUpDown = false
    private var dpadDownDown = false
    private var analogL2: Float = 0f
    private var analogR2: Float = 0f
    private var digitalL2Down = false
    private var digitalR2Down = false
    private var hasAnalogL2 = false
    private var hasAnalogR2 = false
    private var l2Axis: Int = MotionEvent.AXIS_LTRIGGER
    private var r2Axis: Int = MotionEvent.AXIS_RTRIGGER
    private var l2RangeMin: Float = 0f
    private var l2RangeSpan: Float = 1f
    private var r2RangeMin: Float = 0f
    private var r2RangeSpan: Float = 1f

    private var lxInt8: Int = 0
    private var lyInt8: Int = 0
    private var rxInt8: Int = 0
    private var ryInt8: Int = 0

    private var activeGamepadName: String? = null
    private var activeGamepadConnected: Boolean = false

    private var lastTelemetrySentMs: Long = 0L
    private val telemetryThrottleMs: Long = 16L // ~60Hz UI feedback

    private val bluetoothStateReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                BluetoothAdapter.ACTION_STATE_CHANGED -> {
                    val state = intent.getIntExtra(
                        BluetoothAdapter.EXTRA_STATE,
                        BluetoothAdapter.ERROR,
                    )
                    if (state == BluetoothAdapter.STATE_ON) {
                        hidManager.initialize()
                    } else {
                        statusSink?.success(hidManager.getStatusSnapshot())
                    }
                }
                BluetoothDevice.ACTION_BOND_STATE_CHANGED -> {
                    statusSink?.success(hidManager.getStatusSnapshot())
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        inputManager = getSystemService(Context.INPUT_SERVICE) as InputManager
        inputManager.registerInputDeviceListener(this, mainHandler)
        refreshConnectedGamepad()

        hidManager = BluetoothHidManager(this) { status ->
            statusSink?.success(status)
        }

        val filter = IntentFilter().apply {
            addAction(BluetoothAdapter.ACTION_STATE_CHANGED)
            addAction(BluetoothDevice.ACTION_BOND_STATE_CHANGED)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(bluetoothStateReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(bluetoothStateReceiver, filter)
        }

        applyWindowSettings()
        hidManager.initialize()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                handleMethodCall(call, result)
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, STATUS_EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    statusSink = events
                    events?.success(hidManager.getStatusSnapshot())
                }

                override fun onCancel(arguments: Any?) {
                    statusSink = null
                }
            })

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, TELEMETRY_EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    telemetrySink = events
                    emitTelemetry(force = true)
                }

                override fun onCancel(arguments: Any?) {
                    telemetrySink = null
                }
            })
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> {
                hidManager.initialize()
                result.success(hidManager.getStatusSnapshot())
            }
            "requestPermissions" -> {
                if (hidManager.hasRequiredPermissions()) {
                    hidManager.initialize()
                    result.success(true)
                } else {
                    pendingPermissionResult = result
                    val perms = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        arrayOf(
                            Manifest.permission.BLUETOOTH_CONNECT,
                            Manifest.permission.BLUETOOTH_SCAN,
                            Manifest.permission.BLUETOOTH_ADVERTISE,
                        )
                    } else {
                        arrayOf(
                            Manifest.permission.BLUETOOTH,
                            Manifest.permission.BLUETOOTH_ADMIN,
                        )
                    }
                    requestPermissions(perms, REQ_BT_PERMISSIONS)
                }
            }
            "getStatus" -> {
                result.success(hidManager.getStatusSnapshot())
            }
            "connectHost" -> {
                val address = call.argument<String>("address")
                if (address.isNullOrBlank()) {
                    result.error("INVALID_ARGS", "Missing Bluetooth address", null)
                } else {
                    result.success(hidManager.connectHost(address))
                }
            }
            "disconnectHost" -> {
                result.success(hidManager.disconnectHost())
            }
            "requestDiscoverable" -> {
                try {
                    val intent = Intent(BluetoothAdapter.ACTION_REQUEST_DISCOVERABLE).apply {
                        putExtra(BluetoothAdapter.EXTRA_DISCOVERABLE_DURATION, 120)
                    }
                    @Suppress("DEPRECATION")
                    startActivityForResult(intent, REQ_DISCOVERABLE)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("DISCOVERABLE_FAILED", e.message, null)
                }
            }
            "setDeadzone" -> {
                val value = (call.argument<Double>("value") ?: 0.08).toFloat()
                deadzone = value.coerceIn(0f, 0.35f)
                result.success(null)
            }
            "setPollingRate" -> {
                val hz = call.argument<Int>("hz") ?: 120
                hidManager.setPollingRateHz(hz)
                result.success(null)
            }
            "setKeepScreenOn" -> {
                keepScreenOn = call.argument<Boolean>("enabled") ?: true
                applyWindowSettings()
                result.success(null)
            }
            "setOledDim" -> {
                oledDimEnabled = call.argument<Boolean>("enabled") ?: false
                applyWindowSettings()
                result.success(null)
            }
            "getIntroCompleted" -> {
                val prefs = getSharedPreferences("ngamepad_prefs", Context.MODE_PRIVATE)
                result.success(prefs.getBoolean("intro_completed", false))
            }
            "setIntroCompleted" -> {
                val completed = call.argument<Boolean>("completed") ?: true
                getSharedPreferences("ngamepad_prefs", Context.MODE_PRIVATE)
                    .edit()
                    .putBoolean("intro_completed", completed)
                    .apply()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQ_BT_PERMISSIONS) {
            val granted = hidManager.hasRequiredPermissions()
            if (granted) {
                hidManager.initialize()
            } else {
                statusSink?.success(hidManager.getStatusSnapshot())
            }
            pendingPermissionResult?.success(granted)
            pendingPermissionResult = null
        }
    }

    private fun applyWindowSettings() {
        runOnUiThread {
            if (keepScreenOn) {
                window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            } else {
                window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            }
            val attrs = window.attributes
            attrs.screenBrightness = if (oledDimEnabled) 0.01f else -1f
            window.attributes = attrs
        }
    }

    // --- USB / Hardware Gamepad Input Capture (Zero Dart-round-trip for HID) ---

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (isGamepadSource(event.source) && event.deviceId > 0) {
            if (handleGamepadKeyEvent(event)) {
                return true
            }
        }
        return super.dispatchKeyEvent(event)
    }

    override fun dispatchGenericMotionEvent(event: MotionEvent): Boolean {
        if (isGamepadSource(event.source) && event.deviceId > 0) {
            if (handleGamepadMotionEvent(event)) {
                return true
            }
        }
        return super.dispatchGenericMotionEvent(event)
    }

    private fun isGamepadSource(source: Int): Boolean {
        return (source and InputDevice.SOURCE_GAMEPAD) == InputDevice.SOURCE_GAMEPAD ||
            (source and InputDevice.SOURCE_JOYSTICK) == InputDevice.SOURCE_JOYSTICK ||
            (source and InputDevice.SOURCE_DPAD) == InputDevice.SOURCE_DPAD
    }

    private fun handleGamepadKeyEvent(event: KeyEvent): Boolean {
        if (event.repeatCount > 0 && event.action == KeyEvent.ACTION_DOWN) {
            return true // Swallow key repeats for held gamepad buttons
        }
        val pressed = event.action == KeyEvent.ACTION_DOWN
        updateActiveGamepad(event.device)

        var handled = true
        when (event.keyCode) {
            KeyEvent.KEYCODE_BUTTON_A -> setButtonBit(HidDescriptor.BTN_A, pressed)
            KeyEvent.KEYCODE_BUTTON_B -> setButtonBit(HidDescriptor.BTN_B, pressed)
            KeyEvent.KEYCODE_BUTTON_X -> setButtonBit(HidDescriptor.BTN_X, pressed)
            KeyEvent.KEYCODE_BUTTON_Y -> setButtonBit(HidDescriptor.BTN_Y, pressed)
            KeyEvent.KEYCODE_BUTTON_L1 -> setButtonBit(HidDescriptor.BTN_L1, pressed)
            KeyEvent.KEYCODE_BUTTON_R1 -> setButtonBit(HidDescriptor.BTN_R1, pressed)
            KeyEvent.KEYCODE_BUTTON_L2 -> digitalL2Down = pressed
            KeyEvent.KEYCODE_BUTTON_R2 -> digitalR2Down = pressed
            KeyEvent.KEYCODE_BUTTON_SELECT, KeyEvent.KEYCODE_BACK ->
                setButtonBit(HidDescriptor.BTN_SELECT, pressed)
            KeyEvent.KEYCODE_BUTTON_START -> setButtonBit(HidDescriptor.BTN_START, pressed)
            KeyEvent.KEYCODE_BUTTON_THUMBL -> setButtonBit(HidDescriptor.BTN_L3, pressed)
            KeyEvent.KEYCODE_BUTTON_THUMBR -> setButtonBit(HidDescriptor.BTN_R3, pressed)
            KeyEvent.KEYCODE_BUTTON_MODE -> setButtonBit(HidDescriptor.BTN_HOME, pressed)
            KeyEvent.KEYCODE_BUTTON_C -> setButtonBit(HidDescriptor.BTN_EXTRA1, pressed)
            KeyEvent.KEYCODE_BUTTON_Z -> setButtonBit(HidDescriptor.BTN_EXTRA2, pressed)
            KeyEvent.KEYCODE_DPAD_LEFT -> dpadLeftDown = pressed
            KeyEvent.KEYCODE_DPAD_RIGHT -> dpadRightDown = pressed
            KeyEvent.KEYCODE_DPAD_UP -> dpadUpDown = pressed
            KeyEvent.KEYCODE_DPAD_DOWN -> dpadDownDown = pressed
            else -> handled = false
        }

        if (handled) {
            pushStateToHidAndUi()
        }
        return handled
    }

    private fun handleGamepadMotionEvent(event: MotionEvent): Boolean {
        if (event.action != MotionEvent.ACTION_MOVE) return false
        updateActiveGamepad(event.device)

        val rawLx = event.getAxisValue(MotionEvent.AXIS_X)
        val rawLy = event.getAxisValue(MotionEvent.AXIS_Y)
        val (nlx, nly) = applyRadialDeadzone(rawLx, rawLy, deadzone)
        lxInt8 = HidDescriptor.axisToInt8(nlx)
        lyInt8 = HidDescriptor.axisToInt8(nly)

        val rawRx = event.getAxisValue(MotionEvent.AXIS_Z)
        val rawRy = event.getAxisValue(MotionEvent.AXIS_RZ)
        val (nrx, nry) = applyRadialDeadzone(rawRx, rawRy, deadzone)
        rxInt8 = HidDescriptor.axisToInt8(nrx)
        ryInt8 = HidDescriptor.axisToInt8(nry)

        // Triggers: use the device's reported MotionRange so both [0, 1] and [-1, 1] ranges are linear
        if (hasAnalogL2) {
            analogL2 = normalizeTrigger(event.getAxisValue(l2Axis), l2RangeMin, l2RangeSpan)
        }
        if (hasAnalogR2) {
            analogR2 = normalizeTrigger(event.getAxisValue(r2Axis), r2RangeMin, r2RangeSpan)
        }

        // Hat switch (D-Pad on GameSir X2 Pro)
        val rawHatX = event.getAxisValue(MotionEvent.AXIS_HAT_X)
        val rawHatY = event.getAxisValue(MotionEvent.AXIS_HAT_Y)
        hatX = when {
            rawHatX < -0.5f -> -1
            rawHatX > 0.5f -> 1
            else -> 0
        }
        hatY = when {
            rawHatY < -0.5f -> -1
            rawHatY > 0.5f -> 1
            else -> 0
        }

        pushStateToHidAndUi()
        return true
    }

    private fun setButtonBit(bitIndex: Int, pressed: Boolean) {
        buttonsMask = if (pressed) {
            buttonsMask or (1 shl bitIndex)
        } else {
            buttonsMask and (1 shl bitIndex).inv()
        }
    }

    private fun applyRadialDeadzone(x: Float, y: Float, dz: Float): Pair<Float, Float> {
        val mag = hypot(x.toDouble(), y.toDouble()).toFloat()
        if (mag <= dz || mag < 1e-5f) return 0f to 0f
        val scaled = ((mag - dz) / (1f - dz)).coerceIn(0f, 1f)
        val factor = scaled / mag
        return (x * factor).coerceIn(-1f, 1f) to (y * factor).coerceIn(-1f, 1f)
    }

    private fun normalizeTrigger(raw: Float, min: Float, span: Float): Float {
        if (span <= 1e-5f) return raw.coerceIn(0f, 1f)
        return ((raw - min) / span).coerceIn(0f, 1f)
    }

    private fun computeTriggerByte(analog: Float, digitalDown: Boolean, hasAnalog: Boolean): Int {
        return if (hasAnalog) {
            HidDescriptor.triggerToUInt8(analog)
        } else if (digitalDown) {
            255
        } else {
            0
        }
    }

    private fun pushStateToHidAndUi() {
        val combinedHatX = when {
            dpadLeftDown && !dpadRightDown -> -1
            dpadRightDown && !dpadLeftDown -> 1
            else -> hatX
        }
        val combinedHatY = when {
            dpadUpDown && !dpadDownDown -> -1
            dpadDownDown && !dpadUpDown -> 1
            else -> hatY
        }
        val hat = HidDescriptor.computeHat(combinedHatX, combinedHatY)

        val l2Byte = computeTriggerByte(analogL2, digitalL2Down, hasAnalogL2)
        val r2Byte = computeTriggerByte(analogR2, digitalR2Down, hasAnalogR2)

        // Mirror analog trigger press onto digital L2/R2 button bits for broader host compatibility
        setButtonBit(HidDescriptor.BTN_L2, digitalL2Down || l2Byte > 20)
        setButtonBit(HidDescriptor.BTN_R2, digitalR2Down || r2Byte > 20)

        hidManager.updateInputState(
            buttons = buttonsMask,
            hat = hat,
            lx = lxInt8,
            ly = lyInt8,
            rx = rxInt8,
            ry = ryInt8,
            l2 = l2Byte,
            r2 = r2Byte,
        )

        emitTelemetry(force = false)
    }

    private fun emitTelemetry(force: Boolean) {
        val sink = telemetrySink ?: return
        val now = System.currentTimeMillis()
        if (!force && (now - lastTelemetrySentMs) < telemetryThrottleMs) {
            return
        }
        lastTelemetrySentMs = now

        val combinedHatX = when {
            dpadLeftDown && !dpadRightDown -> -1
            dpadRightDown && !dpadLeftDown -> 1
            else -> hatX
        }
        val combinedHatY = when {
            dpadUpDown && !dpadDownDown -> -1
            dpadDownDown && !dpadUpDown -> 1
            else -> hatY
        }
        val hat = HidDescriptor.computeHat(combinedHatX, combinedHatY)
        val l2Byte = computeTriggerByte(analogL2, digitalL2Down, hasAnalogL2)
        val r2Byte = computeTriggerByte(analogR2, digitalR2Down, hasAnalogR2)

        val map = HidDescriptor.GamepadInputState(
            buttons = buttonsMask,
            hat = hat,
            lx = lxInt8,
            ly = lyInt8,
            rx = rxInt8,
            ry = ryInt8,
            l2 = l2Byte,
            r2 = r2Byte,
        ).toTelemetryMap(
            usbDeviceName = activeGamepadName,
            usbConnected = activeGamepadConnected,
        )
        sink.success(map)
    }

    // --- USB Gamepad Hot-plugging ---

    override fun onInputDeviceAdded(deviceId: Int) {
        refreshConnectedGamepad()
        emitTelemetry(force = true)
    }

    override fun onInputDeviceRemoved(deviceId: Int) {
        refreshConnectedGamepad()
        if (!activeGamepadConnected) {
            resetGamepadInputState()
        }
        emitTelemetry(force = true)
    }

    override fun onInputDeviceChanged(deviceId: Int) {
        refreshConnectedGamepad()
        emitTelemetry(force = true)
    }

    private fun updateActiveGamepad(device: InputDevice?) {
        if (device == null) return
        if (!activeGamepadConnected || activeGamepadName != device.name) {
            activeGamepadConnected = true
            activeGamepadName = device.name
            configureTriggerRanges(device)
        }
    }

    private fun configureTriggerRanges(device: InputDevice) {
        val lRange = device.getMotionRange(MotionEvent.AXIS_LTRIGGER)
            ?: device.getMotionRange(MotionEvent.AXIS_BRAKE)
        if (lRange != null && lRange.range > 1e-5f) {
            hasAnalogL2 = true
            l2Axis = lRange.axis
            l2RangeMin = lRange.min
            l2RangeSpan = lRange.range
        } else {
            hasAnalogL2 = false
        }

        val rRange = device.getMotionRange(MotionEvent.AXIS_RTRIGGER)
            ?: device.getMotionRange(MotionEvent.AXIS_GAS)
        if (rRange != null && rRange.range > 1e-5f) {
            hasAnalogR2 = true
            r2Axis = rRange.axis
            r2RangeMin = rRange.min
            r2RangeSpan = rRange.range
        } else {
            hasAnalogR2 = false
        }
    }

    private fun refreshConnectedGamepad() {
        val ids = inputManager.inputDeviceIds
        var foundDevice: InputDevice? = null
        for (id in ids) {
            val dev = inputManager.getInputDevice(id) ?: continue
            if (isGamepadSource(dev.sources) && !dev.isVirtual) {
                foundDevice = dev
                break
            }
        }
        activeGamepadConnected = foundDevice != null
        activeGamepadName = foundDevice?.name
        if (foundDevice != null) {
            configureTriggerRanges(foundDevice)
        } else {
            hasAnalogL2 = false
            hasAnalogR2 = false
        }
    }

    private fun resetGamepadInputState() {
        buttonsMask = 0
        hatX = 0
        hatY = 0
        dpadLeftDown = false
        dpadRightDown = false
        dpadUpDown = false
        dpadDownDown = false
        analogL2 = 0f
        analogR2 = 0f
        digitalL2Down = false
        digitalR2Down = false
        lxInt8 = 0
        lyInt8 = 0
        rxInt8 = 0
        ryInt8 = 0
        pushStateToHidAndUi()
    }

    override fun onDestroy() {
        inputManager.unregisterInputDeviceListener(this)
        try {
            unregisterReceiver(bluetoothStateReceiver)
        } catch (_: IllegalArgumentException) {
        }
        hidManager.shutdown()
        super.onDestroy()
    }
}
