//
//  ViewController.swift
//  StackViewHandler
//
//  Created by Annur Alif Ramadhoni  on 22/07/26.
//

import UIKit
import CatWalk
import SkeletonView
import SnapKit

class ViewController: UIViewController {
    
    private let detailStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 0
        stackView.alignment = .leading
        stackView.distribution = .fill
        stackView.isSkeletonable = true
        return stackView
    }()
    
    private let priceStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 0
        stackView.alignment = .leading
        stackView.distribution = .fill
        stackView.isSkeletonable = true
        return stackView
    }()
    
    private let descLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = .black
        label.numberOfLines = 0
        label.textAlignment = .left
        label.text = "10.000 | 30GB | "
        return label
    }()
    
    private let priceLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = .black
        label.numberOfLines = 0
        label.textAlignment = .left
        label.isSkeletonable = true
        label.skeletonCornerRadius = 12
        label.text = "10.000"
        return label
    }()
    
    private let originalPriceLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 10)
        label.textColor = .gray
        label.numberOfLines = 0
        label.textAlignment = .left
        label.text = ""
        label.isHidden = true
        return label
    }()
    
    private let seeDetail: UILabel = {
        let label = UILabel()
        label.text = "Lihat Detail"
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = .red
        label.textAlignment = .right
        return label
    }()
    
    private let showButton: UIButton = {
        let button = UIButton()
        button.setTitle("Show", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .black
        return button
    }()
    
    private let hideButton: UIButton = {
        let button = UIButton()
        button.setTitle("Hide", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .black
        return button
    }()
    
    private let backView: UIView = {
        let view = UIView()
        return view
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        let inspectorButton = UIButton(type: .system, primaryAction: UIAction(title: "Inspector") { _ in CatWalk.present() })
        view.addSubview(inspectorButton)
        inspectorButton.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.bottom.equalTo(view.safeAreaLayoutGuide).inset(24)
        }
        
        self.view.addSubview(self.detailStackView)
        self.view.addSubview(self.showButton)
        self.view.addSubview(self.hideButton)
        
        self.detailStackView.snp.makeConstraints {
            $0.top.equalTo(100)
            $0.horizontalEdges.equalToSuperview().inset(40)
        }
        
        self.showButton.snp.makeConstraints {
            $0.top.equalTo(self.detailStackView.snp.bottom).offset(16)
            $0.horizontalEdges.equalToSuperview().inset(40)
            $0.height.equalTo(40)
        }
        
        self.hideButton.snp.makeConstraints {
            $0.top.equalTo(self.showButton.snp.bottom).offset(16)
            $0.horizontalEdges.equalToSuperview().inset(40)
            $0.height.equalTo(40)
        }
        
        self.detailStackView.addArrangedSubview(self.backView)
        self.detailStackView.addArrangedSubview(self.seeDetail)
        
        self.backView.addSubview(self.descLabel)
        self.backView.addSubview(self.priceLabel)
        self.backView.addSubview(self.originalPriceLabel)
        
        self.descLabel.snp.makeConstraints {
            $0.top.equalTo(self.backView.snp.top)
            $0.leading.equalTo(self.backView.snp.leading)
            $0.bottom.equalTo(self.backView.snp.bottom)
            $0.width.greaterThanOrEqualTo(0)
        }
        
        self.priceLabel.snp.makeConstraints {
            $0.top.equalTo(self.backView.snp.top)
            $0.leading.equalTo(self.descLabel.snp.trailing)
            $0.bottom.equalTo(self.backView.snp.bottom)
            $0.width.greaterThanOrEqualTo(0)
        }
        
        self.originalPriceLabel.snp.makeConstraints {
            $0.top.equalTo(self.backView.snp.top)
            $0.leading.equalTo(self.priceLabel.snp.trailing).offset(4)
            $0.bottom.equalTo(self.backView.snp.bottom)
            $0.width.greaterThanOrEqualTo(0)
        }
        
        self.showButton.addTarget(self, action: #selector(self.showAction), for: .touchUpInside)
        self.hideButton.addTarget(self, action: #selector(self.hideAction), for: .touchUpInside)
    }

    @objc
    func showAction() {
        self.priceLabel.text = "9.000"
        self.originalPriceLabel.text = "10.000"
        self.originalPriceLabel.isHidden = false
    }
    
    @objc
    func hideAction() {
        self.priceLabel.text = "10.000"
        self.originalPriceLabel.text = "0"
        self.originalPriceLabel.isHidden = true
    }
}

