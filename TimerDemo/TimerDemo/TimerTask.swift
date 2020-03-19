//
//  TimerTask.swift
//  TimerDemo
//
//  Created by jams on 2020/3/17.
//  Copyright © 2020 jams. All rights reserved.
//

import Foundation

protocol Task  {
    associatedtype T
    func taskKey() -> String //任务对应的唯一key，用于区分任务
    func doTask() -> T // 实现任务
    var completion: ((_ result: T?, _ timeout: Bool) -> Void)? {get set} //返回的异步结果
}


class NetworkTask: Task {
    typealias T = String
    var completion: ((String?, Bool) -> Void)?
    
    var hostName: String
    
    init(_ name: String) {
        hostName = name
    }
    
    func taskKey() -> String {
        return hostName
    }
    
    func doTask() -> String {
        Thread.sleep(forTimeInterval: Double.random(in: 1...20)) //模拟耗时任务
        return "\(hostName)'s result"
    }
    
}

protocol TimeWheelDelegate : class {
    func timeoutItems(_ items: [Any]?, _ timeWheel: TimeWheel)
}

class TimeWheel {
    private var capacity: Int
    private var interval: TimeInterval
    private var timeWheel: [[Any]]
    var index: Int
    private var timer: Timer?
    weak var delegate: TimeWheelDelegate?
    
    init(_ capacity: Int, _ interval: TimeInterval) {
        self.capacity = capacity
        self.interval = interval
        self.index = 0
        timeWheel = []
        for _ in 0 ..< capacity { //先填充空数组，创建若干个“空槽”
            self.timeWheel.append([])
        }
    }
    
    func addObject(_ task: Any) {
        if timer == nil {
            timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(detectTimeoutItem(_:)), userInfo: nil, repeats: true)
            RunLoop.current.add(timer!, forMode: .common)
        }
        
        if index < timeWheel.count {
            var arr = timeWheel[index]
            arr.append(task)
            timeWheel[index] = arr
        }
    }
    
    func currentObjects() -> [Any]? {
        if index < timeWheel.count {
            return timeWheel[index]
        }
        return nil
    }
    
    func cleanup() {
        self.timeWheel.removeAll()
        if timer != nil {
            timer?.invalidate()
            timer = nil
        }
    }
    
    private func removeExpiredObjects() {
        if index < timeWheel.count {
            var arr = timeWheel[index]
            arr.removeAll()
        }
    }
    
    private func moveToNextTimeSlot() {
        index = (index + 1) % timeWheel.count
    }
    
    @objc
    private func detectTimeoutItem(_ timer: Timer) {
        moveToNextTimeSlot()
        delegate?.timeoutItems(self.currentObjects(), self)
        removeExpiredObjects()
    }
}


class TaskManager<T: Task> : TimeWheelDelegate {
    
    private var timeWheel: TimeWheel?
    private var timeInterval: TimeInterval
    private var timeoutSeconds: Int
    private var queue: DispatchQueue
    private var callbackDict: Dictionary<String, T>
    
    init(_ timeout: Int, _ timeInterval: TimeInterval) {
        timeoutSeconds = timeout
        self.timeInterval = timeInterval
        queue = DispatchQueue(label: "com.task.queue", qos: .default, attributes: .concurrent, autoreleaseFrequency: .workItem, target: nil)
        callbackDict = [:]
    }
    
    func appendTask(_ task: T, _ completion:@escaping (_ result: T.T?, _ timeout: Bool) -> (Void)) {
        
        if timeWheel == nil {
            timeWheel = TimeWheel(timeoutSeconds, timeInterval)
            timeWheel?.delegate = self
        }
        
        var task = task
        task.completion = completion
        self.callbackDict[task.taskKey()] = task
        self.timeWheel?.addObject(task) //将任务添加到对应的时间轮槽位中
        
        self.queue.async {
            let result = task.doTask()
            DispatchQueue.main.async { //保证数据的一致性
                let key = task.taskKey()
                if let item = self.callbackDict[key] {
                    item.completion?(result, false) //返回按时完成任务的结果
                    self.callbackDict.removeValue(forKey: key)
                }
            }
        }
    }
    
    func timeoutItems(_ items: [Any]?, _ timeWheel: TimeWheel) {
        if let callbacks = items {
            for callback in callbacks {
                if let item = callback as? T, let task = self.callbackDict[item.taskKey()] {
                    task.completion?(nil, true)
                    self.callbackDict.removeValue(forKey: task.taskKey())
                }
            }
        }
    }

}

