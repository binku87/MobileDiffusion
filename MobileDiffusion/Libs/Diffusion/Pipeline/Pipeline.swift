//
//  Pipeline.swift
//  Diffusion
//
//  Created by Pedro Cuenca on December 2022.
//  See LICENSE at https://github.com/huggingface/swift-coreml-diffusers/LICENSE
//

import Foundation
import CoreML
import Combine
import StableDiffusion

public struct StableDiffusionProgress {
    var progress: StableDiffusionPipeline.Progress

    var step: Int { progress.step }
    var stepCount: Int { progress.stepCount }

    var currentImages: [CGImage?]
    
    init(progress: StableDiffusionPipeline.Progress, previewCount: Int) {
        self.progress = progress
        self.currentImages = []

        /*
         0: []
         1: [0]
         2: [0, 5]
         3: [0, 3, 6]
         4: [0, 2, 4, 6]
         5: [0, 2, 4, 6, 8]
         6: [0, 1, 2, 3, 4, 5]
         7: [0, 1, 2, 3, 4, 5, 6]
         8: [0, 1, 2, 3, 4, 5, 6, 7]
         9: [0, 1, 2, 3, 4, 5, 6, 7, 8]
         10: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
         11: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
         12: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
        */
        let stepCount = progress.stepCount
        var needPreviewSteps: [Int] = []
        if previewCount > 0 {
            if previewCount > stepCount {
                needPreviewSteps = (0...stepCount).compactMap({ $0 })
            } else {
                let space = stepCount / (previewCount == 0 ? stepCount : previewCount)
                var current = 0
                while true {
                    needPreviewSteps.append(current)
                    current += space
                    if current > stepCount {
                        break
                    }
                    if needPreviewSteps.count >= previewCount {
                        needPreviewSteps.append(stepCount)
                        break
                    }
                    if current + space > stepCount {
                        current = stepCount
                    }
                }
            }
        } else {
            needPreviewSteps = [stepCount]
        }
        needPreviewSteps.removeLast()
        if needPreviewSteps.contains(progress.step) {
            self.currentImages = progress.currentImages
        } else {
            self.currentImages = []
        }
    }
}

struct GenerationResult {
    var image: CGImage?
    var lastSeed: UInt32
    var interval: TimeInterval?
    var userCanceled: Bool
    var itsPerSecond: Double?
}

class Pipeline {
    let pipeline: StableDiffusionPipelineProtocol
    let maxSeed: UInt32
    
    var isXL: Bool {
        if #available(macOS 14.0, iOS 17.0, *) {
            return (pipeline as? StableDiffusionXLPipeline) != nil
        }
        return false
    }

    var progress: StableDiffusionProgress? = nil {
        didSet {
            progressPublisher.value = progress
        }
    }
    lazy private(set) var progressPublisher: CurrentValueSubject<StableDiffusionProgress?, Never> = CurrentValueSubject(progress)
    
    private var canceled = false

    init(_ pipeline: StableDiffusionPipelineProtocol, maxSeed: UInt32 = UInt32.max) {
        self.pipeline = pipeline
        self.maxSeed = maxSeed
    }
    
    func generate(
        prompt: String,
        negativePrompt: String = "",
        scheduler: StableDiffusionScheduler,
        numInferenceSteps stepCount: Int = 2,
        seed: UInt32 = 0,
        numPreviews previewCount: Int = 5,
        guidanceScale: Float = 7.5,
        disableSafety: Bool = false,
        imageCount: Int = 1,
        progress: @escaping (StableDiffusionProgress) -> Void
    ) throws -> [GenerationResult] {
        let beginDate = Date()
        canceled = false
        let theSeed = seed > 0 ? seed : UInt32.random(in: 1...maxSeed)
        let sampleTimer = SampleTimer()
        sampleTimer.start()
        
        var config = StableDiffusionPipeline.Configuration(prompt: prompt)
        config.negativePrompt = negativePrompt
        config.stepCount = stepCount
        config.seed = theSeed
        config.guidanceScale = guidanceScale
        config.disableSafety = disableSafety
        config.schedulerType = .dpmSolverMultistepScheduler
        config.useDenoisedIntermediates = true
        config.imageCount = imageCount
        if isXL {
            config.encoderScaleFactor = 0.13025
            config.decoderScaleFactor = 0.13025
        }
        
        let images = try pipeline.generateImages(configuration: config) { p in
            sampleTimer.stop()
            let newProgress = StableDiffusionProgress(progress: p, previewCount: previewCount)
            handleProgress(newProgress, sampleTimer: sampleTimer)
            progress(newProgress)
            if p.stepCount != p.step {
                sampleTimer.start()
            }
            return !canceled
        }
        let interval = Date().timeIntervalSince(beginDate)
        print("Got images: \(images) in \(interval)")
        var results: [GenerationResult] = []
        images.forEach { image in
            results.append(GenerationResult(image: image, lastSeed: theSeed, interval: interval, userCanceled: canceled, itsPerSecond: 1.0/sampleTimer.median))
        }
        return results
    }

    func handleProgress(_ progress: StableDiffusionProgress, sampleTimer: SampleTimer) {
        self.progress = progress
    }
        
    func setCancelled() {
        canceled = true
        pipeline.unloadResources()
    }
}
