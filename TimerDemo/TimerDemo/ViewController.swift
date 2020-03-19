//
//  ViewController.swift
//  TimerDemo
//
//  Created by jams on 2020/3/17.
//  Copyright © 2020 jams. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.test()
    }

    func test() {
        let manager = TaskManager<NetworkTask>(10, 1)
        for i in 0 ..< 5 {
            let task = NetworkTask("host-\(i)")
            DispatchQueue.main.asyncAfter(deadline: .now()+Double.random(in: 0...20.0)) {
                print("task:\(task.hostName) do task in \(Date.init())")
                manager.appendTask(task) { (result, timeout) -> (Void) in
                    print("task:\(task.hostName), result:\(result ?? "null"), timeout:\(timeout), time:\(Date.init())")
                }
            }
        }
        
    }

}

