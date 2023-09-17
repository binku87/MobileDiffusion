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

    init(progress: StableDiffusionPipeline.Progress, previewIndices: [Bool]) {
        self.progress = progress
        self.currentImages = []

        /*if [0, 8, 15].contains(progress.step) {
            self.currentImages = progress.currentImages
        } else {
            self.currentImages = []
        }*/

        // Since currentImages is a computed property, only access the preview image if necessary
        //if progress.step < previewIndices.count, previewIndices[progress.step] {
        //if [0, 8, 15, 19, 20].contains(progress.step) {
            //self.currentImages = progress.currentImages
        //}
        //}
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
        config.seed = 3720662312 //theSeed
        config.guidanceScale = guidanceScale
        config.disableSafety = disableSafety
        config.schedulerType = .dpmSolverMultistepScheduler
        config.useDenoisedIntermediates = true
        config.imageCount = 1
        if isXL {
            config.encoderScaleFactor = 0.13025
            config.decoderScaleFactor = 0.13025
        }

        // Evenly distribute previews based on inference steps
        let previewIndices = previewIndices(stepCount, previewCount)

        let images = try pipeline.generateImages(configuration: config) { p in
            sampleTimer.stop()
            let newProgress = StableDiffusionProgress(progress: p, previewIndices: previewIndices)
            handleProgress(newProgress, sampleTimer: sampleTimer)
            progress(newProgress)
            if p.stepCount != p.step {
                //Thread.sleep(forTimeInterval: 3.0)
                print("Start...")
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
