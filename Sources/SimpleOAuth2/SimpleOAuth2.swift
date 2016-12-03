//
//  SimpleOAuth2.swift
//  SwiftAPI
//
//  Created by Þorvaldur Rúnarsson on 29/11/2016.
//
//

import Foundation
import Kitura
import SwiftyJSON
import JWT


class SimpleOAuth2 {

    static let authPath = "/oauth2/authorize"
    private static var router = Router()

    public static var sharedInstance = SimpleOAuth2()

    private var authHash: Data?
    private var authenticator: SimpleJWT?
    
    public var publicPaths: [String] = [String]()

    public func isPublic(url: String) -> Bool {

        for path in self.publicPaths {

            let subPaths = path.components(separatedBy: "/")
            let urlSubPaths = url.components(separatedBy: "/")

            if (urlSubPaths.count > subPaths.count
                    && subPaths[subPaths.count-1] != "*")
                || urlSubPaths.count < subPaths.count {
                continue
            }

            var success = true
            for i in 0 ..< subPaths.count {

                if !(subPaths[i] == urlSubPaths[i] || subPaths[i] == "*") {
                    success = false
                }
            }
            if (success) {
                return true
            }

        }

        return false
    }


    public func simplySecure(router: Router, with credentials: SimpleCredential) {
        router.post(SimpleOAuth2.authPath, handler: SimpleOAuth2.authorize)

        let auth = SimpleJWT(issuer: credentials.clientId, algorithm: .hs512, secret: credentials.clientSecret.data(using: .utf8)!)
        SimpleOAuth2.router = router
        SimpleOAuth2.sharedInstance.authHash = credentials.hashedString().data(using: .utf8)!
        SimpleOAuth2.sharedInstance.authenticator = auth
        router.all("/*", middleware: BodyParser())
        router.all("/*", middleware: SimpleCredentialMiddleware(authenticator: auth))
    }


    private static func authorize(request: RouterRequest, response: RouterResponse, next: @escaping () -> Void) -> Void {

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
        
        guard let storedHash = SimpleOAuth2.sharedInstance.authHash else {
            response.status(.internalServerError).send(json: JSON([
                "errorMessage":"Failed to fetch internal credentials."
                ]))
            return
        }
        
        guard let authenticator = SimpleOAuth2.sharedInstance.authenticator else {
            response.status(.internalServerError).send(json: JSON([
                "errorMessage":"Authenticator not set up correctly."
                ]))
            return
        }
        
        if (grant != "client_credentials") {
            response.sendBadRequest(message: "Invalid grant type.")

            return
        }

        let credential = SimpleCredential(clientId: clientId, clientSecret: clientSecret)

        let hash = credential.hashedString()
        
        let comparingHash = String(data: storedHash, encoding: .utf8)

        if (hash != comparingHash) {
            response.sendUnauthorized(message: "Invalid credentials.", code: 1)
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
