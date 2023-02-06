//
//  MainViewController.swift
//  TwoPhoneSupporter
//
//  Created by Jaehong Yoo on 2023/01/15.
//

import UIKit

class ConnectViewController: UIViewController {

    @IBOutlet weak var doneButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { success, error in
            if success {
                print("All set!")
            } else if let error = error {
                print(error.localizedDescription)
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        print("viewWillAppear:\(animated):\(isBeingDismissed)")
        doneButton.isEnabled = BluetoothService.getStoredDeviceNames().count > 0
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

    @IBAction func handleActAsPeripheral(_ sender: Any) {
        
    }
    
    @IBAction func handleActAsCentral(_ sender: Any) {
        moveToCentral()
    }
    
    @IBAction func handleDone(_ sender: Any) {
        if BluetoothService.getStoredDeviceNames().count > 0 {
            dismiss(animated: true)
        }
    }
    
    private func moveToCentral() {
        let storyBoard: UIStoryboard = UIStoryboard(name: "Main", bundle:nil)
        let nextViewController = storyBoard.instantiateViewController(withIdentifier: "central") as! CentralViewController
        present(nextViewController, animated:true, completion:nil)
    }
}

extension ConnectViewController : DismissCallback {
    func onDismissed() {
        print("onDismissed")
        doneButton.isEnabled = BluetoothService.getStoredDeviceNames().count > 0
    }
}
