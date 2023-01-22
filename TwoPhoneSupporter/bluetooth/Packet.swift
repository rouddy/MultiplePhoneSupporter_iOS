//
//  Packet.swift
//  TwoPhoneSupporter
//
//  Created by Jaehong Yoo on 2023/01/23.
//

import Foundation

enum PacketType : Int16 {
    case checkVersion = 0x00
    case checkDevice = 0x01
    case notification = 0x10
}

extension PacketType {
    fileprivate static let dataSize = 4
    fileprivate static let typeSize = 2
    
    func createPacketData(_ data: Data) -> Data {
        let size = Int32(4 + 2 + data.count)
        var result = withUnsafeBytes(of: size) { Data($0) }
        result.append(withUnsafeBytes(of: rawValue) { Data($0) })
        result.append(data)
        return result
    }
}

class Packet {
    let type: PacketType
    let data: Data
    
    var count: Int {
        get {
            6 + data.count
        }
    }
    
    init?(data: Data) {
        if data.count < 4 {
            return nil
        }
        guard let size = try? data.subdata(in: 0..<4).toInt() else {
            return nil
        }
        if data.count < size {
            return nil
        }
        guard let packetTypeShort = try? data.subdata(in: 4..<6).toShort() else {
            return nil
        }
        guard let packetType = PacketType.init(rawValue: packetTypeShort) else {
            return nil
        }
        
        self.type = packetType
        self.data = data.subdata(in: 6..<Data.Index(size))
    }
}
