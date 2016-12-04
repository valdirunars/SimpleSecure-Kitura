//
//  SimpleOAuth2.swift
//  SimpleOAuth2
//
//  Created by Þorvaldur Rúnarsson on 29/11/2016.
//
//

import Foundation
import Kitura
import SwiftyJSON
import JWT


public class SimpleOAuth2 {

    static let authPath = "/oauth2/authorize"
    
    public static var sharedInstance = SimpleOAuth2()

    private var authHashes = [Data]()
    public var authenticators = [Data:SimpleJWT]()
    
    /// Paths where no authentication is needed
    public var publicPaths: [String] = [String]()
    
    /// A dictionary where key represents a router path and value represents a comma seperated list scopes that the path is restricted to.
    public var restrictedPaths = [String:String]()

    

    /// Secures the routes of router with the specified credentials (clientId, clientSecret, scope), see SimpleOAuth2's scopes property for further info on scope validation
    public func simplySecure(router: Router, with credentials: [SimpleCredential]) {
        router.post(SimpleOAuth2.authPath, handler: SimpleOAuth2.authorize)

        for cred in credentials {
            let credData = cred.hashedString().data(using: .utf8)!
            let auth = SimpleJWT(issuer: cred.clientId, scope: cred.scope, using: .hs512, with: cred.clientSecret.data(using: .utf8)!)
            
            SimpleOAuth2.sharedInstance.authenticators[credData] = auth
            SimpleOAuth2.sharedInstance.authHashes.append(credData)
        }
        
        router.all("/*", middleware: BodyParser())
        router.all("/*", middleware: SimpleCredentialMiddleware())
    }


    private static func authorize(request: RouterRequest, response: RouterResponse, next: @escaping () -> Void) -> Void {

        
        // 1 READ PARAMETERS FROM REQUEST BODY
        var b: String?
        
        do {
            b = try request.readString()
        } catch {
            response.sendBadRequest(message: "No body. \(error)")
            return
        }

        guard let body = b else {
            response.sendBadRequest(message: "No body.")
            return
        }

        let authParams = extractParams(from: body)

        guard let clientId = authParams["client_id"] else {
            response.sendBadRequest(message: "No id.")

            return
        }
        guard let clientSecret = authParams["client_secret"] else {
            response.sendBadRequest(message: "No secret.")

            return
        }

        guard let grant = authParams["grant_type"] else {
            response.sendBadRequest(message: "Invalid grant type.")

            return
        }
        
        guard let scope = authParams["scope"] else {
            response.sendBadRequest(message: "Invalid scope")
            return
        }
        
        if (grant != "client_credentials") {
            response.sendBadRequest(message: "Invalid grant type.")

            return
        }
        
        // 2 CREATE CREDENTIAL DATA FROM INPUT DATA
        let credential = SimpleCredential(clientId: clientId, clientSecret: clientSecret, scope: scope)
        let hash = credential.hashedString()
        
        // 3 CHECK IF CREDENTIALS EXIST IN APP
        var authorized = false
        for storedHash in SimpleOAuth2.sharedInstance.authHashes {
            let comparingHash = String(data: storedHash, encoding: .utf8)
            if (hash == comparingHash) {
                authorized = true
                break
            }

        }
        
        if (!authorized) {
            response.sendUnauthorized(message: "Invalid credentials.", code: 1)
            return
        }

        
        // 4 GET THE AUTHENTICATOR, CREATE A TOKEN AND SEND IT
        guard let hashData = hash.data(using: .utf8) else {
            response.sendUnauthorized(message: "Request unauthorized.", code: 1)
            return
        }
        guard let authenticator = SimpleOAuth2.sharedInstance.authenticators[hashData] else {
            response.sendUnauthorized(message: "Request unauthorized.", code: 2)
            return
        }
        
        let token = authenticator.encode(with: clientId, expiresIn: SimpleJWT.tokenDuration)

        try? response.send(json: JSON([
            "token_type": "Bearer",
            "expires_in":"\(SimpleJWT.tokenDuration)", // 30 minutes
            "access_token": token
        ])).end()


    }

    private static func extractParams(from body: String) -> [String: String] {
        let json = JSON(data: body.data(using: .utf8)!)
        var params = [String: String]()

        for (key, object) in json {
            params[key as String] = object.stringValue
        }
        return params

    }


}
