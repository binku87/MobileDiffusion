//
//  ModelInfo.swift
//  Diffusion
//
//  Created by Pedro Cuenca on 29/12/22.
//  See LICENSE at https://github.com/huggingface/swift-coreml-diffusers/LICENSE
//

import CoreML

let deviceHas6GBOrMore = ProcessInfo.processInfo.physicalMemory > 5924000000   // Different devices report different amounts, so approximate

struct ModelInfo {
    let name: String
    let url: String
    let isXL: Bool

    init(name: String, url: String, isXL: Bool) {
        self.name = name
        self.url = url
        self.isXL = isXL
    }
}
