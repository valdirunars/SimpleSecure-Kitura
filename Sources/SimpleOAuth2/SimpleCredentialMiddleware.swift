//
//  CredentialMiddlewear.swift
//  SwiftAPI
//
//  Created by Þorvaldur Rúnarsson on 29/11/2016.
//
//

import Foundation
import Kitura
import SwiftyJSON
/**
 Custom middleware that allows Cross Origin HTTP requests
 This will allow wwww.todobackend.com to communicate with your server
 */
class SimpleCredentialMiddleware: RouterMiddleware {

    private let authenticator: SimpleJWT

    init(authenticator: SimpleJWT) {
        self.authenticator = authenticator
    }

    func handle(request: RouterRequest, response: RouterResponse, next: @escaping () -> Void) throws {
        
        
        if (request.method == .post
                && request.urlComponents.path == SimpleOAuth2.authPath)
            ||  SimpleOAuth2.sharedInstance.isPublic(url: request.urlComponents.path) {
            
            next()
            return
        }
        
        
        guard let auth = request.headers["Authorization"] else {
            response.sendUnauthorized(message: "Authentication needed.", code: 1)
            return
        }
        
        let args = auth.components(separatedBy: " ")
        if (args.count != 2 ||
            (args.count > 0 && args[0] != "Bearer")) {
            response.sendUnauthorized(message: "Authentication needed.", code: 2)
        }
        
        let token = args[1]
        if !self.authenticator.authorize(token: token) {
            response.sendUnauthorized(message: "Authentication needed.", code: 3)
            return
        }
                
        next()
    }

}
