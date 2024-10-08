//
//  Error.swift
//  thesis_voice_24
//
//  Created by Leonard Pries on 13.06.24.
//

import Foundation

enum AudioManagerError: Error, Equatable {
    case illegalOutputFile
    case illegalInputFile
    case illegalState
    case notAuthorized
    case noAudioFile
    case noModel
    case finished
    case finishedWithMessage(String)
    case other(Error)
    case audioDevice(OSStatus)
    case audioFile(OSStatus)

    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.illegalOutputFile, .illegalOutputFile),
             (.illegalInputFile, .illegalInputFile),
             (.illegalState, .illegalState),
             (.notAuthorized, .notAuthorized),
             (.noAudioFile, .noAudioFile),
             (.finished, .finished): return true
        case (.audioDevice(let lstatus), .audioDevice(let rstatus)):
            return lstatus == rstatus
        case (.audioFile(let lstatus), .audioFile(let rstatus)):
            return lstatus == rstatus
        case (.other, .other):
            return true
        default: return false
        }
    }
}
