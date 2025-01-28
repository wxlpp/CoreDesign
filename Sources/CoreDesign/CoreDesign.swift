//
//  CoreDesign.swift
//  CoreDesign
//
//  Created by Evan wang on 2025年1月28日.
//  Copyright © 2025 Evan. All rights reserved.
//

import Foundation
import UIKit

@IBDesignable
public class CoreDesign: UIView {
    let name = "CoreDesign loaded"

    override public init(frame: CGRect) {
        super.init(frame: frame)
        self.setup()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.setup()
    }

    func setup() {
        backgroundColor = .lightGray
        self.translatesAutoresizingMaskIntoConstraints = false

        let image = UIImage(data: whiteKing)
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(imageView)

        self.addConstraint(NSLayoutConstraint(item: imageView, attribute: .width, relatedBy: .equal, toItem: self, attribute: .width, multiplier: 1, constant: 0))
        self.addConstraint(NSLayoutConstraint(item: imageView, attribute: .height, relatedBy: .equal, toItem: self, attribute: .height, multiplier: 1, constant: 0))
        self.addConstraint(NSLayoutConstraint(item: imageView, attribute: .top, relatedBy: .equal, toItem: self, attribute: .top, multiplier: 1, constant: 0))
        self.addConstraint(NSLayoutConstraint(item: imageView, attribute: .leading, relatedBy: .equal, toItem: self, attribute: .leading, multiplier: 1, constant: 0))

        let label = UILabel()
        label.text = self.name
        label.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(label)
        self.addConstraint(NSLayoutConstraint(item: label, attribute: .bottom, relatedBy: .equal, toItem: self, attribute: .bottom, multiplier: 1, constant: 0))
        self.addConstraint(NSLayoutConstraint(item: label, attribute: .width, relatedBy: .equal, toItem: self, attribute: .width, multiplier: 1, constant: 0))

        self.layoutIfNeeded()
    }
}
