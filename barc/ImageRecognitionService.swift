import UIKit

class ImageRecognitionService: NSObject {
    
    let apiEndpoint = "https://barc.squids.online/api/images"
    let apiToken = "4Fbz8RL2U5PUcRdq"
    // let apiEndpoint = "http://10.0.0.3:5000/api/images"
    // let apiToken = "secret"
    
    
    func request(_ image: UIImage,
                 callback:  @escaping (_:String?) -> Void,
                 errorCallback:  @escaping (_:String) -> Void) {
        
        guard let url = URL(string: apiEndpoint) else {
            print("Error: cannot create URL")
            return
        }
        
        var urlRequest = URLRequest(url: url)
        
        urlRequest.httpMethod = "POST"
        let boundary = "Boundary-\(UUID().uuidString)"
        urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Token token=\(apiToken)", forHTTPHeaderField: "Authorization")
        
        urlRequest.httpBody = createBody(
            parameters: [ "device_id" : UIDevice.current.identifierForVendor!.uuidString ],
            boundary: boundary,
            data: UIImageJPEGRepresentation(image, 0.7)!,
            mimeType: "image/jpg",
            filename: "hello.jpg"
        )
        
        let session = URLSession.shared
        
        let task = session.dataTask(with: urlRequest) {
            (data, response, error) in
            
            // check for any errors
            guard error == nil else {
                print(error!)
                errorCallback("Cant connect to Barc server")
                return
            }
            
            // make sure we got data
            guard let responseData = data else {
                print("server down")
                errorCallback("Cant connect to Barc server")
                return
            }
            
            // parse the result as JSON
            do {
                
                guard let caption = try JSONSerialization.jsonObject(with: responseData, options: []) as? [String: Any] else {
                    errorCallback("Cant connect to Barc server")
                    return
                }
                
                if let result = caption["result"] as? String {
                    callback(result)
                } else {
                    callback(nil)
                }
                
            }
            catch {
                print("error trying to convert data to JSON")
                errorCallback("Cant connect to Barc server")
            }
        }
        task.resume()
    }
    
    
    func createBody(parameters: [String: String],
                    boundary: String,
                    data: Data,
                    mimeType: String,
                    filename: String) -> Data {
        
        var body = Data()
        
        let boundaryPrefix = Data("--\(boundary)\r\n".utf8)
        
        for (key, value) in parameters {
            body.append(boundaryPrefix)
            body.append(Data("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".utf8))
            body.append(Data("\(value)\r\n".utf8))
        }
        
        body.append(boundaryPrefix)
        body.append(Data("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".utf8))
        body.append(Data("Content-Type: \(mimeType)\r\n\r\n".utf8))
        body.append(data)
        body.append(Data("\r\n".utf8))
        body.append(Data("--".appending(boundary.appending("--")).utf8))
        
        return body as Data
    }

}

