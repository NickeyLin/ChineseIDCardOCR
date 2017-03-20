//
//  IDCardOCR.swift
//  ChineseIDCardOCR
//
//  Created by GongXiang on 8/12/16.
//  Copyright © 2016 Kevin.Gong. All rights reserved.
//

import UIKit
import GPUImage
// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
    switch (lhs, rhs) {
    case let (l?, r?):
        return l < r
    case (nil, _?):
        return true
    default:
        return false
    }
}

// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
    switch (lhs, rhs) {
    case let (l?, r?):
        return l > r
    default:
        return rhs < lhs
    }
}


open class IDCardOCR : SwiftOCR {

    public typealias CompletionHandler = (String) -> ()
    
    fileprivate var network = globalNetwork
    
    // 为了加快识别速度 这里需要构建很多个 network
    fileprivate var numberNetwork: FFNN? // includ "x"
    fileprivate var chineseNetwork: FFNN?

    
    public init?(numberNetworkFileURL: URL = Bundle.ocrBundle().url(forResource: "OCR-Network", withExtension: nil)!, chineseNetworkFile: URL = Bundle.ocrBundle().url(forResource: "OCR-Network", withExtension: nil)!) {
        super.init()
        numberNetwork = FFNN.fromFile(numberNetworkFileURL)
        chineseNetwork = FFNN.fromFile(chineseNetworkFile)
        
        guard let _ = numberNetwork , let _ = chineseNetwork else { return nil}
    }
    
    public func testCropImage(_ image:UIImage) -> UIImage{
        return cropNumberImage(image)
    }
    open func recognizeIDCardNo(_ image:UIImage, completionHandler: @escaping CompletionHandler){
        
        DispatchQueue.global(qos: .userInitiated).async {
            let numberImage = self.cropNumberImage(image);
            super.recognize(numberImage, completionHandler)
        }
    }

    func cropNumberImage(_ image:UIImage) -> UIImage {
        let w = image.size.width * 0.6;
        let x = image.size.width * 0.31;
        let h = image.size.height * 0.14;
        let y = image.size.height * 0.79;
        
        return image.crop(CGRect(x: x, y: y, width: w, height: h));
    }
    func cropNumberImage(_ image: UIImage, faceBounds: CGRect) -> UIImage {
        
        // 这里的比例系数实根据身份证的比例，计算身份证号码所在位置
        let w = faceBounds.width * 3.1 //image.size.width //
        let x = faceBounds.width * 1.5 //CGFloat = 0 //
        let y = faceBounds.origin.y + faceBounds.height //image.size.height * 0.75// faceBounds.origin.y + faceBounds.height
        let h = image.size.height * 0.25
        
        // 这种处理会把 “公民身份号码” 这几个字截进来，但是问题不大 后期图像处理会处理掉
        return image.crop(CGRect(x: x, y: y, width: w, height: h)) // 只有身份证号码
    }
    func cropNameImage(_ image: UIImage) -> UIImage {
        
        let w = image.size.width * 0.15
        let h = image.size.height * 0.14
        
        let x = image.size.width * 0.16
        let y = image.size.height * 0.08
        
        return image.crop(CGRect(x: x, y: y, width: w, height: h)) // 只有名字
    }
    
    deinit {
        
        debugPrint("IDCardOCR deinit")
    }

   
}
