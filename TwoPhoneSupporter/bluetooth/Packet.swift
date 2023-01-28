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
    case clearDevice = 0x02
    case notification = 0x10
}

extension PacketType {
    func createPacketData(_ data: Data) -> Data {
        let size = Int32(Packet.sizeSize + Packet.typeSize + data.count)
        var result = withUnsafeBytes(of: Int16(size)) { Data($0) }
        result.append(withUnsafeBytes(of: rawValue) { Data($0) })
        result.append(data)
        return result
    }
}

class Packet {
    fileprivate static let sizeSize = 2
    fileprivate static let typeSize = 2
    
    let type: PacketType
    let data: Data
    
    var count: Int {
        get {
            Packet.sizeSize + Packet.typeSize + data.count
        }
    }
    
    init?(data: Data) {
        if data.count < Packet.sizeSize {
            return nil
        }
        guard let size = try? data.subdata(in: 0..<Packet.sizeSize).toShort() else {
            return nil
        }
        if data.count < size {
            return nil
        }
        guard let packetTypeShort = try? data.subdata(in: Packet.sizeSize..<Packet.sizeSize+Packet.typeSize).toShort() else {
            return nil
        }
        guard let packetType = PacketType.init(rawValue: packetTypeShort) else {
            return nil
        }
        
        self.type = packetType
        self.data = data.subdata(in: Packet.sizeSize+Packet.typeSize..<Data.Index(size))
    }
}

extension Data {
    func toShort() throws -> Int16 {
        if (count != 2) {
            throw PeripheralError.illegalDataError
        }
        return withUnsafeBytes { rawPtr in
            return rawPtr.load(as: Int16.self)
        }
    }
}
