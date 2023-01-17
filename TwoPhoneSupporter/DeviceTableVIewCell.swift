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
    func onConnectBtn(bleDevice: BleDevice)
}

class DeviceTableViewCell: UITableViewCell {
    
    var delegate: DeviceTableViewCellDelegate? = nil
    private var device: BleDevice!
    
    @IBOutlet weak var deviceNameView: UILabel?
    @IBOutlet weak var connectBtn: UIButton!
    
    @IBAction
    func onConnectBtn() {
        delegate?.onConnectBtn(bleDevice: device)
    }
    
    func setDevice(device: BleDevice) {
        self.device = device
        deviceNameView?.text = device.getIdentifier()
        connectBtn.setTitle(device.connected ? "Disconnect" : "Connect", for: .normal)
    }
}
