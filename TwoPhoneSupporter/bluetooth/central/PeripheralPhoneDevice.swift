//
//  PeripheralPhoneDevice.swift
//  TwoPhoneSupporter
//
//  Created by Jaehong Yoo on 2023/01/22.
//

import Foundation
import AlgorigoBleLibrary
import RxSwift
import RxRelay
import CoreBluetooth

enum PeripheralError : Error {
    case versionMatchError
    case deviceUnregisteredError
    case illegalOperatingSystem
    case illegalDataError
}

enum OperatingSystem : UInt8 {
    case android = 0x00
    case iOS = 0x01
}

class PeripheralPhoneDevice : InitializableBleDevice {
    
    fileprivate static let version: Int32 = 0x01
    fileprivate static let peripheralUserDefaultKey = "PeripheralUserDefaultKey"
    static let mainService = "6E400001-B5A3-F393-E0A9-0123456789AB"
    static let writeCharacteristic = "6E400002-B5A3-F393-E0A9-0123456789AB"
    static let notifyCharacteristic = "6E400003-B5A3-F393-E0A9-0123456789AB"
    
    private var deviceCheckUuid: String!
    private var operatingSystem: OperatingSystem!
    
    private var dataDisposable: Disposable? = nil
    private var receivedPacketRelay = PublishRelay<Packet>()
    
    required init(_ peripheral: CBPeripheral) {
        super.init(peripheral)
        let key = getPeripheralUserDefaultKey(peripheral.identifier.uuidString)
        if let deviceCheckUuidString = UserDefaults.standard.string(forKey: key) {
            deviceCheckUuid = deviceCheckUuidString
        } else {
            deviceCheckUuid = UUID().uuidString
            UserDefaults.standard.set(deviceCheckUuid, forKey: key)
        }
    }
    
    override func initialzeCompletable() -> Completable {
        return checkVersion()
            .andThen(checkDevice())
            .do(onSubscribe: { [weak self] in
                self?.dataDisposable = self?.setupNotification(uuid: PeripheralPhoneDevice.notifyCharacteristic)
                    .flatMap { $0 }
                    .scan(Data(), accumulator: { [weak self] prev, newData in
                        var result = Data(prev)
                        result.append(newData)
                        while true {
                            guard let packet = Packet.init(data: result) else {
                                break
                            }
                            self?.receivedPacketRelay.accept(packet)
                            result = result.subdata(in: packet.count..<result.count)
                        }
                        return result
                    })
                    .subscribe { [weak self] event in
                        switch event {
                        case .next(let data):
                            print("setupNotification next:\(data)")
                        case .error(let error):
                            print("setupNotification error:\(error)")
                            self?.disconnect()
                        case .completed:
                            print("setupNotification completed")
                        }
                    }
            })
    }
    
    private func sendPacket(uuid: String, packetType: PacketType, data: Data) -> Single<Data> {
        let packet = packetType.createPacketData(data)
        let writeDataSingle = writeCharacteristic(uuid: uuid, data: packet)
        let receiveDataSingle = receivedPacketRelay
            .filter { packet in
                packet.type == packetType
            }
            .map({ packet in
                packet.data
            })
            .firstOrError()
                
        return Single.zip(writeDataSingle, receiveDataSingle) { writeResult, receivedData in
            receivedData
        }
    }
    
    private func checkVersion() -> Completable {
        return sendPacket(uuid: PeripheralPhoneDevice.writeCharacteristic,
                          packetType: PacketType.checkVersion,
                          data: withUnsafeBytes(of: PeripheralPhoneDevice.version) { Data($0) })
            .map { data in
                data.toUInt8Array()[0]
            }
            .do(onSuccess: { byte in
                if byte != 0x01 {
                    throw PeripheralError.versionMatchError
                }
            })
            .asCompletable()
    }
    
    private func checkDevice() -> Completable {
        return Single<Data>.create { [weak self] observer in
            guard let this = self else {
                observer(.failure(RxError.noElements))
                return Disposables.create()
            }
            
            let json: [String : Any] = [
                "uuid": this.deviceCheckUuid!,
                "os": OperatingSystem.iOS.rawValue,
            ]
            
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: json, options: .sortedKeys)
                observer(.success(jsonData))
            } catch {
                observer(.failure(error))
            }
            
            return Disposables.create()
        }
            .flatMap { [weak self] data in
                self?.sendPacket(uuid: PeripheralPhoneDevice.writeCharacteristic,
                                 packetType: PacketType.checkDevice,
                                 data: data)
                ?? Single.error(RxError.unknown)
            }
            .map { data in
                try JSONSerialization.jsonObject(with: data) as! [String: Any]
            }
            .do(onSuccess: { [weak self] json in
                if json["vaildDevice"] as? Bool != true {
                    throw PeripheralError.deviceUnregisteredError
                }
                if let operatingSystemRawValue = json["os"] as? UInt8,
                   let operatingSystem = OperatingSystem(rawValue: operatingSystemRawValue) {
                    self?.operatingSystem = operatingSystem
                } else {
                    throw PeripheralError.illegalOperatingSystem
                }
            })
            .asCompletable()
    }
    
    func subscribeData() -> Observable<Packet> {
        return receivedPacketRelay.asObservable()
    }
    
    private func getPeripheralUserDefaultKey(_ uuidString: String) -> String {
        return PeripheralPhoneDevice.peripheralUserDefaultKey + uuidString
    }
}

extension Data {
    func toUInt8Array() -> [UInt8] {
        withUnsafeBytes { pointer in
            [UInt8](pointer)
        }
    }
}
