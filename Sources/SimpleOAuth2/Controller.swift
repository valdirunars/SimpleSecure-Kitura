/**
* Copyright IBM Corporation 2016
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
**/
import Foundation
import Kitura
import SwiftyJSON
import LoggerAPI
import CloudFoundryEnv
import KituraStencil

public class Controller {

  let router: Router
  let appEnv: AppEnv

  var port: Int {
    get { return appEnv.port }
  }

  var url: String {
    get { return appEnv.url }
  }

  init() throws {
    appEnv = try CloudFoundryEnv.getAppEnv()

    // All web apps need a Router instance to define routes
    router = Router()
    SimpleOAuth2.sharedInstance.publicPaths = [
      "/",
      "/static/*"
    ]
    SimpleOAuth2.sharedInstance.simplySecure(router: router, with: SimpleCredential(clientId: "1234", clientSecret: "4321"))
    // Serve static content from "public"
    router.all("/static", middleware: StaticFileServer())
    router.add(templateEngine: StencilTemplateEngine())

    router.get("/", handler: get)
    router.post("/uploadTest", handler: postUpload)

  }

  func get(request: RouterRequest, response: RouterResponse, next: () -> Void) {
      // https://github.com/groue/GRMustache.swift

      do {
          try response.render("index.stencil", context: [:]).end()
      } catch {
          // response.statusCode = HTTPStatusCode.
          response.status(.badRequest).send(json: JSON([
              "errorMessage": error.localizedDescription
          ]))

      }
      next()
  }

  func postUpload(request: RouterRequest, response: RouterResponse, next: () -> Void) {
        guard let multiPart = request.body?.asMultiPart else {
            try? response.status(.badRequest).end()
            return
        }
        var u: URL?

        for part in multiPart {
            switch part.body {
            case .raw(let data):
                u = write(data: data)
                break
            default:
                try? response.status(.badRequest).end()
                return
            }
        }

        guard let url = u else {
            try? response.status(.badRequest).end()
            return
        }

        do {
            let data = try Data(contentsOf: url)
            try? response.status(.OK).send(data: data).end()
        } catch {
            try? response.status(.badRequest).send(error.localizedDescription).end()
        }


    }

    private func write(data: Data) -> URL {
        #if DEBUG
            let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as String
        #else
            let paths = FileManager.default.currentDirectoryPath
        #endif
        let url = URL(fileURLWithPath: paths).appendingPathComponent("zipTest.zip")

        if let fileHandle = try? FileHandle(forWritingTo: url) {
            //Append to file

            //fileHandle.seekToEndOfFile()
            fileHandle.write(data)
        } else {
            //Create new file
            do {
                try data.write(to: url)
            } catch {
                print("Error creating \(url)")
            }
        }
        return url
    }
}