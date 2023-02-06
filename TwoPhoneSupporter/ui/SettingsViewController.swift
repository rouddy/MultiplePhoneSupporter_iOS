//
//  SettingsViewController.swift
//  TwoPhoneSupporter
//
//  Created by Jaehong Yoo on 2023/02/05.
//

import UIKit

class SettingsViewController: UIViewController {
    
    enum Settings : String, CaseIterable {
        case connection = "Connection"
        case credit = "Credit"
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

    @IBAction func handleBack(_ sender: Any) {
        dismiss(animated: true)
    }
}

extension SettingsViewController : UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Settings.allCases.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "settings_cell", for: indexPath) as? SettingsTableViewCell else {
            fatalError("Cell is not exist")
        }
        
        cell.setSettings(settings: Settings.allCases[indexPath.row])
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let settings = indexPath.row < Settings.allCases.count ? Settings.allCases[indexPath.row] : nil else {
            return
        }
        
        switch settings {
        case .connection:
            let storyBoard: UIStoryboard = UIStoryboard(name: "Main", bundle:nil)
            if let nextViewController = storyBoard.instantiateViewController(withIdentifier: "connection") as? ConnectViewController {
                present(nextViewController, animated:true, completion:nil)
            }
        case .credit:
            let storyBoard: UIStoryboard = UIStoryboard(name: "Main", bundle:nil)
            if let nextViewController = storyBoard.instantiateViewController(withIdentifier: "credit") as? CreditViewController {
                present(nextViewController, animated:true, completion:nil)
            }
        }
    }
}
