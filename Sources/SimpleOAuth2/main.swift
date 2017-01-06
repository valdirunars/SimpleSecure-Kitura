//
//  main.swift
//  SimpleOAuth2
//
//  Created by Þorvaldur Rúnarsson on 29/11/2016.
//
//

import Foundation
import Kitura
import LoggerAPI
import HeliumLogger
import CloudFoundryEnv
import CloudFoundryDeploymentTracker

do {
  // HeliumLogger disables all buffering on stdout
  let controller = try Controller()
  Log.info("Server will be started on '\(controller.url)'.")
  CloudFoundryDeploymentTracker(repositoryURL: "https://github.com/IBM-Bluemix/SimpleSecure-Kitura.git", codeVersion: nil).track()
  Kitura.addHTTPServer(onPort: controller.port, with: controller.router)
  // Start Kitura-Starter server
  Kitura.run()
} catch let error {
  Log.error(error.localizedDescription)
  Log.error("Oops... something went wrong. Server did not start!")
}
