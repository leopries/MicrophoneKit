//
//  AudioStorage.swift
//  thesis_voice_24
//
//  Created by Leonard Pries on 01.07.24.
//

import AVFoundation
import Combine
import Foundation

final public class AudioStorage {
    private var cancellable: AnyCancellable?
    var audioFile: AVAudioFile?


    func setupAudioStorage(audioStream: AnyPublisher<AudioData, AudioManagerError>, output: URL) throws {
        cancellable = audioStream
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in
                self.audioFile = nil
            }, receiveValue: { audioData in
                try? self.writePCMBuffer(buffer: audioData.buffer, output: output)
            })
    }

    /// Stops recording, closes the file, and returns its URL. Call this before stopping the stream
    /// so the WAV file is fully written and finalized before the URL is used.
    func finishRecording() -> URL? {
        cancellable?.cancel()
        cancellable = nil
        let url = audioFile?.url
        audioFile = nil
        return url
    }

    func writePCMBuffer(buffer: AVAudioPCMBuffer, output: URL) throws {
        guard buffer.frameLength > 0 else { return }
        do {
            if audioFile == nil {
                let adjustedUrl = adjustedURLForFormat(output: output, formatID: buffer.format.settings[AVFormatIDKey] as? UInt32)
                audioFile = try openAudioFile(buffer: buffer, output: adjustedUrl)
            }
            try audioFile?.write(from: buffer)
        } catch {
            print("Could not write file, error=\(error.localizedDescription)")
        }
    }

    private func adjustedURLForFormat(output: URL, formatID: UInt32?) -> URL {
            guard let formatID = formatID else { return output }
            let extensionMapping: [UInt32: String] = [
                kAudioFormatLinearPCM: "wav", // or "aif" for AIFF
                kAudioFormatAppleLossless: "m4a",
                kAudioFormatMPEG4AAC: "m4a"
            ]
            let fileExtension = extensionMapping[formatID] ?? "caf" // default to .caf if unknown format
            var newOutput = output
            if output.pathExtension != fileExtension {
                newOutput.deletePathExtension()
                newOutput.appendPathExtension(fileExtension)
            }
            return newOutput
        }

    private func openAudioFile(buffer: AVAudioPCMBuffer, output: URL) throws -> AVAudioFile {
        let formatID = buffer.format.settings[AVFormatIDKey] as? UInt32 ?? kAudioFormatLinearPCM
        let isFloat = formatID == kAudioFormatLinearPCM && (buffer.format.settings[AVLinearPCMIsFloatKey] as? Bool == true)
        let bitDepth = buffer.format.settings[AVLinearPCMBitDepthKey] as? Int ?? (isFloat ? 32 : 16)
        let settings: [String: Any] = [
            AVFormatIDKey: formatID,
            AVNumberOfChannelsKey: buffer.format.settings[AVNumberOfChannelsKey] ?? 1,
            AVSampleRateKey: buffer.format.settings[AVSampleRateKey] ?? 44100,
            AVLinearPCMBitDepthKey: bitDepth,
            AVLinearPCMIsFloatKey: isFloat
        ]
        do {
            let audioFile = try AVAudioFile(forWriting: output, settings: settings, commonFormat: buffer.format.commonFormat, interleaved: buffer.format.isInterleaved)
            self.audioFile = audioFile
            return audioFile
        } catch {
            debugPrint("☠️ error opening file at \(output.absoluteString)")
            throw error
        }
    }
}
