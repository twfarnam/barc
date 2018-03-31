import UIKit

class WebService {
    
    let apiEndpoint = "https://barc.squids.online/api/images"
    let apiToken = "4Fbz8RL2U5PUcRdq"
    // let apiEndpoint = "http://192.168.100.6:5000/api/images"
    // let apiToken = "secret"
    
    func report(pixelBuffer: CVPixelBuffer, results: [ ClassificationResult ], motion: MotionObservation ) {
        
        guard let url = URL(string: apiEndpoint) else {
            print("Error: cannot create URL")
            return
        }
        
        let image = createImage(pixelBuffer)!
        
        var request = URLRequest(url: url)
        
        request.httpMethod = "POST"
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Token token=\(apiToken)", forHTTPHeaderField: "Authorization")
        
        request.httpBody = createBody(
            parameters: [
                "device_id" : UIDevice.current.identifierForVendor!.uuidString,
                "result" : String(data: try! JSONEncoder().encode(results), encoding: .utf8)!,
                "motion" : String(data: try! JSONEncoder().encode(motion), encoding: .utf8)!,
            ],
            boundary: boundary,
            data: UIImageJPEGRepresentation(image, 0.7)!,
            mimeType: "image/jpg",
            filename: "image.jpg"
        )
        
        let session = URLSession.shared
        let task = session.dataTask(with: request) { data, response, error in
            
            guard error == nil else {
                print(error!)
                return
            }
            
            // don't need to do anything with the response
            
        }
        task.resume()
    }
    
    
    func createImage(_ pixelBuffer: CVPixelBuffer) -> UIImage? {
        // this assumes vertical orientation
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer).oriented(forExifOrientation: 6)
        
        let ratio = 500.0 / Double(CVPixelBufferGetHeight(pixelBuffer))
        
        let filter = CIFilter(name: "CILanczosScaleTransform")!
        filter.setValue(ciImage, forKey: "inputImage")
        filter.setValue(ratio, forKey: "inputScale")
        filter.setValue(1.0, forKey: "inputAspectRatio")
        let resizedImage = filter.outputImage!
        
        let context = CIContext(options:nil)
        let cgImage = context.createCGImage(resizedImage, from: resizedImage.extent)!
        
        return UIImage(cgImage: cgImage)
    }
    
    
    func createBody(parameters: [String: String], boundary: String, data: Data, mimeType: String, filename: String) -> Data {
        
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

