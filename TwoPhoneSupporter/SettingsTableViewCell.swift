//
//  SettingsTableViewCell.swift
//  TwoPhoneSupporter
//
//  Created by Jaehong Yoo on 2023/02/05.
//

import UIKit

class SettingsTableViewCell: UITableViewCell {

    private var settings: SettingsViewController.Settings!
    
    @IBOutlet weak var titleView: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    func setSettings(settings: SettingsViewController.Settings) {
        self.settings = settings
        titleView.text = settings.rawValue
    }
}
