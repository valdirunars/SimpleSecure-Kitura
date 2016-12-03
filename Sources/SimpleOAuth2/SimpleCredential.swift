//
//  SimpleCredential.swift
//  SwiftAPI
//
//  Created by Þorvaldur Rúnarsson on 29/11/2016.
//
//

import Foundation
import CryptoSwift

struct SimpleCredential {
    
    let clientId: String
    let clientSecret: String
    
    func hashedString() -> String {
        return "\(clientId):\(clientSecret)".sha512()
    }
}
