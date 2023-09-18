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

class ViewController: UIViewController {
    @IBOutlet weak var vStatus: UILabel!
    @IBOutlet weak var vPrompt: UITextField!
    @IBOutlet weak var vMemory: UILabel!
    @IBOutlet weak var vAction: UIButton!
    @IBOutlet weak var vTable: UITableView!
    @IBOutlet weak var vModelName: UILabel!
    @IBOutlet weak var vStep: UILabel!
    @IBOutlet weak var vImageCount: UILabel!
    @IBOutlet weak var vPreviewCount: UILabel!
    @IBOutlet weak var vImageCountStepper: UIStepper!
    @IBOutlet weak var vPreviewCountStepper: UIStepper!
    @IBOutlet weak var vStepStepper: UIStepper!
    @IBOutlet weak var vScheduler: UISegmentedControl!
    @IBOutlet weak var vBatchMode: UISegmentedControl!

    var config = DiffusionImageConfigure()
    var imageCount: Int = 1
    var previewCount: Int = 0
    var steps: Int = 10
    var scheduler: StableDiffusionScheduler = .dpmSolverMultistepScheduler
    var batchMode: DiffusionImageBatchMode = .loop

    var manager: DiffusionManager!
    var results: [GenerationResult] = []
    var currentModel: ModelInfo!
    var model1 = ModelInfo(
        name: "stable-diffusion-2.1",
        url: "http://192.168.0.29:8000/coreml-stable-diffusion-2-1-base_split_einsum_compiled.zip",
        isXL: false)
    var model2 = ModelInfo(
        name: "disney-pixal-cartoon",
        url: "http://192.168.0.29:8000/disney-pixal-cartoon.zip",
        isXL: false)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        NotificationCenter.default.reinstall(observer: self, name: .AppWillTerminate, selector: #selector(self.willTerminate))
        self.manager = DiffusionManager(delegate: self)
        currentModel = model1
        vModelName.text = currentModel.name
        self.manager.setup(model: currentModel)
        self.vAction.isEnabled = false
        
        vImageCount.text = "图片个数: \(imageCount)"
        vImageCountStepper.value = Double(imageCount)
        vPreviewCount.text = "预览个数: \(previewCount)"
        vPreviewCountStepper.value = Double(previewCount)
        vStep.text = "生成步数: \(steps)"
        vStepStepper.value = Double(steps)
        vTable.registerNibCell(ofType: ImageCell.self)
        vTable.reloadData()
    }
    
    @IBAction func switchModel() {
        if currentModel.name == model1.name {
            currentModel = model2
        } else {
            currentModel = model1
        }
        vModelName.text = currentModel.name
        self.manager.loadModel(currentModel)
    }

    @IBAction func tapGenerate() {
        vPrompt.resignFirstResponder()
        if manager.isCreating {
            self.vAction.setTitle("生成", for: .normal)
            manager.cancelCreateImageFromText()
        } else {
            let err = manager.createImageFromText(configure: currentConfig)
            if err != nil {
                print(err!.message ?? "Unknown error")
            } else {
                self.vAction.setTitle("取消", for: .normal)
            }
        }
    }
    
    @objc func willTerminate() {
        self.manager.willTerminate()
    }
    
    @IBAction func changeImageCount() {
        imageCount = Int(vImageCountStepper.value)
        vImageCount.text = "图片个数: \(imageCount)"
    }
    
    @IBAction func changePreviewCount() {
        previewCount = Int(vPreviewCountStepper.value)
        vPreviewCount.text = "预览个数: \(previewCount)"
    }
    
    @IBAction func changeStepCount() {
        steps = Int(vStepStepper.value)
        vStep.text = "生成步数: \(steps)"
    }
    
    @IBAction func changeScheduler() {
        if vScheduler.selectedSegmentIndex == 0 {
            scheduler = .dpmSolverMultistepScheduler
        } else {
            scheduler = .pndmScheduler
        }
    }
    
    @IBAction func changeBatchMode() {
        if vBatchMode.selectedSegmentIndex == 0 {
            batchMode = .loop
        } else {
            batchMode = .batch
        }
    }
    
    var currentConfig: DiffusionImageConfigure {
        config.steps = steps
        config.numOfImages = imageCount
        config.positivePrompt = vPrompt.text ?? "Dog"
        config.negativePrompt = ""
        config.previewsCount = previewCount
        config.schedulerType = scheduler
        config.batchMode = batchMode
        return config
    }
}

extension ViewController: UITableViewDataSource, UITableViewDelegate{
    func numberOfSections(in tableView: UITableView) ->Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int{
        return results.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = vTable.dequeueRegisteredCell(oftype: ImageCell.self, at: indexPath)
        cell.selectionStyle = .none
        if let cgImage = results[indexPath.row].image {
            cell.setData(image:  UIImage(cgImage: cgImage))
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UIScreen.main.bounds.width - 20
    }
}

extension ViewController: DiffusionManagerDelegate {
    func diffusionDidModelDoweloading(progress: Double) {
        self.vStatus.text = "下载模型中: (\(String(format: "%.2f", progress)))"
    }
    
    func diffusionDidModelUnCompressing() {
        self.vStatus.text = "解压模型中..."
    }
    
    func diffusionDidModelLoading() {
        self.vStatus.text = "加载模型中..."
    }
    
    func diffusionDidModelLoaded() {
        self.vAction.isEnabled = true
        self.vStatus.text = "模型加载: 完成"
    }
    
    func diffusionDidModelFailure(error: DiffusionError) {
        self.vStatus.text = "模型加载: 失败(\(error.localizedDescription))"
    }
    
    func diffusionDidImagePreviewCreated(step: Int, images: [CGImage?]) {
        self.vStatus.text = "图片生成中: \(step) / \(config.steps)"
        if images.count > 0 {
            var results: [GenerationResult] = []
            images.forEach { image in
                results.append(GenerationResult(image: image, lastSeed: 0, userCanceled: false))
            }
            self.results = results
            self.vTable.reloadData()
        }
    }
    
    func diffusionDidImageGenerated(results: [GenerationResult]) {
        DispatchQueue.main.async {
            self.vStatus.text = "图片生成: 成功"
            self.results = results
            self.vTable.reloadData()
            self.vAction.setTitle("生成", for: .normal)
        }
    }
    
    func diffusionDidImageGenerateFailure(error: DiffusionError) {
        self.vStatus.text = "图片生成: 失败(\(error.localizedDescription))"
    }
    
    func diffusionDiDInfoUpdate(time: Int, total: Int, available: Int, used: Int) {
        self.vMemory.text = "时间=\(time)\n总共=\(total)\n可用=\(available)\nAPP占用=\(used)\n"
    }
}
