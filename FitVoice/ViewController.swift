//
//  ViewController.swift
//  FitVoice
//
//  Created by Krystian Pietrzak on 14/01/2024.
//

import UIKit
import Speech

class ViewController: UIViewController {
    @IBOutlet weak var transcriptionTextView: UITextView!
    
    @IBAction func recordButtonTapped(_ sender: UIButton) {
        if isRecording {
            stopSpeechRecognition()
            sender.setTitle("Start Recording", for: .normal)
        } else {
            startSpeechRecognition()
            sender.setTitle("Stop Recording", for: .normal)
        }
        isRecording.toggle()
    }
    
    private var isRecording = false
    private let speechRecognizer = SFSpeechRecognizer()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        SFSpeechRecognizer.requestAuthorization { authStatus in
            switch authStatus {
            case .authorized:
                print("Speech recognition authorized")
            case .denied, .restricted, .notDetermined:
                print("Speech recognition not authorized")
            @unknown default:
                fatalError("Unknown authorization status")
            }
        }
    }
    
    func stopSpeechRecognition() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionTask?.cancel()
        recognitionTask = nil
    }

    
    func startSpeechRecognition() {
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Audio session setup failed: \(error)")
            return
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        let inputNode = audioEngine.inputNode  // Direct use without 'guard let'

        recognitionRequest?.shouldReportPartialResults = true

        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest!) { result, error in
            if let result = result {
                let transcribedText = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    self.transcriptionTextView.text = transcribedText
                }
            }
            if error != nil || result?.isFinal == true {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                self.recognitionRequest = nil
                self.recognitionTask = nil
            }
        }

        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try! audioEngine.start()
    }
    
}

