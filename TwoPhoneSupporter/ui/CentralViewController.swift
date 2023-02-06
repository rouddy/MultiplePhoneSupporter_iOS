//
//  ViewController.swift
//  TwoPhoneSupporter
//
//  Created by Jaehong Yoo on 2023/01/02.
//

import UIKit
import AlgorigoBleLibrary
import RxSwift
import UserNotifications

protocol DismissCallback {
    func onDismissed()
}

class CentralViewController: UIViewController {
    
    var bleDevices = [PeripheralPhoneDevice]()
    let disposeBag = DisposeBag()
    
    @IBOutlet weak var deviceTableView: UITableView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        stateSubscribe()
        searchDevice()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        print("viewWillDisappear : \(isBeingDismissed)")
        if isBeingDismissed {
            print("parent:\(presentingViewController):\(presentingViewController.self)")
            if let callback = presentingViewController as? DismissCallback {
                callback.onDismissed()
            }
        }
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
        BluetoothManager.instance.scanDevice(withServices: [PeripheralPhoneDevice.mainService])
            .take(for: RxTimeInterval.seconds(15), scheduler: ConcurrentDispatchQueueScheduler(qos: .background))
            .map({ scanned in
                (connected + scanned)
                    .unique { $0.getIdentifier() }
                    .compactMap { $0 as? PeripheralPhoneDevice }
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
    func onConnectBtn(bleDevice: PeripheralPhoneDevice) {
        if bleDevice.connected {
            BluetoothService.instance.disconnectDevice(device: bleDevice)
        } else {
            print("onConnectBtn:\(bleDevice.getIdentifier())")
            BluetoothService.instance.connectDevice(device: bleDevice)
        }
    }
}
