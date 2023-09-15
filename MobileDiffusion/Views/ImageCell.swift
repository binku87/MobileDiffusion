//
//  ImageCell.swift
//  MobileDiffusion
//
//  Created by apple on 9/14/23.
//

import UIKit

class ImageCell: UITableViewCell, NibLoadable {
    @IBOutlet weak var vImage: UIImageView!
    
    func setData(image: UIImage) {
        self.vImage.image = image
    }
}
