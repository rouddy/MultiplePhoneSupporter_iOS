//
//  BluetoothService.swift
//  TwoPhoneSupporter
//
//  Created by Jaehong Yoo on 2023/01/28.
//

import Foundation
import RxSwift
import RxRelay
import AlgorigoBleLibrary

class BluetoothService {
    
    private static let keyStoredDevice = "KeyStoredDevice"
    
    static let instance = BluetoothService()
    
    private let disposeBag = DisposeBag()
    private let connectDeviceRelay = PublishRelay<PeripheralPhoneDevice>()
    private let disconnectDeviceRelay = PublishRelay<PeripheralPhoneDevice>()
    
    private var uuidStrings: [String] {
        get {
            UserDefaults.standard.stringArray(forKey: BluetoothService.keyStoredDevice) ?? []
        }
        set(field) {
            UserDefaults.standard.set(field, forKey: BluetoothService.keyStoredDevice)
        }
    }
    
    private init() {
        connectDeviceRelay
            .filter({ device in
                device.connectionState == .DISCONNECTED
            })
            .flatMap({ [weak self] connectDevice in
                if let this = self {
                    print("connect start:\(connectDevice.getIdentifier())")
                    return connectDevice.connect()
                        .do(onCompleted: { [weak self] in
                            print("connect end:\(connectDevice.getIdentifier())")
                            if let this = self {
                                this.uuidStrings = this.uuidStrings + [connectDevice.getIdentifier()]
                            }
                        })
                        .andThen(
                            connectDevice.subscribeData()
                                .take(until: this.disconnectDeviceRelay.filter({ disconnectDevice in
                                    connectDevice == disconnectDevice
                                }))
                        )
                        .do(onCompleted: { [weak self] in
                            print("disconnect:\(connectDevice.getIdentifier())")
                            if let this = self {
                                this.uuidStrings = this.uuidStrings.filter({ uuidString in
                                    uuidString != connectDevice.getIdentifier()
                                })
                            }
                            connectDevice.disconnect()
                        })
                } else {
                    return Observable.error(RxError.unknown)
                }
            })
            .subscribe { [weak self] event in
                switch event {
                case .next(let packet):
                    print("packet:\(packet.type)")
                    switch packet.type {
                    case .notification:
                        self?.onNotifyData(packet)
                    default:
                        break
                    }
                case .completed:
                    print("connectDeviceRelay completed")
                case .error(let error):
                    print("connectDeviceRelay error:\(error)")
                }
            }
            .disposed(by: disposeBag)
        
        let uuids = uuidStrings.compactMap { uuidString in
            UUID(uuidString: uuidString)
        }
        BluetoothManager.instance.retrieveDevice(identifiers: uuids)
            .asObservable()
            .flatMap { bleDevices in
                Observable.from(bleDevices.compactMap({ bleDevice in
                    bleDevice as? PeripheralPhoneDevice
                }))
            }
            .subscribe { [weak self] event in
                switch event {
                case .next(let device):
                    self?.addDevice(device: device)
                case .error(let error):
                    print("retrieve device error:\(error)")
                case .completed:
                    print("retrieve device completed")
                }
            }
            .disposed(by: disposeBag)
    }
    
    func addDevice(device: PeripheralPhoneDevice) {
        connectDeviceRelay.accept(device)
    }
    
    func removeDevice(device: PeripheralPhoneDevice) {
        disconnectDeviceRelay.accept(device)
    }
    
    private func onNotifyData(_ packet: Packet) {
        if let json = try? JSONSerialization.jsonObject(with: packet.data) as? [String: Any] {
            let content = UNMutableNotificationContent()
            content.title = json["title"] as? String ?? "empty title"
            content.body = json["text"] as? String ?? "empty body"
            content.sound = UNNotificationSound.default
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
            
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

            // add our notification request
            UNUserNotificationCenter.current().add(request)
        }
    }
}
