//
// Copyright (C) 2015 CosmicMind, Inc. <http://cosmicmind.io> and other CosmicMind contributors
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program located at the root of the software package
// in a file called LICENSE.  If not, see <http://www.gnu.org/licenses/>.
//

import UIKit
import AVFoundation

private var CaptureSessionAdjustingExposureContext: UInt8 = 1

public enum CaptureSessionPreset {
	case High
}

/**
	:name:	CaptureSessionPresetToString
*/
public func CaptureSessionPresetToString(preset: CaptureSessionPreset) -> String {
	switch preset {
	case .High:
		return AVCaptureSessionPresetHigh
	}
}

@objc(CaptureSessionDelegate)
public protocol CaptureSessionDelegate {
	/**
	:name:	captureSessionFailedWithError
	*/
	optional func captureSessionFailedWithError(capture: CaptureSession, error: NSError)
	
	/**
	:name:	captureStillImageAsynchronously
	*/
	optional func captureStillImageAsynchronously(capture: CaptureSession, image: UIImage)
	
	/**
	:name:	captureStillImageAsynchronouslyFailedWithError
	*/
	optional func captureStillImageAsynchronouslyFailedWithError(capture: CaptureSession, error: NSError)
	
	/**
	:name:	captureCreateMovieFileFailedWithError
	*/
	optional func captureCreateMovieFileFailedWithError(capture: CaptureSession, error: NSError)
	
	/**
	:name:	captureMovieFailedWithError
	*/
	optional func captureMovieFailedWithError(capture: CaptureSession, error: NSError)
	
	/**
	:name:	captureDidStartRecordingToOutputFileAtURL
	*/
	optional func captureDidStartRecordingToOutputFileAtURL(capture: CaptureSession, captureOutput: AVCaptureFileOutput, fileURL: NSURL, fromConnections connections: [AnyObject])
	
	/**
	:name:	captureDidFinishRecordingToOutputFileAtURL
	*/
	optional func captureDidFinishRecordingToOutputFileAtURL(capture: CaptureSession, captureOutput: AVCaptureFileOutput, outputFileURL: NSURL, fromConnections connections: [AnyObject], error: NSError!)
}

@objc(CaptureSession)
public class CaptureSession : NSObject, AVCaptureFileOutputRecordingDelegate {
	/**
	:name:	videoQueue
	*/
	private lazy var videoQueue: dispatch_queue_t = dispatch_queue_create("io.materialkit.CaptureSession", nil)
	
	/**
	:name:	activeVideoInput
	*/
	private var activeVideoInput: AVCaptureDeviceInput?
	
	/**
	:name:	activeAudioInput
	*/
	private var activeAudioInput: AVCaptureDeviceInput?
	
	/**
	:name:	imageOutput
	*/
	private lazy var imageOutput: AVCaptureStillImageOutput = AVCaptureStillImageOutput()
	
	/**
	:name:	movieOutput
	*/
	private lazy var movieOutput: AVCaptureMovieFileOutput = AVCaptureMovieFileOutput()
	
	/**
	:name: session
	*/
	internal lazy var session: AVCaptureSession = AVCaptureSession()
	
	/**
	:name:	isRunning
	*/
	public private(set) lazy var isRunning: Bool = false
	
	/**
	:name:	isRecording
	*/
	public private(set) lazy var isRecording: Bool = false
	
	/**
	:name:	movieOutputURL
	*/
	public private(set) var movieOutputURL: NSURL?
	
	/**
	:name:	activeCamera
	*/
	public var activeCamera: AVCaptureDevice? {
		return activeVideoInput?.device
	}
	
	/**
	:name:	init
	*/
	public override init() {
		sessionPreset = .High
		super.init()
		prepareSession()
	}
	
	/**
	:name:	inactiveCamera
	*/
	public var inactiveCamera: AVCaptureDevice? {
		var device: AVCaptureDevice?
		if 1 < cameraCount {
			if activeCamera?.position == .Back {
				device = cameraWithPosition(.Front)
			} else {
				device = cameraWithPosition(.Back)
			}
		}
		return device
	}
	
	/**
	:name:	cameraCount
	*/
	public var cameraCount: Int {
		return AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo).count
	}
	
	/**
	:name:	canSwitchCameras
	*/
	public var canSwitchCameras: Bool {
		return 1 < cameraCount
	}
	
	/**
	:name:	caneraSupportsTapToFocus
	*/
	public var cameraSupportsTapToFocus: Bool {
		return activeCamera!.focusPointOfInterestSupported
	}
	
	/**
	:name:	cameraSupportsTapToExpose
	*/
	public var cameraSupportsTapToExpose: Bool {
		return activeCamera!.exposurePointOfInterestSupported
	}
	
	/**
	:name:	cameraHasFlash
	*/
	public var cameraHasFlash: Bool {
		return activeCamera!.hasFlash
	}
	
	/**
	:name:	cameraHasTorch
	*/
	public var cameraHasTorch: Bool {
		return activeCamera!.hasTorch
	}
	
	/**
	:name:	focusMode
	*/
	public var focusMode: AVCaptureFocusMode {
		get {
			return activeCamera!.focusMode
		}
		set(value) {
			var error: NSError?
			if isFocusModeSupported(focusMode) {
				do {
					let device: AVCaptureDevice = activeCamera!
					try device.lockForConfiguration()
					device.focusMode = focusMode
					device.unlockForConfiguration()
				} catch let e as NSError {
					error = e
				}
			} else {
				error = NSError(domain: "[MaterialKit Error: Unsupported focusMode.]", code: 0, userInfo: nil)
			}
			if let e: NSError = error {
				delegate?.captureSessionFailedWithError?(self, error: e)
			}
		}
	}
	
	/**
	:name:	flashMode
	*/
	public var flashMode: AVCaptureFlashMode {
		get {
			return activeCamera!.flashMode
		}
		set(value) {
			var error: NSError?
			if isFlashModeSupported(flashMode) {
				do {
					let device: AVCaptureDevice = activeCamera!
					try device.lockForConfiguration()
					device.flashMode = flashMode
					device.unlockForConfiguration()
				} catch let e as NSError {
					error = e
				}
			} else {
				error = NSError(domain: "[MaterialKit Error: Unsupported flashMode.]", code: 0, userInfo: nil)
			}
			if let e: NSError = error {
				delegate?.captureSessionFailedWithError?(self, error: e)
			}
		}
	}
	
	/**
	:name:	torchMode
	*/
	public var torchMode: AVCaptureTorchMode {
		get {
			return activeCamera!.torchMode
		}
		set(value) {
			var error: NSError?
			if isTorchModeSupported(torchMode) {
				do {
					let device: AVCaptureDevice = activeCamera!
					try device.lockForConfiguration()
					device.torchMode = torchMode
					device.unlockForConfiguration()
				} catch let e as NSError {
					error = e
				}
			} else {
				error = NSError(domain: "[MaterialKit Error: Unsupported torchMode.]", code: 0, userInfo: nil)
			}
			if let e: NSError = error {
				delegate?.captureSessionFailedWithError?(self, error: e)
			}
		}
	}
	
	/**
	:name:	sessionPreset
	*/
	public var sessionPreset: CaptureSessionPreset {
		didSet {
			session.sessionPreset = CaptureSessionPresetToString(sessionPreset)
		}
	}
	
	/**
	:name:	sessionPreset
	*/
	public var currentVideoOrientation: AVCaptureVideoOrientation {
		var orientation: AVCaptureVideoOrientation
		switch UIDevice.currentDevice().orientation {
		case .Portrait:
			orientation = .Portrait
		case .LandscapeRight:
			orientation = .LandscapeLeft
		case .PortraitUpsideDown:
			orientation = .PortraitUpsideDown
		default:
			orientation = .LandscapeRight
		}
		return orientation
	}
	
	/**
	:name:	delegate
	*/
	public weak var delegate: CaptureSessionDelegate?
	
	/**
	:name:	startSession
	*/
	public func startSession() {
		if !isRunning {
			dispatch_async(videoQueue) {
				self.session.startRunning()
			}
		}
	}
	
	/**
	:name:	startSession
	*/
	public func stopSession() {
		if isRunning {
			dispatch_async(videoQueue) {
				self.session.stopRunning()
			}
		}
	}
	
	/**
	:name:	switchCameras
	*/
	public func switchCameras() {
		if canSwitchCameras {
			dispatch_async(videoQueue) {
				do {
					let videoInput: AVCaptureDeviceInput? = try AVCaptureDeviceInput(device: self.inactiveCamera!)
					self.session.beginConfiguration()
					self.session.removeInput(self.activeVideoInput)
					
					if self.session.canAddInput(videoInput) {
						self.session.addInput(videoInput)
						self.activeVideoInput = videoInput
					} else {
						self.session.addInput(self.activeVideoInput)
					}
					self.session.commitConfiguration()
				} catch let e as NSError {
					self.delegate?.captureSessionFailedWithError?(self, error: e)
				}
			}
		}
	}
	
	/**
	:name:	isFocusModeSupported
	*/
	public func isFocusModeSupported(focusMode: AVCaptureFocusMode) -> Bool {
		return activeCamera!.isFocusModeSupported(focusMode)
	}
	
	/**
	:name:	isExposureModeSupported
	*/
	public func isExposureModeSupported(exposureMode: AVCaptureExposureMode) -> Bool {
		return activeCamera!.isExposureModeSupported(exposureMode)
	}
	
	/**
	:name:	isFlashModeSupported
	*/
	public func isFlashModeSupported(flashMode: AVCaptureFlashMode) -> Bool {
		return activeCamera!.isFlashModeSupported(flashMode)
	}
	
	/**
	:name:	isTorchModeSupported
	*/
	public func isTorchModeSupported(torchMode: AVCaptureTorchMode) -> Bool {
		return activeCamera!.isTorchModeSupported(torchMode)
	}
	
	/**
	:name:	focusAtPoint
	*/
	public func focusAtPoint(point: CGPoint) {
		var error: NSError?
		if cameraSupportsTapToFocus && isFocusModeSupported(.AutoFocus) {
			do {
				let device: AVCaptureDevice = activeCamera!
				try device.lockForConfiguration()
				device.focusPointOfInterest = point
				device.focusMode = .AutoFocus
				device.unlockForConfiguration()
			} catch let e as NSError {
				error = e
			}
		} else {
			error = NSError(domain: "[MaterialKit Error: Unsupported focusAtPoint.]", code: 0, userInfo: nil)
		}
		if let e: NSError = error {
			delegate?.captureSessionFailedWithError?(self, error: e)
		}
	}
	
	/**
	:name:	exposeAtPoint
	*/
	public func exposeAtPoint(point: CGPoint) {
		var error: NSError?
		if cameraSupportsTapToExpose && isExposureModeSupported(.ContinuousAutoExposure) {
			do {
				let device: AVCaptureDevice = activeCamera!
				try device.lockForConfiguration()
				device.exposurePointOfInterest = point
				device.exposureMode = .ContinuousAutoExposure
				if device.isExposureModeSupported(.Locked) {
					device.addObserver(self, forKeyPath: "adjustingExposure", options: .New, context: &CaptureSessionAdjustingExposureContext)
				}
				device.unlockForConfiguration()
			} catch let e as NSError {
				error = e
			}
		} else {
			error = NSError(domain: "[MaterialKit Error: Unsupported exposeAtPoint.]", code: 0, userInfo: nil)
		}
		if let e: NSError = error {
			delegate?.captureSessionFailedWithError?(self, error: e)
		}
	}
	
	/**
	:name:	observeValueForKeyPath
	*/
	public override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
		if context == &CaptureSessionAdjustingExposureContext {
			let device: AVCaptureDevice = object as! AVCaptureDevice
			if !device.adjustingExposure && device.isExposureModeSupported(.Locked) {
				object!.removeObserver(self, forKeyPath: "adjustingExposure", context: &CaptureSessionAdjustingExposureContext)
				dispatch_async(dispatch_get_main_queue()) {
					do {
						try device.lockForConfiguration()
						device.exposureMode = .Locked
						device.unlockForConfiguration()
					} catch let e as NSError {
						self.delegate?.captureSessionFailedWithError?(self, error: e)
					}
				}
			}
		} else {
			super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
		}
	}
	
	/**
	:name:	resetFocusAndExposureModes
	*/
	public func resetFocusAndExposureModes() {
		let device: AVCaptureDevice = activeCamera!
		let canResetFocus: Bool = device.focusPointOfInterestSupported && device.isFocusModeSupported(.ContinuousAutoFocus)
		let canResetExposure: Bool = device.exposurePointOfInterestSupported && device.isExposureModeSupported(.ContinuousAutoExposure)
		let centerPoint: CGPoint = CGPointMake(0.5, 0.5)
		do {
			try device.lockForConfiguration()
			if canResetFocus {
				device.focusMode = .ContinuousAutoFocus
				device.focusPointOfInterest = centerPoint
			}
			if canResetExposure {
				device.exposureMode = .ContinuousAutoExposure
				device.exposurePointOfInterest = centerPoint
			}
			device.unlockForConfiguration()
		} catch let e as NSError {
			delegate?.captureSessionFailedWithError?(self, error: e)
		}
	}
	
	/**
	:name:	captureStillImage
	*/
	public func captureStillImage() {
		let connection: AVCaptureConnection = imageOutput.connectionWithMediaType(AVMediaTypeVideo)
		connection.videoOrientation = currentVideoOrientation
		imageOutput.captureStillImageAsynchronouslyFromConnection(connection) { (sampleBuffer: CMSampleBuffer!, error: NSError!) -> Void in
			if nil == error {
				let data: NSData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(sampleBuffer)
				self.delegate?.captureStillImageAsynchronously?(self, image: UIImage(data: data)!)
			} else {
				self.delegate?.captureStillImageAsynchronouslyFailedWithError?(self, error: error!)
			}
		}
	}
	
	/**
	:name:	startRecording
	*/
	public func startRecording() {
		dispatch_async(videoQueue) {
			if !self.isRecording {
				let connection: AVCaptureConnection = self.movieOutput.connectionWithMediaType(AVMediaTypeVideo)
				connection.videoOrientation = self.currentVideoOrientation
				connection.preferredVideoStabilizationMode = .Auto
				
				let device: AVCaptureDevice = self.activeCamera!
				if device.smoothAutoFocusSupported {
					do {
						try device.lockForConfiguration()
						device.smoothAutoFocusEnabled = true
						device.unlockForConfiguration()
					} catch let e as NSError {
						self.delegate?.captureSessionFailedWithError?(self, error: e)
					}
				}
				
				self.movieOutputURL = self.uniqueURL()
				if let v: NSURL = self.movieOutputURL {
					self.movieOutput.startRecordingToOutputFileURL(v, recordingDelegate: self)
				}
			}
		}
	}
	
	/**
	:name:	captureOutput
	*/
	public func captureOutput(captureOutput: AVCaptureFileOutput!, didStartRecordingToOutputFileAtURL fileURL: NSURL!, fromConnections connections: [AnyObject]!) {
		isRecording = true
		delegate?.captureDidStartRecordingToOutputFileAtURL?(self, captureOutput: captureOutput, fileURL: fileURL, fromConnections: connections)
	}
	
	/**
	:name:	captureOutput
	*/
	public func captureOutput(captureOutput: AVCaptureFileOutput!, didFinishRecordingToOutputFileAtURL outputFileURL: NSURL!, fromConnections connections: [AnyObject]!, error: NSError!) {
		isRecording = false
		delegate?.captureDidFinishRecordingToOutputFileAtURL?(self, captureOutput: captureOutput, outputFileURL: outputFileURL, fromConnections: connections, error: error)
	}
	
	/**
	:name:	stopRecording
	*/
	public func stopRecording() {
		if isRecording {
			movieOutput.stopRecording()
		}
	}
	
	/**
	:name:	prepareSession
	*/
	private func prepareSession() {
		prepareVideoInput()
		prepareAudioInput()
		prepareImageOutput()
		prepareMovieOutput()
	}
	
	/**
	:name:	prepareVideoInput
	*/
	private func prepareVideoInput() {
		do {
			activeVideoInput = try AVCaptureDeviceInput(device: AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo))
			if session.canAddInput(activeVideoInput) {
				session.addInput(activeVideoInput)
			}
		} catch let e as NSError {
			delegate?.captureSessionFailedWithError?(self, error: e)
		}
	}
	
	/**
	:name:	prepareAudioInput
	*/
	private func prepareAudioInput() {
		do {
			activeAudioInput = try AVCaptureDeviceInput(device: AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeAudio))
			if session.canAddInput(activeAudioInput) {
				session.addInput(activeAudioInput)
			}
		} catch let e as NSError {
			delegate?.captureSessionFailedWithError?(self, error: e)
		}
	}
	
	/**
	:name:	prepareImageOutput
	*/
	private func prepareImageOutput() {
		if session.canAddOutput(imageOutput) {
			imageOutput.outputSettings = [AVVideoCodecKey: AVVideoCodecJPEG]
			session.addOutput(imageOutput)
		}
	}
	
	/**
	:name:	prepareMovieOutput
	*/
	private func prepareMovieOutput() {
		if session.canAddOutput(movieOutput) {
			session.addOutput(movieOutput)
		}
	}
	
	/**
	:name:	cameraWithPosition
	*/
	private func cameraWithPosition(position: AVCaptureDevicePosition) -> AVCaptureDevice? {
		let devices: Array<AVCaptureDevice> = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo) as! Array<AVCaptureDevice>
		for device in devices {
			if device.position == position {
				return device
			}
		}
		return nil
	}
	
	/**
	:name:	uniqueURL
	*/
	private func uniqueURL() -> NSURL? {
		do {
			let directory: NSURL = try NSFileManager.defaultManager().URLForDirectory(.DocumentDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true)
			return directory.URLByAppendingPathComponent("temp_movie.mov")
		} catch let e as NSError {
			delegate?.captureCreateMovieFileFailedWithError?(self, error: e)
		}
		return nil
	}
}
