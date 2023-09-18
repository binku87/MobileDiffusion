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

class ViewController: UIViewController {
    @IBOutlet weak var vStatus: UILabel!
    @IBOutlet weak var vImage: UIImageView!
    @IBOutlet weak var vPrompt: UITextField!
    @IBOutlet weak var vMemory: UILabel!
    @IBOutlet weak var vAction: UIButton!
    @IBOutlet weak var vTable: UITableView!
    var config = DiffusionImageConfigure()

    var manager: DiffusionManager!
    var results: [GenerationResult] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.manager = DiffusionManager(delegate: self)
        self.manager.setup()
        self.vAction.isEnabled = false
        
        config.steps = 10
        config.numOfImages = 2
        config.positivePrompt = "Dog"
        config.negativePrompt = ""
        config.previewsCount = 3
        
        vTable.registerNibCell(ofType: ImageCell.self)
        vTable.reloadData()
    }

    @IBAction func tapGenerate() {
        vPrompt.resignFirstResponder()
        if manager.isCreating {
            self.vAction.setTitle("生成", for: .normal)
            manager.cancelCreateImageFromText()
        } else {
            let err = manager.createImageFromText(configure: config)
            if err != nil {
                print(err!.message ?? "Unknown error")
            } else {
                self.vAction.setTitle("取消", for: .normal)
            }
        }
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
        self.vStatus.text = "下载模型中: (\(progress)"
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
    
    func diffusionDidImagePreviewCreated(step: Int, images: [UIImage?]) {
        self.vStatus.text = "图片生成中: \(step) / \(config.steps)"
        if images.count > 0 {
            var results: [GenerationResult] = []
            images.forEach { image in
                results.append(GenerationResult(image: image?.cgImage, lastSeed: 0, userCanceled: false))
            }
            self.results = results
            self.vTable.reloadData()
        }
    }
    
    func diffusionDidImageGenerated(results: [GenerationResult]) {
        self.vStatus.text = "图片生成: 成功"
        self.results = results
        self.vTable.reloadData()
    }
    
    func diffusionDidImageGenerateFailure(error: DiffusionError) {
        self.vStatus.text = "图片生成: 失败(\(error.localizedDescription))"
    }
    
    func diffusionDiDInfoUpdate(time: Int, total: Int, available: Int, used: Int) {
        self.vMemory.text = "时间=\(time)\n总共=\(total)\n可用=\(available)\nAPP占用=\(used)\n"
    }
}
