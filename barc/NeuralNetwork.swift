//
//  ImageRecognizer.swift
//  barc
//
//  Created by Tim Farnam on 3/5/18.
//  Copyright © 2018 Tim Farnam. All rights reserved.
//

import Foundation
import UIKit
import CoreML
import Vision


public protocol NeuralNetworkDelegate: class {
    func didClassifyImage(results: [ ClassificationResult ])
    func didInitModel()
    func willUpdateModel()
    func initModelError(errorMessage: String)
}

public struct ClassificationResult: Codable {
    var label: String
    var confidence: Float
}

class NeuralNetwork {
    
    var delegate : NeuralNetworkDelegate?
    let modelRemoteURL : URL!
    let modelURL : URL!
    var model : VNCoreMLModel?
    var request: VNCoreMLRequest?
    
    
    init() {
        modelRemoteURL = URL(string:  "https://admin:4Fbz8RL2U5PUcRdq@barc.squids.online/static/barc.mlmodel")!
        
        let appSupportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        try? FileManager.default.createDirectory(at: appSupportDirectory!, withIntermediateDirectories: true)
        modelURL = appSupportDirectory?.appendingPathComponent("model.mlmodelc")
    }
    
    
    func classifyImage(_ pixelBuffer: CVPixelBuffer) {
        DispatchQueue.global(qos: .userInitiated).async {
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer)
            try? handler.perform([self.request!])
        }
    }
    
    
    func initModel() {
        
        // find the modification date of the model
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: modelURL.path) else {
            self.downloadModel()
            return
        }
        let localLastModifiedAt = attributes[FileAttributeKey.modificationDate] as! Date
        
        // make a HEAD request to see if it has been updated
        var request = URLRequest(url: modelRemoteURL)
        request.httpMethod = "HEAD"
        let session = URLSession.shared
        
        let task = session.dataTask(with: request) { data, response, error in
            
            if error != nil {
                self.loadModel()
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                
                let lastModifiedHeader = httpResponse.allHeaderFields["Last-Modified"] as! String
                
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "EEE, dd LLL yyyy HH:mm:ss zzz"
                
                guard let remoteLastModifiedAt = dateFormatter.date(from: lastModifiedHeader) else {
                    self.downloadModel()
                    return
                }
                
                if (remoteLastModifiedAt > localLastModifiedAt) {
                    self.downloadModel()
                } else {
                    self.loadModel()
                }
            }
        }
        
        task.resume()
    }
    
    
    func downloadModel() {
        if (delegate != nil) {
            delegate!.willUpdateModel()
        }
        
        let request = URLRequest(url: modelRemoteURL)
        let session = URLSession.shared
        let task = session.downloadTask(with: request) { tempLocalURL, response, error in

            if tempLocalURL != nil, error == nil {
                do {
                    let tempCompiledURL = try MLModel.compileModel(at: tempLocalURL!)
                    
                    if FileManager.default.fileExists(atPath: self.modelURL.path) {
                        try FileManager.default.replaceItemAt(self.modelURL, withItemAt: tempCompiledURL)
                    } else {
                        try FileManager.default.copyItem(at: tempCompiledURL, to: self.modelURL)
                    }
                    
                    self.loadModel()
                } catch {
                    print("downloadModel error", error)
                    self.loadModel()
                }
            }
            else {
                self.loadModel()
            }
        }
        task.resume()
    }
    
    
    func loadModel() {
        do {
            let mlModel = try MLModel(contentsOf: modelURL)
            
            model = try VNCoreMLModel(for: mlModel)
            
            request = VNCoreMLRequest(
                model: self.model!,
                completionHandler: { [weak self] request, error in
                    self?.processClassifications(for: request, error: error)
                }
            )
            
            request!.imageCropAndScaleOption = .centerCrop
            
            delegate?.didInitModel()
        } catch {
            print(error)
            delegate?.initModelError(errorMessage: "Can't load the neural network")
        }
    }
    
    
    
    func processClassifications(for request: VNRequest, error: Error?) {
        DispatchQueue.main.async {
            
            guard let results = request.results else {
                print("Unable to classify image.\n\(error!.localizedDescription)")
                self.delegate!.didClassifyImage(results: [ ])
                return
            }
            
            let classifications = (results as! [VNClassificationObservation]).filter { obs in
                obs.confidence >= 0.05
            }.map { obs in
                return ClassificationResult(label: obs.identifier, confidence: obs.confidence)
            }
            
            if self.delegate != nil {
                self.delegate!.didClassifyImage(results: classifications)
            }

        }
    }
    
    
}


