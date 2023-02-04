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

class DeviceNamesToConnectManager {
    private var deviceNames = [String]()
    private let deviceNamesRelay = PublishRelay<[String]>()
    
    init(_ deviceNames: [String]) {
        self.deviceNames = deviceNames
    }
    
    func getObservable() -> Observable<[String]> {
        return Observable.just(deviceNames)
            .concat(deviceNamesRelay)
    }
    
    func addDeviceNameToScan(deviceName: String) {
        deviceNames.append(deviceName)
        deviceNamesRelay.accept(deviceNames)
    }
    
    func removeDeviceNameFromScan(deviceName: String) {
        deviceNames.removeAll { $0 == deviceName }
        deviceNamesRelay.accept(deviceNames)
    }
}

class BluetoothService {
    
    private static let keyStoredDevice = "KeyStoredDevice"
    
    static let instance = BluetoothService()
    
    private let disposeBag = DisposeBag()
    private let connectDeviceRelay = PublishRelay<PeripheralPhoneDevice>()
    private let disconnectDeviceRelay = PublishRelay<PeripheralPhoneDevice>()
    private let deviceNamesToConnectManager: DeviceNamesToConnectManager!
    
    private init() {
        deviceNamesToConnectManager = DeviceNamesToConnectManager(UserDefaults.standard.stringArray(forKey: BluetoothService.keyStoredDevice) ?? [])
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
                            if let deviceName = connectDevice.getName() {
                                self?.storeDeviceName(deviceName: deviceName)
                            }
                        })
                        .andThen(
                            connectDevice.subscribeData()
                                .take(until: this.disconnectDeviceRelay.filter({ disconnectDevice in
                                    connectDevice == disconnectDevice
                                }))
                        )
                        .concat(connectDevice.clearDevice())
                        .do(onCompleted: { [weak self] in
                            print("disconnect:\(connectDevice.getName()):\(connectDevice.getIdentifier())")
                            if let deviceName = connectDevice.getName() {
                                self?.removeDeviceName(deviceName: deviceName)
                            }
                            connectDevice.disconnect()
                        })
                        .catch({ error in
                            print("catch:\(error)")
                            self?.deviceNamesToConnectManager.addDeviceNameToScan(deviceName: connectDevice.getName()!)
                            return Observable.empty()
                        })
                } else {
                    return Observable.error(RxError.unknown)
                }
            })
            .do(onDispose: {
                print("connectDeviceRelay onDispose")
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
        
        deviceNamesToConnectManager
            .getObservable()
            .flatMap { deviceNames -> Observable<Bool> in
                Observable.just(deviceNames.count > 0)
            }
            .distinctUntilChanged()
            .flatMapLatest({ on in
                if on {
                    print("!!!! start scan")
                    return BluetoothManager.instance.scanDevice(withServices: [PeripheralPhoneDevice.mainService])
                        .map { bleDevices -> [PeripheralPhoneDevice] in
                            bleDevices.compactMap({ $0 as? PeripheralPhoneDevice })
                        }
                        .concatMap { [weak self] devices in
                            print("scanned:(\(devices.count)):\(devices.map({ $0.getName() ?? "" }).joined(separator: ","))")
                            return self?.deviceNamesToConnectManager
                                .getObservable()
                                .map({ deviceNames -> [PeripheralPhoneDevice] in
                                    devices.filter { device in
                                        deviceNames.contains { device.getName() == $0 }
                                    }
                                })
                                .take(while: { filtered in
                                    print("scan filtered:\(filtered.count):\(filtered.first)")
                                    switch filtered.count {
                                    case 0:
                                        return false
                                    case 1:
                                        let device = filtered.first!
                                        self?.connectDeviceRelay.accept(device)
                                        self?.deviceNamesToConnectManager.removeDeviceNameFromScan(deviceName: device.getName()!)
                                        return false
                                    default:
                                        let device = filtered.first!
                                        self?.connectDeviceRelay.accept(device)
                                        self?.deviceNamesToConnectManager.removeDeviceNameFromScan(deviceName: device.getName()!)
                                        return true
                                    }
                                })
                                .ignoreElements()
                            ?? Observable.error(RxError.unknown)
                        }
                } else {
                    print("!!!! stop scan")
                    return Observable.empty()
                }
            })
            .subscribe { event in
                
            }
            .disposed(by: disposeBag)
    }
    
    fileprivate func getStoredDeviceNames() -> [String] {
        return UserDefaults.standard.stringArray(forKey: BluetoothService.keyStoredDevice) ?? []
    }
    
    fileprivate func storeDeviceName(deviceName: String) {
        var stored = getStoredDeviceNames()
        stored.append(deviceName)
        UserDefaults.standard.set(stored, forKey: BluetoothService.keyStoredDevice)
    }
    
    fileprivate func removeDeviceName(deviceName: String) {
        var stored = getStoredDeviceNames()
        stored.removeAll { $0 == deviceName }
        UserDefaults.standard.set(stored, forKey: BluetoothService.keyStoredDevice)
    }
    
    func connectDevice(device: PeripheralPhoneDevice) {
        connectDeviceRelay.accept(device)
    }
    
    func disconnectDevice(device: PeripheralPhoneDevice) {
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
