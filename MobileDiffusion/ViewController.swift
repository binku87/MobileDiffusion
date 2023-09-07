//
//  ViewController.swift
//  MobileDiffusion
//
//  Created by apple on 9/4/23.
//

import UIKit
import Combine
import Darwin
import Foundation
import StableDiffusion

func calcMemory() -> Double {
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

extension Notification.Name {
    static let MemoryDidWarning = NSNotification.Name("MemoryDidWarning")
    static let AppWillTerminate = NSNotification.Name("AppWillTerminate")
}

extension NotificationCenter {
    func reinstall(observer: NSObject, name: Notification.Name, selector: Selector) {
        NotificationCenter.default.removeObserver(observer, name: name, object: nil)
        NotificationCenter.default.addObserver(observer, selector: selector, name: name, object: nil)
    }
}

class ViewController: UIViewController {
    @IBOutlet weak var vStatus: UILabel!
    @IBOutlet weak var vImage: UIImageView!
    @IBOutlet weak var vPrompt: UITextField!
    @IBOutlet weak var vMemory: UILabel!
    
    let model = ModelInfo.v21Base
    var generation = GenerationContext()
    var stateSubscriber: Cancellable?
    var imageTask: Task<Void, Never>? = nil
    var i = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        NotificationCenter.default.reinstall(observer: self, name: .AppWillTerminate, selector: #selector(self.cancelImageTask))
        NotificationCenter.default.reinstall(observer: self, name: .MemoryDidWarning, selector: #selector(self.cancelImageTask))
        _ = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            DispatchQueue.main.async {
                self.i += 1
                self.vMemory.text = "内存占用: \(calcMemory())MB\n内存可用: \(os_proc_available_memory() / 1000 / 1000)\n时间: \(self.i)"
                let (total, available) = self.getSystemMemoryInfo()
                if available < 20 {
                    switch self.generation.state {
                    case .startup:
                        break
                    default:
                        self.cancelImageTask()
                    }
                }
                self.vMemory.text = "时间=\(self.i)\n总共=\(Int(total))\n可用=\(Int(available))\nAPP占用=\(Int(calcMemory()))\nAPP可用=\(Int(os_proc_available_memory() / 1024 / 1024))"
                print("service=diffusion 时间=\(self.i) 总共=\(Int(total)) 可用=\(Int(available)) APP占用=\(Int(calcMemory())) APP可用=\(Int(os_proc_available_memory() / 1024 / 1024))")
            }
        }
        loadModel()
    }
    
    func loadModel() {
        Task.init {
            let loader = PipelineLoader(model: model)
            stateSubscriber = loader.statePublisher.sink { state in
                DispatchQueue.main.async {
                    switch state {
                    case .downloading(let progress):
                        self.vStatus.text = "Downloading (\(progress)"
                    case .uncompressing:
                        self.vStatus.text = "Uncompressing"
                    case .readyOnDisk:
                        self.vStatus.text = "Loading"
                    default:
                        break
                    }
                }
            }
            do {
                generation.delegate = self
                generation.pipeline = try await loader.prepare()
                self.vStatus.text = "Start"
            }  catch {
                print("Could not load model, error: \(error)")
            }
        }
    }
    
    @IBAction func tapGenerate() {
        if case .running = generation.state { return }
        self.i = 0
        vPrompt.resignFirstResponder()
        imageTask = Task {
            self.vStatus.text = "Generating"
            generation.state = .running(nil)
            do {
                self.vImage.image = nil
                generation.positivePrompt = vPrompt.text ?? "Dog"
                let result = try await generation.generate()
                generation.state = .complete(generation.positivePrompt, result.image, result.lastSeed, result.interval)
                self.vStatus.text = "Done"
            } catch {
                generation.state = .failed(error)
                self.vStatus.text = "Error: \(error)"
            }
        }
    }
    
    @objc @IBAction func cancelImageTask() {
        print("service=diffusion action=cancel")
        //if calcMemory() > 1500 || Int(calcMemory() * 1024 * 1024) > os_proc_available_memory() {
        let (_, free) = getSystemMemoryInfo()
        //if free < 60 {
        self.vStatus.text = "Cancelled"
        (generation.pipeline?.pipeline as? StableDiffusionPipeline)?.unloadResources()
        //try? (generation.pipeline?.pipeline as? StableDiffusionPipeline)?.loadResources()
        //print("------")
        //self.loadModel()
        //try? (generation.pipeline?.pipeline as? StableDiffusionPipeline)?.loadResources()
            /*generation.cancelGeneration()
            imageTask?.cancel()
            generation.state = .userCanceled*/
        //}
    }
    
    func getSystemMemoryInfo() -> (totalMemoryMB: Double, freeMemoryMB: Double) {
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

extension ViewController: GenerationContextDelegate {
    func generationDidUdpateProgress(progress: StableDiffusionProgress) {
        self.vStatus.text = "Image: \(progress.step) / \(progress.stepCount)"
        if let cgImage = generation.previewImage {
            self.vImage.image = UIImage(cgImage: cgImage)
        }
    }
}
