//
//  Observable+concat.swift
//  TwoPhoneSupporter
//
//  Created by Jaehong Yoo on 2023/01/29.
//

import Foundation
import RxSwift

extension Observable {
    func concat(_ completable: Completable) -> Observable<Element> {
        concat(completable.asObservable().map({ never in
            never as! Element
        }))
    }
}
