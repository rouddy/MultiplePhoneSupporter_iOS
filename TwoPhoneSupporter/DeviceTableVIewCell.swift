//
//  DeviceTableVIewCell.swift
//  TwoPhoneSupporter
//
//  Created by Jaehong Yoo on 2023/01/10.
//

import Foundation
import UIKit
import AlgorigoBleLibrary

protocol DeviceTableViewCellDelegate {
    func onConnectBtn(bleDevice: PeripheralPhoneDevice)
}

class DeviceTableViewCell: UITableViewCell {
    
    var delegate: DeviceTableViewCellDelegate? = nil
    private var device: PeripheralPhoneDevice!
    
    @IBOutlet weak var deviceNameView: UILabel?
    @IBOutlet weak var connectBtn: UIButton!
    
    @IBAction
    func onConnectBtn() {
        delegate?.onConnectBtn(bleDevice: device)
    }
    
    func setDevice(device: PeripheralPhoneDevice) {
        self.device = device
        deviceNameView?.text = device.getName()
        connectBtn.setTitle(device.connected ? "Disconnect" : "Connect", for: .normal)
    }
}
