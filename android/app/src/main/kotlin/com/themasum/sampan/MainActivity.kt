package com.themasum.sampan

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
import android.bluetooth.le.BluetoothLeScanner
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.net.Inet4Address
import java.net.NetworkInterface
import java.util.Collections
import java.util.concurrent.ConcurrentHashMap

class MainActivity : FlutterActivity(), SensorEventListener, LocationListener {
    private val channelName = "sampan.mesh/native"
    private val sampanManufacturerId = 0x5350 // 'S' 'P'
    private val permissionRequestCode = 5350

    private var sensorManager: SensorManager? = null
    private var locationManager: LocationManager? = null
    private var isListeningGnss = false
    private var latestGnssLocation: Location? = null

    private val gravity = FloatArray(3)
    private val geomagnetic = FloatArray(3)
    private var hasGravity = false
    private var hasMagnetic = false
    private var currentHeadingDegrees: Double = 0.0

    private var bleAdvertiser: BluetoothLeAdvertiser? = null
    private var bleScanner: BluetoothLeScanner? = null
    private var isScanning = false
    private var lastAdvertisingPayload: ByteArray? = null
    private val discoveredFrames = ConcurrentHashMap<String, Map<String, Any>>()

    private val advertiseCallback = object : AdvertiseCallback() {}

    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult?) {
            val scanResult = result ?: return
            val record = scanResult.scanRecord ?: return
            val mfgData = record.getManufacturerSpecificData(sampanManufacturerId)
            val frame28 = if (mfgData != null) {
                extractSampan28ByteFrame(mfgData, isManufacturerData = true)
            } else {
                val rawBytes = record.bytes ?: return
                extractSampan28ByteFrame(rawBytes, isManufacturerData = false)
            } ?: return

            val address = try {
                scanResult.device?.address ?: "ble-peer"
            } catch (_: Throwable) {
                "ble-peer"
            }
            discoveredFrames[address] = mapOf(
                "address" to address,
                "rssi" to scanResult.rssi,
                "payload" to frame28
            )
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        setupCompassSensor()
        startGnssLocationUpdates()

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getAppDataDir" -> {
                        try {
                            result.success(applicationContext.filesDir.absolutePath)
                        } catch (_: Throwable) {
                            result.success(null)
                        }
                    }
                    "getApkPath" -> {
                        try {
                            result.success(applicationContext.applicationInfo.sourceDir)
                        } catch (_: Throwable) {
                            result.success(null)
                        }
                    }
                    "getLocalIpAddresses" -> {
                        result.success(enumerateLocalIpv4Addresses())
                    }
                    "getSensorSnapshot" -> {
                        startGnssLocationUpdates()
                        result.success(readSensorAndGnssSnapshot())
                    }
                    "requestPermissions" -> {
                        result.success(requestMeshRuntimePermissions())
                    }
                    "startBleAdvertising" -> {
                        val payload = call.argument<ByteArray>("payload")
                        val started = if (payload != null) {
                            lastAdvertisingPayload = payload
                            startSampanBleAdvertising(payload)
                        } else {
                            false
                        }
                        ensureBleScannerRunning()
                        result.success(started)
                    }
                    "pollBleScanResults" -> {
                        ensureBleScannerRunning()
                        val list = ArrayList<Map<String, Any>>(discoveredFrames.values)
                        discoveredFrames.clear()
                        result.success(list)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Reconstructs the canonical 28-byte Sampan Telemetry Frame:
     * `[0x53, 0x50, 0x01, role(1B), lat(4B), lon(4B), speed(2B), key(14B)]`.
     *
     * When advertised via `addManufacturerData(0x5350, payload26)`, Android's
     * BLE stack transmits `0x5350` as the 2-byte Manufacturer ID and the
     * remaining 26 bytes as manufacturer-specific data so the total legacy BLE
     * advertisement PDU is 30 bytes (<= 31-byte BLE limit).
     */
    private fun extractSampan28ByteFrame(
        bytes: ByteArray,
        isManufacturerData: Boolean
    ): ByteArray? {
        if (isManufacturerData && bytes.size == 26 && bytes[0] == 0x01.toByte()) {
            val reconstructed = ByteArray(28)
            reconstructed[0] = 0x53.toByte()
            reconstructed[1] = 0x50.toByte()
            System.arraycopy(bytes, 0, reconstructed, 2, 26)
            return reconstructed
        }
        if (bytes.size == 28 &&
            bytes[0] == 0x53.toByte() &&
            bytes[1] == 0x50.toByte() &&
            bytes[2] == 0x01.toByte()
        ) {
            return bytes
        }
        if (bytes.size >= 28) {
            for (i in 0..(bytes.size - 28)) {
                val isBigEndianMagic =
                    bytes[i] == 0x53.toByte() && bytes[i + 1] == 0x50.toByte()
                val isLittleEndianMfgId =
                    bytes[i] == 0x50.toByte() && bytes[i + 1] == 0x53.toByte()
                if ((isBigEndianMagic || isLittleEndianMfgId) &&
                    bytes[i + 2] == 0x01.toByte()
                ) {
                    val out = bytes.copyOfRange(i, i + 28)
                    out[0] = 0x53.toByte()
                    out[1] = 0x50.toByte()
                    return out
                }
            }
        }
        return null
    }

    private fun requestMeshRuntimePermissions(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            startGnssLocationUpdates()
            ensureBleScannerRunning()
            return true
        }
        return try {
            val perms = mutableListOf(
                Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.ACCESS_COARSE_LOCATION
            )
            if (Build.VERSION.SDK_INT >= 31) {
                perms.add("android.permission.BLUETOOTH_SCAN")
                perms.add("android.permission.BLUETOOTH_ADVERTISE")
                perms.add("android.permission.BLUETOOTH_CONNECT")
            }
            if (Build.VERSION.SDK_INT >= 33) {
                perms.add("android.permission.NEARBY_WIFI_DEVICES")
            }
            val missing = perms.filter {
                checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED
            }
            if (missing.isNotEmpty()) {
                requestPermissions(missing.toTypedArray(), permissionRequestCode)
            } else {
                startGnssLocationUpdates()
                ensureBleScannerRunning()
                lastAdvertisingPayload?.let { startSampanBleAdvertising(it) }
            }
            true
        } catch (_: Throwable) {
            false
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == permissionRequestCode) {
            startGnssLocationUpdates()
            ensureBleScannerRunning()
            lastAdvertisingPayload?.let { startSampanBleAdvertising(it) }
        }
    }

    @SuppressLint("MissingPermission")
    private fun startSampanBleAdvertising(payload28Bytes: ByteArray): Boolean {
        return try {
            val btManager =
                getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
            val adapter: BluetoothAdapter? = btManager?.adapter
            if (adapter == null || !adapter.isEnabled) {
                return false
            }
            val advertiser = adapter.bluetoothLeAdvertiser ?: return false
            bleAdvertiser = advertiser
            advertiser.stopAdvertising(advertiseCallback)

            // Strip the 2-byte magic prefix (0x53, 0x50) because 0x5350 is passed
            // as the 2-byte BLE Manufacturer ID. This keeps the advertisement AD
            // structure at 2B (AD header) + 2B (0x5350) + 26B (body) = 30 bytes,
            // fitting cleanly inside the 31-byte legacy BLE PDU limit.
            val mfgPayload = if (payload28Bytes.size == 28 &&
                payload28Bytes[0] == 0x53.toByte() &&
                payload28Bytes[1] == 0x50.toByte()
            ) {
                payload28Bytes.copyOfRange(2, 28)
            } else {
                payload28Bytes
            }

            val settings = AdvertiseSettings.Builder()
                .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
                .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_HIGH)
                .setConnectable(false)
                .build()

            val data = AdvertiseData.Builder()
                .setIncludeDeviceName(false)
                .setIncludeTxPowerLevel(false)
                .addManufacturerData(sampanManufacturerId, mfgPayload)
                .build()

            advertiser.startAdvertising(settings, data, advertiseCallback)
            true
        } catch (_: SecurityException) {
            false
        } catch (_: Throwable) {
            false
        }
    }

    @SuppressLint("MissingPermission")
    private fun ensureBleScannerRunning() {
        if (isScanning) return
        try {
            val btManager =
                getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
            val adapter: BluetoothAdapter? = btManager?.adapter
            if (adapter == null || !adapter.isEnabled) return
            val scanner = adapter.bluetoothLeScanner ?: return
            bleScanner = scanner

            val settings = ScanSettings.Builder()
                .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
                .build()

            scanner.startScan(null, settings, scanCallback)
            isScanning = true
        } catch (_: SecurityException) {
            isScanning = false
        } catch (_: Throwable) {
            isScanning = false
        }
    }

    @SuppressLint("MissingPermission")
    private fun startGnssLocationUpdates() {
        if (isListeningGnss) return
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
                checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED &&
                checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED
            ) {
                return
            }
            val lm = getSystemService(Context.LOCATION_SERVICE) as? LocationManager ?: return
            locationManager = lm
            if (lm.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
                lm.requestLocationUpdates(
                    LocationManager.GPS_PROVIDER,
                    2000L,
                    1.0f,
                    this,
                    Looper.getMainLooper()
                )
                isListeningGnss = true
            }
            if (lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) {
                lm.requestLocationUpdates(
                    LocationManager.NETWORK_PROVIDER,
                    4000L,
                    2.0f,
                    this,
                    Looper.getMainLooper()
                )
                isListeningGnss = true
            }
        } catch (_: SecurityException) {
            isListeningGnss = false
        } catch (_: Throwable) {
            isListeningGnss = false
        }
    }

    override fun onLocationChanged(location: Location) {
        latestGnssLocation = location
    }

    @Deprecated("Deprecated in Android API")
    override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
    override fun onProviderEnabled(provider: String) {}
    override fun onProviderDisabled(provider: String) {}

    private fun setupCompassSensor() {
        try {
            sensorManager = getSystemService(Context.SENSOR_SERVICE) as? SensorManager
            val accel = sensorManager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
            val mag = sensorManager?.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD)
            if (accel != null) {
                sensorManager?.registerListener(this, accel, SensorManager.SENSOR_DELAY_UI)
            }
            if (mag != null) {
                sensorManager?.registerListener(this, mag, SensorManager.SENSOR_DELAY_UI)
            }
        } catch (_: Throwable) {
        }
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (event == null) return
        if (event.sensor.type == Sensor.TYPE_ACCELEROMETER) {
            System.arraycopy(event.values, 0, gravity, 0, 3)
            hasGravity = true
        } else if (event.sensor.type == Sensor.TYPE_MAGNETIC_FIELD) {
            System.arraycopy(event.values, 0, geomagnetic, 0, 3)
            hasMagnetic = true
        }
        if (hasGravity && hasMagnetic) {
            val r = FloatArray(9)
            val i = FloatArray(9)
            if (SensorManager.getRotationMatrix(r, i, gravity, geomagnetic)) {
                val orientation = FloatArray(3)
                SensorManager.getOrientation(r, orientation)
                val azimuthRad = orientation[0].toDouble()
                val deg = (Math.toDegrees(azimuthRad) + 360.0) % 360.0
                currentHeadingDegrees = deg
            }
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    @SuppressLint("MissingPermission")
    override fun onDestroy() {
        try {
            sensorManager?.unregisterListener(this)
            if (isListeningGnss) {
                locationManager?.removeUpdates(this)
                isListeningGnss = false
            }
            bleAdvertiser?.stopAdvertising(advertiseCallback)
            if (isScanning) {
                bleScanner?.stopScan(scanCallback)
                isScanning = false
            }
        } catch (_: Throwable) {
        }
        super.onDestroy()
    }

    private fun enumerateLocalIpv4Addresses(): List<String> {
        val addresses = mutableListOf<String>()
        try {
            val interfaces = NetworkInterface.getNetworkInterfaces() ?: return addresses
            for (intf in Collections.list(interfaces)) {
                if (!intf.isUp || intf.isLoopback) continue
                for (addr in Collections.list(intf.inetAddresses)) {
                    if (!addr.isLoopbackAddress && addr is Inet4Address) {
                        val host = addr.hostAddress
                        if (!host.isNullOrEmpty()) {
                            addresses.add(host)
                        }
                    }
                }
            }
        } catch (_: Throwable) {
        }
        return addresses
    }

    @SuppressLint("MissingPermission")
    private fun readSensorAndGnssSnapshot(): Map<String, Any> {
        var lat = 21.4272
        var lon = 91.9702
        var speed = 0.0
        var hasFix = false
        try {
            val lm = locationManager
                ?: (getSystemService(Context.LOCATION_SERVICE) as? LocationManager)
            val gpsLoc: Location? = latestGnssLocation
                ?: lm?.getLastKnownLocation(LocationManager.GPS_PROVIDER)
                ?: lm?.getLastKnownLocation(LocationManager.NETWORK_PROVIDER)
            if (gpsLoc != null) {
                lat = gpsLoc.latitude
                lon = gpsLoc.longitude
                speed = gpsLoc.speed.toDouble()
                hasFix = true
            }
        } catch (_: SecurityException) {
        } catch (_: Throwable) {
        }

        return mapOf(
            "headingDegrees" to currentHeadingDegrees,
            "latitude" to lat,
            "longitude" to lon,
            "speedMps" to speed,
            "isCalibrated" to (hasGravity && hasMagnetic),
            "hasGpsFix" to hasFix
        )
    }
}
