//
//  MainViewController.swift
//  TwoPhoneSupporter
//
//  Created by Jaehong Yoo on 2023/02/05.
//

import UIKit
import RxSwift

class MainViewController: UIViewController {

    @IBOutlet weak var statusView: UILabel!
    @IBOutlet weak var statusViewHeightConstraint: NSLayoutConstraint!
    
    private let disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        BluetoothService.instance.getConnectedDeviceObservable()
            .observe(on: MainScheduler.instance)
            .subscribe { [weak self] event in
                switch event {
                case .next(let devices):
                    if devices.count > 1 {
                        self?.statusView.text = "\(devices.count) Devices are connected"
                        UIView.animate(withDuration: 1.0, delay: 0.0) {
                            self?.statusViewHeightConstraint.constant = 38
                        }
                    } else if devices.count == 1 {
                        self?.statusView.text = "1 Device is connected"
                        UIView.animate(withDuration: 1.0, delay: 0.0) {
                            self?.statusViewHeightConstraint.constant = 38
                        }
                    } else {
                        UIView.animate(withDuration: 1.0, delay: 0.0) {
                            self?.statusViewHeightConstraint.constant = 0
                        }
                    }
                case .error(let error):
                    print("connected device error:\(error)")
                case .completed:
                    print("connected device complete")
                }
            }
            .disposed(by: disposeBag)
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
