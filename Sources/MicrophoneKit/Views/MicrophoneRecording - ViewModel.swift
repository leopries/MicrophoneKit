//
//  MicrophoneRecordingViewModel.swift
//
//
//  Created by Leonard Pries on 22.08.24.
//

import AVFoundation
import Combine
import Foundation
import SoundAnalysis

@Observable public class MicrophoneRecordingViewModel {
    public let audioStreamManager = AudioStreamManager()
    public let audioStorage = AudioStorage()
    var cancellables = Set<AnyCancellable>()
    public var audioInputManager = AudioInputManager()
    private let audioLoudnessAnalyzer = AudioSequentAnalyzer<AudioLoudnessAnalyzerData>()
    
    // Timer
    private var timer: Timer?
    private var tenthsOfSecondElapsed = 0
    private var isTimerRunning = false
    
    // Config
    private let fileName: String
    public var afterSave: (URL) -> Void
    public var onNewData: (Double) -> Void
    
    public init(
        fileName: String,
        afterSave: @escaping (URL) -> Void = { _ in },
        onNewData: @escaping (Double) -> Void = { _ in }
    ) {
        self.fileName = fileName
        self.afterSave = afterSave
        self.onNewData = onNewData
        Task {
            await audioStreamManager.requestAuthorization()
        }
    }
    
    public func startRecording() {
        print("🎙️ start analyze")
        do {
            try audioStreamManager.setupCaptureSession(using: audioInputManager.inputDevice)
            try audioLoudnessAnalyzer.setupAnalyzer(audioStream: audioStreamManager.audioStream)
            
            audioLoudnessAnalyzer.publisher
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { _ in
                }) { data in
                    
                    self.onNewData(Double(data.rmsAmplitude))
                }
                .store(in: &cancellables)
            
            let documentPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let audioFilename = documentPath.appendingPathComponent("\(fileName).wav")
            try audioStorage.setupAudioStorage(audioStream: audioStreamManager.audioStream, output: audioFilename)
            
            try audioStreamManager.start()
            startTimer()
        } catch {
            print("☠️ analyzer not started, error=\(error)")
        }
    }
    
    public func stopRecording() {
        print("🎙️ stop analyze")
        let url = audioStorage.finishRecording()
        audioStreamManager.stop()
        if let url {
            print("URL: \(url)")
            afterSave(url)
        }
        stopTimer()
    }
    
    public func restart() {
        print("🎙️ stop analyze")
        let url = audioStorage.finishRecording()
        audioStreamManager.stop()
        if let url {
            print("URL: \(url)")
            afterSave(url)
        }
        startRecording()
    }
    
    public var timeFormatted: String {
        let totalSeconds = tenthsOfSecondElapsed / 10
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func startTimer() {
        if !isTimerRunning {
            isTimerRunning = true
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                self.tenthsOfSecondElapsed += 1
            }
        }
    }
    
    private func stopTimer() {
        isTimerRunning = false
        timer?.invalidate()
        tenthsOfSecondElapsed = 0
        timer = nil
    }
}
