//
//  Array+unique.swift
//  TwoPhoneSupporter
//
//  Created by Jaehong Yoo on 2023/01/17.
//

import Foundation

extension Array {
    func unique<T:Hashable>(by: ((Element) -> (T)))  -> [Element] {
//        let dict = Dictionary(uniqueKeysWithValues: map({ (by($0), $0) }))
//        return Array(dict.values)
        
//        let uniqued = Dictionary(grouping: self) { by($0) }
//            .mapValues { $0.first! }
//            .values
//        return Array(uniqued)
        
        var set = Set<T>() //the unique list kept in a Set for fast retrieval
        var arrayOrdered = [Element]() //keeping the unique list of elements but ordered
        for value in self {
            if !set.contains(by(value)) {
                set.insert(by(value))
                arrayOrdered.append(value)
            }
        }

        return arrayOrdered
    }
}
