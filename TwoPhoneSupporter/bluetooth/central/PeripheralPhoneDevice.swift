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
    case deviceUnregisteredError
    case illegalDataError
}

class PeripheralPhoneDevice : InitializableBleDevice {
    
    fileprivate static let peripheralUserDefaultKey = "PeripheralUserDefaultKey"
    static let mainService = "6E400001-B5A3-F393-E0A9-0123456789AB"
    static let writeCharacteristic = "6E400002-B5A3-F393-E0A9-0123456789AB"
    static let notifyCharacteristic = "6E400003-B5A3-F393-E0A9-0123456789AB"
    
    private var deviceCheckUuid: String!
    private var dataDisposable: Disposable? = nil
    private var receivedPacketRelay = PublishRelay<Packet>()
    
    required init(_ peripheral: CBPeripheral) {
        super.init(peripheral)
        if let deviceCheckUuidString = UserDefaults.standard.string(forKey: getPeripheralUserDefaultKey(peripheral.identifier.uuidString)) {
            deviceCheckUuid = deviceCheckUuidString
        } else {
            deviceCheckUuid = UUID().uuidString
        }
    }
    
    override func initialzeCompletable() -> Completable {
        return checkDevice()
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
    
    private func checkDevice() -> Completable {
        let data = PacketType.checkDevice.createPacketData(deviceCheckUuid.data(using: .utf8)!)
        let writeDataObservable = writeCharacteristic(uuid: PeripheralPhoneDevice.writeCharacteristic, data: data)
            .asObservable()
            .ignoreElements()
        let receiveDataObservable = receivedPacketRelay
            .filter { packet in
                packet.type == .checkDevice
            }
            .do(onNext: { packet in
                let bytes = packet.data.withUnsafeBytes {
                    [UInt8](UnsafeBufferPointer(start: $0, count: packet.data.count))
                }
                if bytes[0] != 0x01 {
                    throw PeripheralError.deviceUnregisteredError
                }
            })
            .firstOrError()
            .asObservable()
            .ignoreElements()
        
        return Observable.of(writeDataObservable, receiveDataObservable)
                .merge()
                .asCompletable()
    }
    
    func subscribeData() -> Observable<Packet> {
        return receivedPacketRelay.asObservable()
    }
    
    private func getPeripheralUserDefaultKey(_ uuidString: String) -> String {
        return PeripheralPhoneDevice.peripheralUserDefaultKey + uuidString
    }
}
