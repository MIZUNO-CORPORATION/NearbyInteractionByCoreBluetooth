//
//  File.swift
//  NearbyInteractionByCoreBluetooth
//
//  Created by AM2190 on 2021/11/17.
//

import Foundation

class File: NSObject {
    var realtimeDataStream: OutputStream!
    let formatter = DateFormatter()
    
    //シングルトンパターン
    static let shared = File()
    override init(){
        formatter.dateFormat = "HH:mm:ss.SSS"
    }
    
    // MARK: - To save heart rate data
    func createFile(connectedDeviceName: String) {
        //リアルタイムに取得した距離・方向データからCSVを作成する（作成時刻とデバイス名がファイル名に含まれる）
        let filePath = NSHomeDirectory() + "/Documents/" + File.getNowString() + "_" + connectedDeviceName + "_NearbyInteraction.csv"
        print(filePath)
        
        realtimeDataStream = OutputStream(toFileAtPath: filePath, append: true)!
        realtimeDataStream.open()
        let text: String = "Time,Distance[m],Direction_x,Direction_y,Direction_z\n"
        guard let data = text.data(using: .utf8) else { return }
        data.withUnsafeBytes { realtimeDataStream.write($0, maxLength: data.count)}
    }
    
    func addDataToFile(rowString: String) {
        let now = Date()
        let nowString = formatter.string(from: now)
        guard let data = (nowString + ", " + rowString).data(using: .utf8) else { return }
        data.withUnsafeBytes { realtimeDataStream.write($0, maxLength: data.count)}
    }
    
    func closeFile() {
        realtimeDataStream.close()
    }
    
    // MARK: - To get the current time
    static func getNowString() -> String {
        //iPhoneの現在の時刻をセットする
        let now = Date()
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        
        let string = formatter.string(from: now)
        return string
    }
}
