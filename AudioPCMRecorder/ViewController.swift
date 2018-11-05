//
//  ViewController.swift
//  AudioPCMRecorder
//
//  Created by lunli on 2018/11/5.
//  Copyright © 2018年 lunli. All rights reserved.
//

import UIKit
import CoreMedia

class ViewController: UIViewController {
    
    let recorder = PCMRecorder.init()
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    @IBAction func start(_ sender: Any) {
        print("click start")
        recorder.callback = {(buffer:CMSampleBuffer) in
            
        }
        recorder.start()
    }
    
    @IBAction func stop(_ sender: Any) {
        print("click stop")
    }
}

