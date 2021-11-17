//
//  InterfaceController.swift
//  NearbyInteractionByCoreBluetooth WatchKit Extension
//
//  Created by AM2190 on 2021/11/17.
//

import WatchKit
import Foundation
import CoreBluetooth
import NearbyInteraction

class InterfaceController: WKInterfaceController {
    // MARK: - NearbyInteraction variables
    var niSession: NISession?
    var appleWatchTokenData: Data?
    
    // MARK: - CoreBluetooth variables
    var centralManager: CBCentralManager!
    var discoveredPeripheral: CBPeripheral!
    let tokenServiceUUID: CBUUID = CBUUID(string:"2AC0B600-7C0C-4C9D-AB71-072AE2037107")
    let appleWatchTokenCharacteristicUUID: CBUUID = CBUUID(string:"2AC0B601-7C0C-4C9D-AB71-072AE2037107")
    let iPhoneTokenCharacteristicUUID: CBUUID = CBUUID(string:"2AC0B602-7C0C-4C9D-AB71-072AE2037107")
    
    // MARK: - IBOutlet instances
    @IBOutlet weak var deviceNameLabel: WKInterfaceLabel!
    @IBOutlet weak var distanceLabel: WKInterfaceLabel!
    
    // MARK: - UI lifecycle
    override func awake(withContext context: Any?) {
        setupNearbyInteraction()
        setupCoreBluetooth()
    }
    
    // MARK: - Initial setting
    func setupNearbyInteraction () {
        // Check if Nearby Interaction is supported.
        guard NISession.isSupported else {
            print("This device doesn't support Nearby Interaction.")
            return
        }
        
        // Set the NISession.
        niSession = NISession()
        niSession?.delegate = self
        
        // Create a token and change Data type.
        guard let token = niSession?.discoveryToken else {
            return
        }
        appleWatchTokenData = try! NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
    }
    
    func setupCoreBluetooth() {
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
}

// MARK: - NISessionDelegate
extension InterfaceController: NISessionDelegate {
    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        // The session runs with one accessory.
        guard let accessory = nearbyObjects.first else { return }

        // Retrieve the accessory's distance, in meters.
        if let distance = accessory.distance {
            distanceLabel.setText(distance.description)
        }else {
            distanceLabel.setText("-")
        }
    }
    
    func session(_ session: NISession, didInvalidateWith error: Error) {
        print(error)
    }
}

// MARK: - CBCentralManagerDelegate
extension InterfaceController: CBCentralManagerDelegate{
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("CBManager state is powered on")
            central.scanForPeripherals(withServices: [tokenServiceUUID])
            
        default:
            print("CBManager state is \(central.state)")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        discoveredPeripheral = peripheral
        central.stopScan()
        central.connect(peripheral, options: nil)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices([tokenServiceUUID])
        
        deviceNameLabel.setText(peripheral.name)
    }
}

// MARK: - CBPeripheralDelegate
extension InterfaceController: CBPeripheralDelegate{
    
    // Called when services are discovered
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else {
            return
        }
        print(services)
        for service in services {
            peripheral.discoverCharacteristics([appleWatchTokenCharacteristicUUID, iPhoneTokenCharacteristicUUID], for: service)
        }
    }
    
    // Called when characteristics are discovered
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if error != nil {
            print(error.debugDescription)
            return
        }
        
        guard let characteristics = service.characteristics else {
            return
        }
        print(characteristics)
        for characteristic in characteristics {
            if characteristic.uuid.isEqual(appleWatchTokenCharacteristicUUID) {
                peripheral.writeValue(appleWatchTokenData!, for: characteristic, type: .withResponse)
                
            }else if characteristic.uuid.isEqual(iPhoneTokenCharacteristicUUID) {
                peripheral.readValue(for: characteristic)
                
            }else {
                print("Other characteristic is " + characteristic.description)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if error != nil {
            print(error.debugDescription)
            return
        }
        
        if characteristic.uuid.isEqual(iPhoneTokenCharacteristicUUID) {
            guard let value = characteristic.value else {
                print("characteristic's value is nil")
                return
            }
            guard let iPhoneToken = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NIDiscoveryToken.self, from: value) else {
                print("iPhone's DiscoverToken is nil")
                return
            }
            let config = NINearbyPeerConfiguration(peerToken: iPhoneToken)
            niSession?.run(config)
            
            print("NearbyInteraction session is running")
        }
    }
}

