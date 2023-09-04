//
//  ViewController.swift
//  MobileDiffusion
//
//  Created by apple on 9/4/23.
//

import UIKit

class ViewController: UIViewController {
    @IBOutlet weak var vStatus: UILabel!
    
    let model = ModelInfo.v14Base
    var generation = GenerationContext()

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        let loader = PipelineLoader(model: model)
        stateSubscriber = loader.statePublisher.sink { state in
            DispatchQueue.main.async {
                switch state {
                case .downloading(let progress):
                    vStatus.text = "Downloading"
                    print("Download Progress: \(progress)")
                case .uncompressing:
                    vStatus.text = "Uncompressing"
                case .readyOnDisk:
                    vStatus.text = "Loading"
                default:
                    break
                }
            }
        }
        do {
            generation.pipeline = try await loader.prepare()
            self.currentView = .textToImage
        } catch {
            print("Could not load model, error: \(error)")
        }
    }

    @IBAction func tapGenerate() {
        
    }

}

