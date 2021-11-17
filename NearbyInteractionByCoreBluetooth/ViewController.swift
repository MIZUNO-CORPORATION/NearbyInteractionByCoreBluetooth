//
//  ViewController.swift
//  NearbyInteractionByCoreBluetooth
//
//  Created by AM2190 on 2021/11/17.
//

import UIKit
import CoreBluetooth
import NearbyInteraction

class ViewController: UIViewController {
    // MARK: - NearbyInteraction variables
    var niSession: NISession?
    var iPhoneTokenData: Data?
    
    // MARK: - CoreBluetooth variables
    var peripheralManager: CBPeripheralManager!
    let tokenServiceUUID: CBUUID = CBUUID(string:"2AC0B600-7C0C-4C9D-AB71-072AE2037107")
    let appleWatchTokenCharacteristicUUID: CBUUID = CBUUID(string:"2AC0B601-7C0C-4C9D-AB71-072AE2037107")
    let iPhoneTokenCharacteristicUUID: CBUUID = CBUUID(string:"2AC0B602-7C0C-4C9D-AB71-072AE2037107")
    var tokenService: CBMutableService?
    var appleWatchTokenCharacteristic: CBMutableCharacteristic?
    var iPhoneTokenCharacteristic: CBMutableCharacteristic?

    // MARK: - CSV File instances
    var file: File!
    
    // MARK: - IBOutlet instances
    @IBOutlet weak var stateLabel: UILabel!
    @IBOutlet weak var distanceLabel: UILabel!
    @IBOutlet weak var directionXLabel: UILabel!
    @IBOutlet weak var directionYLabel: UILabel!
    @IBOutlet weak var directionZLabel: UILabel!
    
    // MARK: - UI lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupNearbyInteraction()
        setupCoreBluetooth()
        file = File.shared
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        peripheralManager.stopAdvertising()
        super.viewWillDisappear(animated)
    }
    
    // MARK: - Initial setting
    func setupNearbyInteraction() {
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
        iPhoneTokenData = try! NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
    }
    
    func setupCoreBluetooth() {
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
        
        appleWatchTokenCharacteristic = CBMutableCharacteristic(type: appleWatchTokenCharacteristicUUID, properties: [.write], value: nil, permissions: [.writeable])
        iPhoneTokenCharacteristic = CBMutableCharacteristic(type: iPhoneTokenCharacteristicUUID, properties: [.read], value: iPhoneTokenData, permissions: [.readable])
        
        tokenService = CBMutableService(type: tokenServiceUUID, primary: true)
        tokenService?.characteristics = [appleWatchTokenCharacteristic!, iPhoneTokenCharacteristic!]
    }

}

// MARK: - NISessionDelegate
extension ViewController: NISessionDelegate {
    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        var stringData = ""
        
        // The session runs with one accessory.
        guard let accessory = nearbyObjects.first else { return }

        // Retrieve the accessory's distance, in meters.
        if let distance = accessory.distance {
            distanceLabel.text = distance.description
            stringData += distance.description
            print(distance.description)
        }else {
            distanceLabel.text = "-"
        }
        stringData += ","
        
        if let direction = accessory.direction {
            directionXLabel.text = direction.x.description
            directionYLabel.text = direction.y.description
            directionZLabel.text = direction.z.description
            
            stringData += direction.x.description + ","
            stringData += direction.y.description + ","
            stringData += direction.z.description
            print(direction.description)
        }else {
            directionXLabel.text = "-"
            directionYLabel.text = "-"
            directionZLabel.text = "-"
        }
        
        stringData += "\n"
        file.addDataToFile(rowString: stringData)

    }
    
    func session(_ session: NISession, didInvalidateWith error: Error) {
        print(error)
    }
}

// MARK: - CBPeripheralManagerDelegate
extension ViewController: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .poweredOn:
            print("CBManager state is powered on")
            peripheralManager.add(tokenService!)
            peripheralManager.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [tokenServiceUUID]])
            
            stateLabel.text = "CoreBluetooth is start advertising"
        default:
            print("CBManager state is \(peripheral.state)")
            return
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        if request.characteristic.uuid.isEqual(iPhoneTokenCharacteristicUUID) {
            if let value = iPhoneTokenCharacteristic?.value {
                if request.offset > value.count {
                    peripheral.respond(to: request, withResult: CBATTError.invalidOffset)
                    print("Read fail: invalid offset")
                    return
                }
                request.value = value.subdata(in: Range(uncheckedBounds: (request.offset, value.count)))
                peripheral.respond(to: request, withResult: CBATTError.success)
            }
        }else {
            print("Read fail: wrong characteristic uuid:", request.characteristic.uuid)
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            if request.characteristic.uuid.isEqual(appleWatchTokenCharacteristicUUID) {
                guard let value = request.value else {
                    print("characteristic's value is nil")
                    return
                }
                appleWatchTokenCharacteristic?.value = value
                peripheralManager.respond(to: request, withResult: CBATTError.success)
                
                guard let appleWatchToken = try! NSKeyedUnarchiver.unarchivedObject(ofClass: NIDiscoveryToken.self, from: value) else {
                    print("AppleWatch's DiscoverToken is nil")
                    return
                }
                let config = NINearbyPeerConfiguration(peerToken: appleWatchToken)
                niSession?.run(config)
                
                file.createFile(connectedDeviceName: "AppleWatch")
                print("NearbyInteraction session is running")
                stateLabel.text = "NearbyInteraction Session is start running"
            }else {
                print("Read fail: wrong characteristic uuid:", request.characteristic.uuid)
            }
        }
    }
}

