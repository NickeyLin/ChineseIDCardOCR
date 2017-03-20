//
//  OCR-Training.swift
//  ChineseIDCardOCR
//
//  Created by GongXiang on 8/12/16.
//  Copyright © 2016 Kevin.Gong. All rights reserved.
//

import UIKit

class OCRTraining {

    let ocr = IDCardOCR()!

    let trainingBackgroundImage = UIImage(named: "idbackground")!

    let documentsDirectory: URL = {
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return urls[urls.endIndex - 1]
    }()

    init() {}

    func trainging(_ size: Int) {

        let errorThreshold = Float(2)

        let trainingData = generateRealisticCharSet(size)
        let testData = generateRealisticCharSet(size / 20)

        let trainingInputs = trainingData.map { $0.0 }
        let trainingAnswers = trainingData.map { $0.1 }
        let testInputs = testData.map { $0.0 }
        let testAnswers = testData.map { $0.1}

        do {
            try globalNetwork.train(inputs: trainingInputs, answers: trainingAnswers, testInputs: testInputs, testAnswers: testAnswers, errorThreshold: errorThreshold)

            saveOCR()
        } catch {
            print(error)
        }

    }

    fileprivate func generateRealisticCharSet(_ size: Int) -> [([Float],[Float])] {

        var trainingSet = [([Float],[Float])]()

        let randomCode: () -> String = {
            let randomCharacter: () -> String = {
                let charArray = Array(recognizableCharacters.characters)
                let randomDouble = Double(arc4random())/(Double(UINT32_MAX) + 1)
                let randomIndex  = Int(floor(randomDouble * Double(charArray.count)))
                return String(charArray[randomIndex])
            }

            var code = ""

            for _ in 0 ..< 18 {
                code += randomCharacter()
            }

            return code
        }

        let customImage: (String) -> UIImage = { [unowned self] code in

            let bg = self.trainingBackgroundImage

            UIGraphicsBeginImageContext(bg.size)
            bg.draw(in: CGRect(origin: CGPoint.zero, size: bg.size))

            NSString(string: code).draw(in: CGRect(origin: CGPoint(x: 15, y: 20), size: bg.size), withAttributes: [NSFontAttributeName: UIFont(name: "OCR-B 10 BT", size: 25)!])

            let customImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()

            return customImage!
        }

        for _ in 0 ..< size {

            let code = randomCode()
            let currentCustomImage = customImage(code)

            //Generate Training set

            let blobs = ocr.extractBlobs(currentCustomImage)

            if blobs.count == 18 {

                for blobIndex in 0..<blobs.count {

                    let blob = blobs[blobIndex]

                    let imageData = ocr.convertImageToFloatArray(blob.0)

                    var imageAnswer = [Float](repeating: 0, count: recognizableCharacters.characters.count)
                    if let index = Array(recognizableCharacters.characters).index(of: Array(code.characters)[blobIndex]) {
                        imageAnswer[index] = 1
                    }

                    trainingSet.append((imageData,imageAnswer))
                }
            }
        }

        return trainingSet
    }

    func saveOCR() {
        globalNetwork.writeToFile(url())
    }

    func url() -> URL {
        return documentsDirectory.appendingPathComponent("OCR-Network")
    }
}
