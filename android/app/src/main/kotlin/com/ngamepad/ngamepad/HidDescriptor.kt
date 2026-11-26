package com.ngamepad.ngamepad

import kotlin.math.roundToInt

/**
 * Standard USB/Bluetooth HID Gamepad Report Descriptor & 9-byte Report Packer.
 *
 * Report ID: 0x01 (passed separately to BluetoothHidDevice.sendReport)
 * Report Payload Layout (9 bytes total):
 * ┌───────┬──────────────────────────────────────────────────────────────────┐
 * │ Byte  │ Content                                                          │
 * ├───────┼──────────────────────────────────────────────────────────────────┤
 * │ 0     │ Buttons 1..8  (bit 0=A, 1=B, 2=X, 3=Y, 4=L1, 5=R1, 6=L2, 7=R2)   │
 * │ 1     │ Buttons 9..16 (bit 0=Select, 1=Start, 2=L3, 3=R3, 4=Home, 5..7)  │
 * │ 2     │ Low nibble (bits 0..3): 8-way Hat Switch (0=N..7=NW, 8=Center)   │
 * │       │ High nibble (bits 4..7): Constant 4-bit padding (0)              │
 * │ 3     │ Left Stick X   (signed int8: -127 .. 127)                        │
 * │ 4     │ Left Stick Y   (signed int8: -127 .. 127)                        │
 * │ 5     │ Right Stick X  (signed int8: -127 .. 127, HID Usage Z)           │
 * │ 6     │ Right Stick Y  (signed int8: -127 .. 127, HID Usage Rz)          │
 * │ 7     │ Left Trigger   (unsigned uint8: 0 .. 255, HID Usage Rx)          │
 * │ 8     │ Right Trigger  (unsigned uint8: 0 .. 255, HID Usage Ry)          │
 * └───────┴──────────────────────────────────────────────────────────────────┘
 */
object HidDescriptor {
    const val REPORT_ID: Int = 1
    const val REPORT_SIZE: Int = 9

    // Button bitmask indices (0..15)
    const val BTN_A: Int = 0
    const val BTN_B: Int = 1
    const val BTN_X: Int = 2
    const val BTN_Y: Int = 3
    const val BTN_L1: Int = 4
    const val BTN_R1: Int = 5
    const val BTN_L2: Int = 6
    const val BTN_R2: Int = 7
    const val BTN_SELECT: Int = 8
    const val BTN_START: Int = 9
    const val BTN_L3: Int = 10
    const val BTN_R3: Int = 11
    const val BTN_HOME: Int = 12
    const val BTN_EXTRA1: Int = 13
    const val BTN_EXTRA2: Int = 14
    const val BTN_EXTRA3: Int = 15

    // Hat switch values (0..7 = N, NE, E, SE, S, SW, W, NW; 8 = Null/Centered)
    const val HAT_CENTER: Int = 8

    val DESCRIPTOR: ByteArray = byteArrayOf(
        0x05.toByte(), 0x01.toByte(), // Usage Page (Generic Desktop Controls)
        0x09.toByte(), 0x05.toByte(), // Usage (Game Pad)
        0xA1.toByte(), 0x01.toByte(), // Collection (Application)
        0x85.toByte(), REPORT_ID.toByte(), // Report ID (1)

        // --- 16 Buttons (Bytes 0..1) ---
        0x05.toByte(), 0x09.toByte(), // Usage Page (Button)
        0x19.toByte(), 0x01.toByte(), // Usage Minimum (Button 1)
        0x29.toByte(), 0x10.toByte(), // Usage Maximum (Button 16)
        0x15.toByte(), 0x00.toByte(), // Logical Minimum (0)
        0x25.toByte(), 0x01.toByte(), // Logical Maximum (1)
        0x75.toByte(), 0x01.toByte(), // Report Size (1 bit)
        0x95.toByte(), 0x10.toByte(), // Report Count (16)
        0x81.toByte(), 0x02.toByte(), // Input (Data, Variable, Absolute)

        // --- 8-way Hat Switch + 4-bit Padding (Byte 2) ---
        0x05.toByte(), 0x01.toByte(), // Usage Page (Generic Desktop Controls)
        0x09.toByte(), 0x39.toByte(), // Usage (Hat switch)
        0x15.toByte(), 0x00.toByte(), // Logical Minimum (0)
        0x25.toByte(), 0x07.toByte(), // Logical Maximum (7)
        0x35.toByte(), 0x00.toByte(), // Physical Minimum (0)
        0x46.toByte(), 0x3B.toByte(), 0x01.toByte(), // Physical Maximum (315)
        0x65.toByte(), 0x14.toByte(), // Unit (English Rotation: Degrees)
        0x75.toByte(), 0x04.toByte(), // Report Size (4 bits)
        0x95.toByte(), 0x01.toByte(), // Report Count (1)
        0x81.toByte(), 0x42.toByte(), // Input (Data, Variable, Absolute, Null State)

        // Reset global Unit/Physical items before analog axes
        0x65.toByte(), 0x00.toByte(), // Unit (None)
        0x35.toByte(), 0x00.toByte(), // Physical Minimum (0)
        0x45.toByte(), 0x00.toByte(), // Physical Maximum (0)
        0x75.toByte(), 0x04.toByte(), // Report Size (4 bits)
        0x95.toByte(), 0x01.toByte(), // Report Count (1)
        0x81.toByte(), 0x01.toByte(), // Input (Constant, Array, Absolute) - padding

        // --- 4 Analog Stick Axes: X, Y, Z (RX), Rz (RY) (Bytes 3..6) ---
        0x09.toByte(), 0x30.toByte(), // Usage (X)  -> Left Stick X
        0x09.toByte(), 0x31.toByte(), // Usage (Y)  -> Left Stick Y
        0x09.toByte(), 0x32.toByte(), // Usage (Z)  -> Right Stick X
        0x09.toByte(), 0x35.toByte(), // Usage (Rz) -> Right Stick Y
        0x15.toByte(), 0x81.toByte(), // Logical Minimum (-127)
        0x25.toByte(), 0x7F.toByte(), // Logical Maximum (127)
        0x75.toByte(), 0x08.toByte(), // Report Size (8 bits)
        0x95.toByte(), 0x04.toByte(), // Report Count (4)
        0x81.toByte(), 0x02.toByte(), // Input (Data, Variable, Absolute)

        // --- 2 Analog Trigger Axes: Rx (L2), Ry (R2) (Bytes 7..8) ---
        0x09.toByte(), 0x33.toByte(), // Usage (Rx) -> Left Trigger (L2)
        0x09.toByte(), 0x34.toByte(), // Usage (Ry) -> Right Trigger (R2)
        0x15.toByte(), 0x00.toByte(), // Logical Minimum (0)
        0x26.toByte(), 0xFF.toByte(), 0x00.toByte(), // Logical Maximum (255, 2-byte unsigned)
        0x75.toByte(), 0x08.toByte(), // Report Size (8 bits)
        0x95.toByte(), 0x02.toByte(), // Report Count (2)
        0x81.toByte(), 0x02.toByte(), // Input (Data, Variable, Absolute)

        0xC0.toByte() // End Collection
    )

    /**
     * Thread-safe mutable snapshot of the latest gamepad state, packed into [REPORT_SIZE] bytes.
     */
    data class GamepadInputState(
        var buttons: Int = 0,
        var hat: Int = HAT_CENTER,
        var lx: Int = 0, // -127..127
        var ly: Int = 0, // -127..127
        var rx: Int = 0, // -127..127
        var ry: Int = 0, // -127..127
        var l2: Int = 0, // 0..255
        var r2: Int = 0, // 0..255
    ) {
        fun packInto(out: ByteArray) {
            require(out.size >= REPORT_SIZE)
            out[0] = (buttons and 0xFF).toByte()
            out[1] = ((buttons ushr 8) and 0xFF).toByte()
            out[2] = (hat and 0x0F).toByte()
            out[3] = lx.coerceIn(-127, 127).toByte()
            out[4] = ly.coerceIn(-127, 127).toByte()
            out[5] = rx.coerceIn(-127, 127).toByte()
            out[6] = ry.coerceIn(-127, 127).toByte()
            out[7] = l2.coerceIn(0, 255).toByte()
            out[8] = r2.coerceIn(0, 255).toByte()
        }

        fun toTelemetryMap(
            usbDeviceName: String?,
            usbConnected: Boolean,
        ): Map<String, Any?> {
            return mapOf(
                "buttons" to buttons,
                "hat" to hat,
                "lx" to lx,
                "ly" to ly,
                "rx" to rx,
                "ry" to ry,
                "l2" to l2,
                "r2" to r2,
                "usbConnected" to usbConnected,
                "usbDeviceName" to usbDeviceName,
            )
        }
    }

    /**
     * Maps normalized (-1/0/1) X/Y hat or D-pad inputs into the 8-way HID Hat Switch value.
     */
    fun computeHat(x: Int, y: Int): Int {
        return when {
            x == 0 && y < 0 -> 0 // North
            x > 0 && y < 0 -> 1  // North-East
            x > 0 && y == 0 -> 2 // East
            x > 0 && y > 0 -> 3  // South-East
            x == 0 && y > 0 -> 4 // South
            x < 0 && y > 0 -> 5  // South-West
            x < 0 && y == 0 -> 6 // West
            x < 0 && y < 0 -> 7  // North-West
            else -> HAT_CENTER
        }
    }

    /**
     * Converts a normalized axis (-1.0..1.0) to signed 8-bit (-127..127).
     */
    fun axisToInt8(value: Float): Int {
        return (value.coerceIn(-1f, 1f) * 127f).roundToInt().coerceIn(-127, 127)
    }

    /**
     * Converts a normalized trigger (0.0..1.0) to unsigned 8-bit (0..255).
     */
    fun triggerToUInt8(value: Float): Int {
        return (value.coerceIn(0f, 1f) * 255f).roundToInt().coerceIn(0, 255)
    }
}
