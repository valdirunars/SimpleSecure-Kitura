//
//  Controller.swift
//  SimpleOAuth2
//
//  Created by Þorvaldur Rúnarsson on 29/11/2016.
//
//

import Foundation
import Kitura
import SwiftyJSON
import LoggerAPI
import CloudFoundryEnv
import KituraStencil

public class Controller {

  let router: Router = Router()
  let appEnv: AppEnv

  var port: Int {
    get { return appEnv.port }
  }

  var url: String {
    get { return appEnv.url }
  }

  init() throws {
    appEnv = try CloudFoundryEnv.getAppEnv()
    
    SimpleOAuth2.sharedInstance.publicPaths = [
      "/",
      "/static/*",
    ]
    SimpleOAuth2.sharedInstance.restrictedPaths = [
        "/adminJSON": "admin",
        "/userJSON": "user,admin"
    ]
    
    SimpleOAuth2.sharedInstance.simplySecure(router: router, with: [
        SimpleCredential(clientId: "1234", clientSecret: "4321", scope: "admin"),
        SimpleCredential(clientId: "4321", clientSecret: "1234", scope: "user")
    ])
    router.all("/static", middleware: StaticFileServer())
    router.all("/*", middleware: BodyParser())
    // Serve static content from "public"
    
    router.add(templateEngine: StencilTemplateEngine())

    router.get("/", handler: get)
    router.get("/adminJSON", handler: getAdminJSON)
    router.get("/userJSON", handler: getUserJSON)

  }

  func get(request: RouterRequest, response: RouterResponse, next: () -> Void) {
      // https://github.com/groue/GRMustache.swift
    
      do {
        var isAdmin = false
        if let token = request.queryParameters["token"] {
            for auth in SimpleOAuth2.sharedInstance.authenticators.values {
                if auth.authorize(token: token) &&
                    auth.scope == "admin" {
                    isAdmin = true
                    break
                }
            }
        }
        
        
        if isAdmin {
            try response.render("index.stencil", context: [ "admin": "true"]).end()
        }
        else
        {
            try response.render("index.stencil", context: [ : ]).end()
        }
        
      } catch {
          response.status(.badRequest).send(json: JSON([
              "errorMessage": error.localizedDescription
          ]))

      }
      next()
  }

  func getAdminJSON(request: RouterRequest, response: RouterResponse, next: () -> Void) {
    response.status(.OK).send(json: JSON([
        "messsage": "Secured by admin credential"
    ]))
    next()
  }
  
  func getUserJSON(request: RouterRequest, response: RouterResponse, next: () -> Void) {
    response.status(.OK).send(json: JSON([
        "messsage":"Secured by user credential"
    ]))
    next()
  }
  
}
