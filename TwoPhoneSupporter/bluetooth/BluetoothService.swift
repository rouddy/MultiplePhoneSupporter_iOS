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
    
    private var nameStrings: [String] {
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
                            print("connect end:\(connectDevice.getName()):\(connectDevice.getIdentifier())")
                            if let this = self {
                                this.nameStrings = this.nameStrings + [connectDevice.getName() ?? ""]
                            }
                        })
                        .andThen(
                            connectDevice.subscribeData()
                                .take(until: this.disconnectDeviceRelay.filter({ disconnectDevice in
                                    connectDevice == disconnectDevice
                                }))
                        )
                        .concat(connectDevice.clearDevice())
                        .catch({ error in
                            
                            Observable.error(error)
                        })
                        .do(onCompleted: { [weak self] in
                            print("disconnect:\(connectDevice.getName()):\(connectDevice.getIdentifier())")
                            if let this = self {
                                this.nameStrings = this.nameStrings.filter({ nameString in
                                    nameString != connectDevice.getName()
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
        
        var scanned = Array<BleDevice>()
        print("nameStrings:\(nameStrings.joined(separator: ","))")
        BluetoothManager.instance.scanDevice(withServices: [PeripheralPhoneDevice.mainService])
            .map { bleDevices in
                bleDevices
                    .compactMap({ bleDevice in
                        bleDevice as? PeripheralPhoneDevice
                    })
                    .filter { bleDevice in
                        self.nameStrings.contains(bleDevice.getName() ?? "")
                    }
            }
            .flatMap { bleDevices in
                Observable.from(bleDevices)
            }
            .concatMap({ bleDevice in
                Observable<PeripheralPhoneDevice>.create { observer in
                    if !scanned.contains(where: { scan in
                        scan.getName() == bleDevice.getName()
                    }) {
                        scanned.append(bleDevice)
                        observer.onNext(bleDevice)
                    }
                    observer.onCompleted()
                    return Disposables.create()
                }
            })
            .do(onNext: { bleDevice in
                print("scan do onNext:\(bleDevice.getName()):\(bleDevice.getIdentifier())")
                self.addDevice(device: bleDevice)
            })
            .take(while: { _ in
                scanned.count < self.nameStrings.count
            })
            .subscribe { event in
                switch event {
                case .next(let bleDevice):
                    print("scan onNext:\(bleDevice.getName()):\(bleDevice.getIdentifier())")
                case .error(let error):
                    print("scan device error:\(error)")
                case .completed:
                    print("scan device completed")
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
