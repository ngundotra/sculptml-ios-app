//
//  DeployViewController.swift
//  build-ml
//
//  Created by Felipe Campos on 11/26/18.
//  Copyright © 2018 Noah Gundotra. All rights reserved.
//

import UIKit
import SnapKit
import CoreML
import Vision
import Photos
import Accelerate

class DeployViewController: UIViewController, UINavigationControllerDelegate {
    
    var modelInputDimension: (Int, Int, Int) = (28, 28, 1)
    var imageFormat: String! {
        return modelInputDimension.2 == 1 ? "grayscale" : "rgb"
    }
    
    var model: MLModel!
    var vnModel: VNCoreMLModel?
    var authorized: Bool = false
    
    let picker = UIImagePickerController()
    
    @IBOutlet weak var classification: UILabel!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var classifyButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // TODO: get model params, pass into image dimension into input specs
        // Do any additional setup after loading the view.
        
        authorized = Utils.checkCameraPermission()
        picker.delegate = self
        
        do {
            vnModel = try VNCoreMLModel(for: model)
        } catch _ {
            print("Could not convert .mlmodel into vision model.")
        }
        
        imageView.snp.makeConstraints { (make) in
            make.center.equalToSuperview()
            make.height.equalTo(modelInputDimension.1 * 4)
            make.width.equalTo(modelInputDimension.0 * 4)
        }
        
        classifyButton.snp.makeConstraints { (make) in
            make.centerX.equalToSuperview()
            make.top.lessThanOrEqualTo(imageView.snp.bottom)
        }
        
        classification.snp.makeConstraints { (make) in
            make.centerX.equalToSuperview()
            make.top.lessThanOrEqualTo(classifyButton.snp.bottom)
        }
    }
    
    @IBAction func imageSelect(_ sender: Any) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = NSTextAlignment.center
        let messageText = NSMutableAttributedString(
            string: "How would you like to test your model?",
            attributes: [
                NSAttributedStringKey.paragraphStyle: paragraphStyle,
                NSAttributedStringKey.font : UIFont.preferredFont(forTextStyle: UIFontTextStyle.body),
                NSAttributedStringKey.foregroundColor : UIColor.black
            ]
        )
        let webAlert = UIAlertController()
        webAlert.setValue(messageText, forKey: "attributedMessage")
        
        let plAction = UIAlertAction(title: "Choose from Library", style: .default, handler: {(alert: UIAlertAction!) in
            // set to photo library
            self.picker.sourceType = .photoLibrary
            self.picker.allowsEditing = false
            
            self.present(self.picker, animated: true)
        })
        
        let camAction = UIAlertAction(title: "Take a Photo", style: .default, handler: {(alert: UIAlertAction!) in
            if !UIImagePickerController.isSourceTypeAvailable(.camera) {
                return
            }
            
            // set to camera
            self.picker.sourceType = .camera
            self.picker.allowsEditing = false
            
            self.present(self.picker, animated: true)
        })
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        
        webAlert.addAction(plAction)
        webAlert.addAction(camAction)
        webAlert.addAction(cancelAction)
        
        DispatchQueue.main.async {
            self.present(webAlert, animated: true, completion: nil)
        }
    }
    
    func classify(image: UIImage) {
        // Classify the image
        let classificationRequest = VNCoreMLRequest(model: vnModel!) { [weak self] request, error in
            guard let results = request.results as? [VNClassificationObservation], let topClassification = results.first else {
                self?.classification.text = "Failed to classify"
                return
            }
            
            DispatchQueue.main.async {
                print("VNClassificationObservation identifier: \(topClassification.identifier)")
                print("Type of topClass: \(type(of: topClassification))")
                self?.classification.text = "Classification: \(topClassification.identifier)" // "\(classifications.first)"
            }
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let handler = VNImageRequestHandler(ciImage: CIImage(cgImage: image.cgImage!))
            do {
                try handler.perform([classificationRequest])
            } catch {
                print(error)
            }
        }
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}

extension DeployViewController: UIImagePickerControllerDelegate {
    @objc func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
    
    @objc func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        picker.dismiss(animated: true)
        classification.text = "Analyzing Image..."
        guard let image = info["UIImagePickerControllerOriginalImage"] as? UIImage else {
            return
        }
        
        print(0)
        
        UIGraphicsBeginImageContextWithOptions(CGSize(width: modelInputDimension.0, height: modelInputDimension.1), true, 2.0)
        image.draw(in: CGRect(x: 0, y: 0, width: modelInputDimension.0, height: modelInputDimension.1))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue, kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        var pixelBuffer : CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(newImage.size.width), Int(newImage.size.height), kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)
        guard (status == kCVReturnSuccess) else {
            return
        }
        
        print(1)
        
        CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer!)
        
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: pixelData, width: Int(newImage.size.width), height: Int(newImage.size.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) //3
        
        context?.translateBy(x: 0, y: newImage.size.height)
        context?.scaleBy(x: 1.0, y: -1.0)
        
        UIGraphicsPushContext(context!)
        newImage.draw(in: CGRect(x: 0, y: 0, width: newImage.size.width, height: newImage.size.height))
        UIGraphicsPopContext()
        CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        
        print(2)
        
        if imageFormat == "rgb" {
            imageView.image = newImage
            classify(image: newImage)
        } else if imageFormat == "grayscale" {
            guard let cgImage = newImage.cgImage else {
                print("Unable to get CGImage")
                return
            }
            
            print(3)
            
            /*
             The format of the source asset.
             */
            var format: vImage_CGImageFormat = {
                guard
                    let sourceColorSpace = cgImage.colorSpace else {
                        fatalError("Unable to get color space")
                }
                
                return vImage_CGImageFormat(
                    bitsPerComponent: UInt32(cgImage.bitsPerComponent),
                    bitsPerPixel: UInt32(cgImage.bitsPerPixel),
                    colorSpace: Unmanaged.passRetained(sourceColorSpace),
                    bitmapInfo: cgImage.bitmapInfo,
                    version: 0,
                    decode: nil,
                    renderingIntent: cgImage.renderingIntent)
            }()
            
            /*
             The vImage buffer containing a scaled down copy of the source asset.
             */
            var sourceBuffer: vImage_Buffer = {
                var sourceImageBuffer = vImage_Buffer()
                
                vImageBuffer_InitWithCGImage(&sourceImageBuffer,
                                             &format,
                                             nil,
                                             cgImage,
                                             vImage_Flags(kvImageNoFlags))
                
                var scaledBuffer = vImage_Buffer()
                
                vImageBuffer_Init(&scaledBuffer,
                                  sourceImageBuffer.height / 3,
                                  sourceImageBuffer.width / 3,
                                  format.bitsPerPixel,
                                  vImage_Flags(kvImageNoFlags))
                
                vImageScale_ARGB8888(&sourceImageBuffer,
                                     &scaledBuffer,
                                     nil,
                                     vImage_Flags(kvImageNoFlags))
                
                return scaledBuffer
            }()
            
            /*
             The 1-channel, 8-bit vImage buffer used as the operation destination.
             */
            var destinationBuffer: vImage_Buffer = {
                var destinationBuffer = vImage_Buffer()
                
                vImageBuffer_Init(&destinationBuffer,
                                  sourceBuffer.height,
                                  sourceBuffer.width,
                                  8,
                                  vImage_Flags(kvImageNoFlags))
                
                return destinationBuffer
            }()
            
            // Declare the three coefficients that model the eye's sensitivity
            // to color.
            let redCoefficient: Float = 0.2126
            let greenCoefficient: Float = 0.7152
            let blueCoefficient: Float = 0.0722
            
            // Create a 1D matrix containing the three luma coefficients that
            // specify the color-to-grayscale conversion.
            let divisor: Int32 = 0x1000
            let fDivisor = Float(divisor)
            
            var coefficientsMatrix = [
                Int16(redCoefficient * fDivisor),
                Int16(greenCoefficient * fDivisor),
                Int16(blueCoefficient * fDivisor)
            ]
            
            // Use the matrix of coefficients to compute the scalar luminance by
            // returning the dot product of each RGB pixel and the coefficients
            // matrix.
            var preBias: Int16 = 0
            let postBias: Int32 = 0
            
            vImageMatrixMultiply_ARGB8888ToPlanar8(&sourceBuffer,
                                                   &destinationBuffer,
                                                   &coefficientsMatrix,
                                                   divisor,
                                                   &preBias,
                                                   postBias,
                                                   vImage_Flags(kvImageNoFlags))
            
            // Create a 1-channel, 8-bit grayscale format that's used to
            // generate a displayable image.
            var monoFormat = vImage_CGImageFormat(
                bitsPerComponent: 8,
                bitsPerPixel: 8,
                colorSpace: Unmanaged.passRetained(CGColorSpaceCreateDeviceGray()),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                version: 0,
                decode: nil,
                renderingIntent: .defaultIntent)
            
            // Create a Core Graphics image from the grayscale destination buffer.
            let result = vImageCreateCGImageFromBuffer(
                &destinationBuffer,
                &monoFormat,
                nil,
                nil,
                vImage_Flags(kvImageNoFlags),
                nil)
            
            print(4)
            
            // Display the grayscale result.
            if let result = result {
                let greyscaleImage = UIImage(cgImage: result.takeRetainedValue())
                imageView.image = greyscaleImage
                classify(image: greyscaleImage)
            } else {
                print("lol oh shit.")
            }
        }
    }
}
