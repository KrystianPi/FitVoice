//
//  ViewController.swift
//  FitVoice
//
//  Created by Krystian Pietrzak on 14/01/2024.
//

import UIKit
import Speech

class WaveformView: UIView {
    private var bars: [UIView] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupBars()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupBars()
    }

    private func setupBars() {
        let numberOfBars = 15  // You can adjust this
        let barWidth = self.bounds.width / CGFloat(numberOfBars)

        for i in 0..<numberOfBars {
            let bar = UIView(frame: CGRect(x: CGFloat(i) * barWidth, y: 0, width: barWidth, height: self.bounds.height))
            bar.backgroundColor = .blue
            addSubview(bar)
            bars.append(bar)
        }
    }
    
    func resetBars() {
        for bar in self.bars {
            bar.frame.size.height = 0
            bar.frame.origin.y = self.bounds.height / 2
        }
    }

    func animate() {
        UIView.animate(withDuration: 0.3) {
            for bar in self.bars {
                let randomHeight = CGFloat.random(in: 0...self.bounds.height)
                bar.frame.size.height = randomHeight
                bar.frame.origin.y = (self.bounds.height - randomHeight) / 2
            }
        }
    }
}


class ViewController: UIViewController {
    @IBOutlet weak var transcriptionTextView: UITextView!
    
    @IBOutlet weak var responseTextView: UITextView!
    @IBOutlet weak var sendButton: UIButton!
    
    @IBAction func recordButtonTapped(_ sender: UIButton) {
        sendButton.isHidden = !isRecording
        if isRecording {
            waveformView.resetBars()
            stopWaveformAnimation()
            stopSpeechRecognition()
            sender.setTitle("Record", for: .normal)
        } else {
            startWaveformAnimation()
            startSpeechRecognition()
            sender.setTitle("Done", for: .normal)
        }
        isRecording.toggle()
    }
    
    @IBAction func sendButtonTapped(_ sender: UIButton) {
        sendTranscribedTextToAPI(recordedText: currentTranscribedText)
    }
    
    private func sendTranscribedTextToAPI(recordedText: String) {
        print("Preparing to send text to API:", recordedText)}
    
    private var isRecording = false
    private let speechRecognizer = SFSpeechRecognizer()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var waveformView: WaveformView!
    private var timer: Timer?
    private var currentTranscribedText = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        sendButton.isHidden = true
        setGradientBackground()
        waveformView = WaveformView(frame: CGRect(x: 20, y: 390, width: view.bounds.width - 40, height: 50))
                view.addSubview(waveformView)
        waveformView.resetBars()
        transcriptionTextView.backgroundColor = UIColor.clear
        responseTextView.backgroundColor = UIColor.clear
        transcriptionTextView.textColor = UIColor.white
        responseTextView.textColor = UIColor.white
        transcriptionTextView.font = UIFont.systemFont(ofSize: 20)
        responseTextView.font = UIFont.systemFont(ofSize: 20)
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
    
    func setGradientBackground() {
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [UIColor.systemBlue.cgColor, UIColor.systemPurple.cgColor]
        gradientLayer.locations = [0.0, 1.0]
        gradientLayer.frame = self.view.bounds
        
        self.view.layer.insertSublayer(gradientLayer, at: 0)
    }
    
    func startWaveformAnimation() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.waveformView.animate()
        }
    }
    
    func stopWaveformAnimation() {
        timer?.invalidate()
        timer = nil
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
                
                // Check if the transcribed text is not empty before updating
                if !transcribedText.isEmpty {
                    self.currentTranscribedText = transcribedText
                    DispatchQueue.main.async {
                        self.transcriptionTextView.text = transcribedText
                        print("text: \(self.transcriptionTextView.text)")
                        print("text1: \(self.currentTranscribedText)")
                    }
                }
            }

            // Only stop the audio engine and cleanup if there's an error or it's the final result
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

