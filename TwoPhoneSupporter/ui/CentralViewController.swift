//
//  ViewController.swift
//  TwoPhoneSupporter
//
//  Created by Jaehong Yoo on 2023/01/02.
//

import UIKit
import AlgorigoBleLibrary
import RxSwift

class CentralViewController: UIViewController {
    var bleDevices = [BleDevice]()
    let disposeBag = DisposeBag()
    
    @IBOutlet weak var deviceTableView: UITableView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        stateSubscribe()
        searchDevice()
    }
    
    private func stateSubscribe() {
        BluetoothManager.instance.getConnectionStateObservable()
            .observe(on: MainScheduler.instance)
            .subscribe { [weak self] event in
                switch event {
                case .next((let device, let state)):
                    print("state:\(device.getIdentifier()):\(state)")
                    self?.deviceTableView?.reloadData()
                case .error(let error):
                    print("connection state error:\(error)")
                case .completed:
                    break
                }
            }
            .disposed(by: disposeBag)
    }

    private func searchDevice() {
        let connected = BluetoothManager.instance.getConnectedDevices()
        BluetoothManager.instance.scanDevice(withServices: ["6E400001-B5A3-F393-E0A9-0123456789AB"])
            .take(for: RxTimeInterval.seconds(15), scheduler: ConcurrentDispatchQueueScheduler(qos: .background))
            .map({ scanned in
                (connected + scanned).unique { $0.getIdentifier() }
            })
            .observe(on: MainScheduler.instance)
            .subscribe { [weak self] event in
                switch event {
                case .next(let devices):
                    self?.bleDevices = devices
                    self?.deviceTableView?.reloadData()
                case .error(let error):
                    print("scan device error:\(error)")
                case .completed:
                    break
                }
            }
            .disposed(by: disposeBag)
    }
    
    @IBAction func handleBack(_ sender: Any) {
        dismiss(animated: true)
    }
}

extension CentralViewController : UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return bleDevices.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "bledevice_cell", for: indexPath) as? DeviceTableViewCell else {
            fatalError("Cell is not exist")
        }
        
        cell.delegate = self
        cell.setDevice(device: self.bleDevices[indexPath.row])
        
        return cell
    }
}

extension CentralViewController : DeviceTableViewCellDelegate {
    func onConnectBtn(bleDevice: BleDevice) {
        if bleDevice.connected {
            bleDevice.disconnect()
        } else {
            bleDevice.connect()
                .andThen(bleDevice.writeCharacteristic(uuid: "6E400002-B5A3-F393-E0A9-0123456789AB", data: "Data".data(using: .utf8)!))
                .asObservable()
                .flatMap { data in
                    print("data:\(data)")
                    return bleDevice.setupNotification(uuid: "6E400002-B5A3-F393-E0A9-0123456789AB")
                }
                .subscribe { event in
                    switch event {
                    case .next(let data):
                        print("data2:\(data)")
                    case .completed:
                        print("completed")
                    case .error(let error):
                        print("error:\(error)")
                    }
                }
                .disposed(by: disposeBag)
            
//            bleDevice.connect()
//                .andThen(bleDevice.writeCharacteristic(uuid: "6E400002-B5A3-F393-E0A9-0123456789AB", data: "Data".data(using: .utf8)))
//                .asObservable()
//                .flatMap({ data in
//                    print("!!! 000:\(data)")
//                    bleDevice.setupNotification(uuid: "6E400002-B5A3-F393-E0A9-0123456789AB")
//                        .flatMap { observable in
//                            observable
//                        }
//                })
//                .subscribe { event in
//                    switch event {
//                    case .next(let data):
//                        print("!!! 111:\(data)")
//                    case .completed:
//                        print("!!! completed")
//                    case .error(let error):
//                        print("!!! \(error)")
//                    }
//                }
//                .disposed(by: disposeBag)
        }
    }
    
}
