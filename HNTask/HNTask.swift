//
// HNTask.swift
//
// Copyright (c) 2014 Hironori Ichimiya <hiron@hironytic.com>
//
// Permission is hereby granted, free of charge, to any person obtaining
// a copy of this software and associated documentation files (the
// "Software"), to deal in the Software without restriction, including
// without limitation the rights to use, copy, modify, merge, publish,
// distribute, sublicense, and/or sell copies of the Software, and to
// permit persons to whom the Software is furnished to do so, subject to
// the following conditions:
// The above copyright notice and this permission notice shall be included
// in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
// IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
// CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
// TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
// SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

import Foundation

protocol HNTaskContext {
    var result: Any? { get }
    var error: HNTaskError? { get }
    
    func isError() -> Bool
}

protocol HNTaskError {
}

class HNTask : HNTaskContext {

    typealias TaskCallback = (HNTaskContext) -> Any?
    typealias FulfilledCallback = (Any?) -> Any?
    typealias RejectedCallback = (HNTaskError) -> Any?
    
    let _lock = NSObject()
    var _completed: Bool = false
    let _completeCondition: NSCondition = NSCondition()
    var _result: Any? = nil
    var _error: HNTaskError? = nil
    var _continuations: (() -> Void)[] = []

    /// creates an uncompleted task
    init() {
        
    }

    /// creates an resolved task
    class func resolvedTask(result: Any?) -> HNTask {
        let task = HNTask()
        task.resolve(result)
        return task
    }

    /// creates an rejected task
    class func rejectedTask(error: HNTaskError) -> HNTask {
        let task = HNTask()
        task.reject(error)
        return task
    }
    
    // @private
    func doInLock<TResult>(callback: () -> TResult) -> TResult {
        objc_sync_enter(_lock)
        let result = callback()
        objc_sync_exit(_lock)
        return result
    }
    
    var result: Any? {
        get {
            return doInLock { () -> Any? in
                return self._result
            }
        }
    }
    
    var error: HNTaskError? {
        get {
            return doInLock { () -> HNTaskError? in
                return self._error
            }
        }
    }
    
    func isError() -> Bool {
        return doInLock { () -> Bool in
            return self._error ? true : false
        }
    }

    func isCompleted() -> Bool {
        return doInLock({ () -> Bool in
            return self._completed
        })
    }

    func resolve(result: Any?) {
        complete(result: result, error: nil)
    }
    
    func reject(error: HNTaskError) {
        complete(result: nil, error: error)
    }
    
    // @private
    func complete(#result: Any?, error: HNTaskError?) {
        // doInLock is not used here for reduction of the call stack size.
        objc_sync_enter(_lock)
        if !self._completed {
            self._completed = true
            self._result = result
            self._error = error
        }
        
        // wake up all waiting thread by waitUntilCompleted()
        self._completeCondition.lock()
        self._completeCondition.broadcast()
        self._completeCondition.unlock()

        // execute all coninuations
        for callback in self._continuations {
            callback()
        }
        self._continuations.removeAll(keepCapacity: false)
        objc_sync_exit(_lock)
    }
    
    func continueWith(executor: HNTaskExecutor, callback: TaskCallback) -> HNTask {
        let task = HNTask()
        
        let executeCallback: () -> Void = {
            executor.execute {
                let result = callback(self)
                if let resultTask = result as? HNTask {
                    resultTask.continueWith { context in
                        task.complete(result: context.result, error: context.error)
                        return nil
                    }
                } else {
                    task.complete(result: result, error: self.error)
                }
            }
        }

        var wasCompleted = false
        doInLock { () -> Void in
            wasCompleted = self.isCompleted()
            if !wasCompleted {
                self._continuations.append(executeCallback)
            }
        }
        if wasCompleted {
            executeCallback()
        }
        
        return task
    }
    
    func continueWith(callback: TaskCallback) -> HNTask {
        return continueWith(HNDefaultTaskExecutor.sharedExecutor, callback: callback)
    }
    
    func then(executor: HNTaskExecutor, onFulfilled: FulfilledCallback) -> HNTask {
        return continueWith(executor) { context in
            if context.isError() {
                return context.result
            } else {
                return onFulfilled(context.result)
            }
        }
    }
    
    func then(onFulfilled: FulfilledCallback) -> HNTask {
        return then(HNDefaultTaskExecutor.sharedExecutor, onFulfilled: onFulfilled)
    }
    
    func then(executor: HNTaskExecutor, onFulfilled: FulfilledCallback, onRejected: RejectedCallback) -> HNTask {
        return continueWith(executor) { context in
            if let error = context.error {
                return HNTask.resolvedTask(nil).continueWith { context in
                    return onRejected(error)
                }
            } else {
                return onFulfilled(context.result)
            }
        }
    }

    func then(#onFulfilled: FulfilledCallback, onRejected: RejectedCallback) -> HNTask {
        return then(HNDefaultTaskExecutor.sharedExecutor, onFulfilled: onFulfilled, onRejected: onRejected)
    }
    
    func catch(executor: HNTaskExecutor, onRejected: (HNTaskError) -> Any?) -> HNTask {
        return continueWith(executor) { context in
            if let error = context.error {
                return HNTask.resolvedTask(nil).continueWith { context in
                    return onRejected(error)
                }
            } else {
                return context.result
            }
        }
    }

    func catch(onRejected: (HNTaskError) -> Any?) -> HNTask {
        return catch(HNDefaultTaskExecutor.sharedExecutor, onRejected: onRejected)
    }
    
    func waitUntilCompleted() {
        let doWait = doInLock { () -> Bool in
            if (self.isCompleted()) {
                return false
            }
            self._completeCondition.lock()
            return true
        }
        if doWait {
            self._completeCondition.wait()
            self._completeCondition.unlock()
        }
    }
}
