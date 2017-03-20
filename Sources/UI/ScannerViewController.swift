//
//  ScannerViewController.swift
//  ChineseIDCardOCR
//
//  Created by GongXiang on 8/12/16.
//  Copyright © 2016 Kevin.Gong. All rights reserved.
//

import UIKit
import AVFoundation
import GPUImage

public struct IDCard {

    public let number: String // 身份证号
    public let image: UIImage // 身份证截图

//TODO
//添加其他字段的识别

}


open class ScannerViewController: UIViewController {

    @IBOutlet weak var focusView: FocusView!
    @IBOutlet weak var maskView: UIView!
    @IBOutlet weak var closeButton: UIButton!
    @IBOutlet weak var tipLabel: UILabel!
    @IBOutlet weak var waittingIndicator: UIActivityIndicatorView!

    // default 0.75
    @IBOutlet fileprivate weak var focusViewWidthLayoutConstraint: NSLayoutConstraint?

    let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 160, height: 100))
    
    let captureSession = AVCaptureSession()
    let device = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
    let output = AVCaptureStillImageOutput()

    let ocr = IDCardOCR()

    var observer: AnyObject?
    var repeatTimer: Timer?
    var recognizing = false

    var previewLayer: AVCaptureVideoPreviewLayer!

    open var didRecognizedHandler: ((IDCard) -> ())?

    public init() {
        super.init(nibName: "ScannerViewController", bundle: Bundle.ocrBundle())
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override open func viewDidLoad() {
        super.viewDidLoad()

        adjustfocusViewWidth()

        var input: AVCaptureDeviceInput

        do {
            input = try AVCaptureDeviceInput(device: device)
        } catch {
            return
        }

        guard captureSession.canAddInput(input) else { return }
        captureSession.addInput(input)

        guard captureSession.canAddOutput(output) else { return }
        captureSession.addOutput(output)

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
        previewLayer.connection.videoOrientation = .landscapeRight

        view.layer.insertSublayer(previewLayer, below: maskView.layer)

        focusView.layer.borderColor = UIColor.white.cgColor
        focusView.layer.borderWidth = 0.5
        focusView.layer.cornerRadius = 4
        focusView.isHidden = true



        let image = UIImage(named: "icon_close", in: Bundle.ocrBundle(), compatibleWith: nil)?.withRenderingMode(.alwaysTemplate)
        closeButton.tintColor = UIColor.white
        closeButton.setImage(image, for: UIControlState())
        closeButton.isHidden = true

        tipLabel.isHidden = true

        addNotification()
    }

    deinit {
        removeNotification()
    }

    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        captureSession.startRunning()
    }

    override open func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        captureSession.stopRunning()
    }

    override open func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = view.layer.bounds
        if let _ = maskView.layer.mask { refreshMask() }
    }

    @IBAction func touchClose(_ sender: UIButton) {

        captureSession.stopRunning()
        focusView.stopScaningAnimation()

        dismiss(animated: true, completion: nil)
    }

    // MARK: focus view layoutConstraint
    fileprivate func adjustfocusViewWidth() {

        let screenWidth = UIApplication.shared.statusBarOrientation == .landscapeRight ?
                          UIScreen.main.bounds.height : UIScreen.main.bounds.size.width

        var multiplier: CGFloat = 0.75

        switch screenWidth {
        case 320:
            multiplier = 0.75
        case 375:
            multiplier = 0.65
        default:
            multiplier = 0.5
        }

        if let c = focusViewWidthLayoutConstraint {
            view.removeConstraint(c)
            focusView.removeConstraint(c)
        }

        let layout = NSLayoutConstraint(item: focusView, attribute: .width, relatedBy: .equal, toItem: view, attribute: .width, multiplier: multiplier, constant: 0.0)
        view.addConstraint(layout)
        focusViewWidthLayoutConstraint = layout

        focusView.setNeedsUpdateConstraints()
    }

    // MARK: Notification
    fileprivate func addNotification() {
        
        observer = NotificationCenter.default.addObserver(forName: NSNotification.Name.AVCaptureSessionDidStartRunning, object: nil, queue: nil) { [weak self] _ in
            guard let sSelf = self else { return }
            sSelf.refreshMask()
            
            // 开始准备获取图片
            sSelf.repeatTimer = Timer.schedule(repeatInterval: 0.5) { timer in
                sSelf.captureImage(timer!)
            }
            
            //
            sSelf.focusView.isHidden = false
            sSelf.focusView.startScaningAnimation()
            
            //
            sSelf.closeButton.isHidden = false
            
            //
            sSelf.tipLabel.isHidden = false
            
            //
            sSelf.waittingIndicator.stopAnimating()
        }
    }

    fileprivate func refreshMask() {

        let path = UIBezierPath(rect: view.bounds)
        let focus = UIBezierPath(roundedRect: focusView.frame, cornerRadius: 4)

        path.append(focus.reversing())

        let maskLayer = CAShapeLayer()
        maskLayer.path = path.cgPath

        maskView.layer.mask = maskLayer
    }

    fileprivate func removeNotification() {

        guard let o = observer else { return }
        
        NotificationCenter.default.removeObserver(o)
    }

    fileprivate func captureImage(_ timer: Timer) {

        // the camera's focus is stable.
        guard !(device?.isAdjustingFocus)! else { return }
        guard !recognizing else { return }

        recognizing = true

        // 获取图片
        let settings = AVCaptureManualExposureBracketedStillImageSettings.manualExposureSettings(withExposureDuration: (device?.exposureDuration)!, iso: (device?.iso)!)
        let stillImageConnection = output.connection(withMediaType: AVMediaTypeVideo)
            stillImageConnection?.videoOrientation = .landscapeRight

        output.captureStillImageBracketAsynchronously(from: stillImageConnection, withSettingsArray: [settings], completionHandler: { (buffer, settings, error) in

            guard buffer != nil else {
                self.recognizing = false
                return
            }
            
            let imgData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(buffer)
            if let image = UIImage(data: imgData!) {

                let interestRect = self.previewLayer.metadataOutputRectOfInterest(for: self.focusView.frame)

                let rect = CGRect(x: interestRect.origin.x * image.size.width,
                    y: interestRect.origin.y * image.size.height,
                    width: interestRect.size.width * image.size.width,
                    height: interestRect.size.height * image.size.height)

                let croppedImage = image.crop(rect) // 身份证完整的图片
//                self.imageView.image = self.ocr?.cropNameImage(croppedImage);
//                self.imageView.sizeToFit()
//                self.view.addSubview(self.imageView);
                
                self.ocr?.recognizeIDCardNo(croppedImage) {
                    debugPrint($0)
                    let result = $0
                    if result.lengthOfBytes(using: String.Encoding.utf8) == 18 {
                        let number = result
                        DispatchQueue.main.async {
                            self.didRecognizedHandler?(IDCard(number: number, image: croppedImage))
                        }
                    }
                    self.recognizing = false
                }
            }
        })
    }

    // MARK: override supper
    override open var preferredStatusBarStyle : UIStatusBarStyle {
        return .lightContent
    }
    
    override open var preferredInterfaceOrientationForPresentation : UIInterfaceOrientation {
        return .landscapeRight
    }
    
    override open var supportedInterfaceOrientations : UIInterfaceOrientationMask {
        return .landscape
    }
    
    override open var shouldAutorotate : Bool {
        return false
    }
}
