//
//  DiffusionManager.swift
//  MobileDiffusion
//
//  Created by apple on 9/15/23.
//

import UIKit
import Combine
import StableDiffusion

class DiffusionError: Codable, Error {
    public var message: String?

    private enum CodingKeys: String, CodingKey {
        case message
    }
    
    init(message: String) {
        self.message = message
    }
}

enum DiffusionImageBatchMode: Int {
    // 一张一张生成
    case loop
    // 同时生成
    case batch
}

struct DiffusionImageConfigure {
    var steps: Int = 20
    var seed: UInt32 = 0
    var guidanceScale: Double = 7.5
    var numOfImages = 1
    var batchMode: DiffusionImageBatchMode = .batch
    var positivePrompt: String = "Dog"
    var negativePrompt: String = ""
    var disableSafety: Bool = false
    var previewsCount: Int = 1
    var schedulerType: StableDiffusionScheduler = .dpmSolverMultistepScheduler
}

protocol DiffusionManagerDelegate {
    func diffusionDidModelDoweloading(progress: Double)
    func diffusionDidModelUnCompressing()
    func diffusionDidModelLoading()
    func diffusionDidModelLoaded()
    func diffusionDidModelFailure(error: DiffusionError)
    func diffusionDidImagePreviewCreated(step: Int, images: [CGImage?])
    func diffusionDidImageGenerated(results: [GenerationResult])
    func diffusionDidImageGenerateFailure(error: DiffusionError)
    func diffusionDiDInfoUpdate(time: Int, total: Int, available: Int, used: Int)
}

class DiffusionManager: NSObject {
    var delegate: DiffusionManagerDelegate
    var stateSubscriber: Cancellable?
    var generation = GenerationContext()
    var imageTask: Task<Void, Never>? = nil
    var results: [GenerationResult] = []
    var timestamp: Int = 0

    init(delegate: DiffusionManagerDelegate) {
        self.delegate = delegate
    }
    
    public func setup(model: ModelInfo) {
        loadModel(model, skipUnload: true)
        startMemeryInfo()
    }
    
    public func loadModel(_ model: ModelInfo, skipUnload: Bool = false) {
        self.timestamp = 0
        if !skipUnload {
            generation.pipeline?.setCancelled()
        }
        Task.init {
            let loader = PipelineLoader(model: model)
            stateSubscriber = loader.statePublisher.sink { state in
                DispatchQueue.main.async {
                    switch state {
                    case .downloading(let progress):
                        self.delegate.diffusionDidModelDoweloading(progress: progress)
                    case .uncompressing:
                        self.delegate.diffusionDidModelUnCompressing()
                    case .readyOnDisk:
                        self.delegate.diffusionDidModelLoading()
                    default:
                        break
                    }
                }
            }
            do {
                generation.delegate = self
                generation.pipeline = try await loader.prepare()
                DispatchQueue.main.async {
                    self.delegate.diffusionDidModelLoaded()
                }
            }  catch {
                DispatchQueue.main.async {
                    self.delegate.diffusionDidModelFailure(error: DiffusionError(message: error.localizedDescription))
                }
            }
        }
    }
    
    public var isCreating: Bool {
        if case .running = self.generation.state {
            return true
        } else {
            return false
        }
    }
    
    public func createImageFromText(configure: DiffusionImageConfigure) -> DiffusionError? {
        if case .running = self.generation.state {
            return DiffusionError(message: "diffusion.image_creating")
        }
  
        let loopCount = configure.batchMode == .batch ? 0 : (configure.numOfImages - 1)
        imageTask = Task {
            var results: [GenerationResult] = []
            for _ in (0...loopCount) {
                generation.state = .running(nil)
                do {
                    self.timestamp = 0
                    generation.positivePrompt = configure.positivePrompt
                    generation.negativePrompt = configure.negativePrompt
                    if configure.batchMode == .batch {
                        generation.imageCount = configure.numOfImages
                    } else {
                        generation.imageCount = 1
                    }
                    generation.guidanceScale = configure.guidanceScale
                    generation.disableSafety = configure.disableSafety
                    generation.steps = configure.steps
                    generation.seed = configure.seed
                    generation.previews = Double(configure.previewsCount)
                    let r = try await generation.generate()
                    if configure.batchMode == .loop {
                        results.append(contentsOf: r)
                    } else {
                        results = r
                    }
                    generation.state = .complete(generation.positivePrompt, results[0].image, results[0].lastSeed, results[0].interval)
                    self.delegate.diffusionDidImageGenerated(results: results)
                } catch {
                    generation.state = .failed(error)
                    DispatchQueue.main.async {
                        self.delegate.diffusionDidImageGenerateFailure(error: DiffusionError(message: error.localizedDescription))
                    }
                }
            }
        }
        return nil
    }
    
    public func cancelCreateImageFromText() {
        self.generation.cancelGeneration()
    }
    
    public func willTerminate() {
        self.generation.pipeline?.setCancelled()
    }
    
    private func startMemeryInfo() {
        _ = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            DispatchQueue.main.async {
                self.timestamp += 1
                let (total, available) = self.getSystemMemoryInfo()
                self.delegate.diffusionDiDInfoUpdate(time: self.timestamp, total: Int(total), available: Int(available), used: Int(self.calcMemory()))
            }
        }
    }
    
    private func calcMemory() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if kerr == KERN_SUCCESS {
            let usedMB = Double(info.resident_size) / 1024.0 / 1024.0
            return usedMB
        } else {
            return 0
        }
    }
    
    private func getSystemMemoryInfo() -> (totalMemoryMB: Double, freeMemoryMB: Double) {
        var totalMemory: UInt64 = 0
        var freeMemory: vm_size_t = 0

        // 获取总内存大小
        var mib: [Int32] = [CTL_HW, HW_MEMSIZE]
        var length = MemoryLayout<UInt64>.size
        sysctl(&mib, 2, &totalMemory, &length, nil, 0)

        // 获取可用内存大小
        var page_size: vm_size_t = 0
        var vm_stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        host_page_size(mach_host_self(), &page_size)

        withUnsafeMutablePointer(to: &vm_stats) { (vmStatsPointer) in
            _ = withUnsafeMutablePointer(to: &count) { (countPointer) in
                vmStatsPointer.withMemoryRebound(to: integer_t.self, capacity: 1) { reboundPointer in
                    host_statistics64(
                        mach_host_self(),
                        HOST_VM_INFO,
                        reboundPointer,
                        countPointer
                    )
                }
            }
        }

        freeMemory = vm_size_t(vm_stats.free_count) * page_size

        // 转换为MB
        let totalMemoryMB = Double(totalMemory) / 1024 / 1024
        let freeMemoryMB = Double(freeMemory) / 1024 / 1024

        return (totalMemoryMB, freeMemoryMB)
    }
}

extension DiffusionManager: GenerationContextDelegate {
    func generationDidUdpateProgress(progress: StableDiffusionProgress) {
        DispatchQueue.main.async {
            self.delegate.diffusionDidImagePreviewCreated(step: progress.step, images: progress.currentImages)
        }
    }
}
