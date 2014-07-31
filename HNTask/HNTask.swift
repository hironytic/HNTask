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

public class HNTask {
    private let _lock = NSObject()
    private var _completed: Bool = false
    private let _completeCondition: NSCondition = NSCondition()
    private var _result: Any? = nil
    private var _error: Any? = nil
    private var _continuations: [(() -> Void)] = []

    public struct DefaultTaskExecutor {
        static public var sharedExecutor: HNExecutor = HNAsyncExecutor.sharedExecutor
    }
    
    private init() {
    }
    
    /// creates an uncompleted task
    public convenience init(callback: ((Any?) -> Void, (Any) -> Void) -> Void) {
        self.init()
        let resolver = { (result: Any?) -> Void in
            self.complete(result: result, error: nil)
        }
        let rejector = { (error: Any) -> Void in
            self.complete(result: nil, error: error)
        }
        callback(resolver, rejector)
    }

    /// creates an resolved task
    class public func resolve(result: Any?) -> HNTask {
        let task = HNTask()
        task.complete(result: result, error: nil)
        return task
    }

    /// creates an rejected task
    class public func reject(error: Any) -> HNTask {
        let task = HNTask()
        task.complete(result: nil, error: error)
        return task
    }
    
    class public func all(tasks: [HNTask]) -> HNTask {
        let task = HNTask()
        let lock = NSObject()
        var count = tasks.count
        var results = [Any?](count: count, repeatedValue: nil)

        for (index, value) in enumerate(tasks) {
            value.continueWith { context in
                if context.isError() {
                    var doReject = false
                    objc_sync_enter(lock)
                    if count > 0 {
                        count = 0
                        doReject = true
                    }
                    objc_sync_exit(lock)
                    if doReject {
                        task.complete(result: nil, error: context.error!)
                    }
                } else {
                    var doResolve = false
                    objc_sync_enter(lock)
                    results[index] = context.result
                    if count > 0 {
                        count--
                        if count == 0 {
                            doResolve = true
                        }
                    }
                    objc_sync_exit(lock)
                    
                    if doResolve {
                        let resultValue: Any = results
                        task.complete(result: resultValue, error: nil)
                    }
                }
                return (nil, nil)
            }
        }
        
        return task
    }
    
    class public func race(tasks: [HNTask]) -> HNTask {
        let task = HNTask()
        let lock = NSObject()
        var completed = false
        
        for (index, value) in enumerate(tasks) {
            value.continueWith { context in
                var doComplete = false
                objc_sync_enter(lock)
                if !completed {
                    completed = true
                    doComplete = true
                }
                objc_sync_exit(lock)
                
                if doComplete {
                    if context.isError() {
                        task.complete(result: nil, error: context.error!)
                    } else {
                        task.complete(result: context.result, error: nil)
                    }
                }
                return (nil, nil)
            }
        }
        
        return task
    }
    
    class public func allSettled(tasks: [HNTask]) -> HNTask {
        let task = HNTask()
        let lock = NSObject()
        var count = tasks.count
        var results = [Any?](count: count, repeatedValue: nil)
        
        for (index, value) in enumerate(tasks) {
            value.continueWith { context in
                var doResolve = false
                objc_sync_enter(lock)
                if context.isError() {
                    results[index] = context.error
                } else {
                    results[index] = context.result
                }
                if count > 0 {
                    count--
                    if count == 0 {
                        doResolve = true
                    }
                }
                objc_sync_exit(lock)
                
                if doResolve {
                    let resultValue: Any = results
                    task.complete(result: resultValue, error: nil)
                }
                return (nil, nil)
            }
        }
        
        return task
    }

    
    private func doInLock<TResult>(callback: () -> TResult) -> TResult {
        objc_sync_enter(_lock)
        let result = callback()
        objc_sync_exit(_lock)
        return result
    }
    
    public var result: Any? {
        get {
            return doInLock { () -> Any? in
                return self._result
            }
        }
    }
    
    public var error: Any? {
        get {
            return doInLock { () -> Any? in
                return self._error
            }
        }
    }
    
    public func isError() -> Bool {
        return doInLock { () -> Bool in
            return self._error ? true : false
        }
    }

    public func isCompleted() -> Bool {
        return doInLock({ () -> Bool in
            return self._completed
        })
    }

    private func complete(#result: Any?, error: Any?) {
        // doInLock is not used here for reduction of the call stack size.
        objc_sync_enter(_lock)
        if !self._completed {
            self._completed = true
            self._result = result
            self._error = error
        }
        
        // wake up all threads waiting in waitUntilCompleted()
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
    
    public func continueWith(executor: HNExecutor, callback: (HNTask) -> (result: Any?, error: Any?)) -> HNTask {
        let task = HNTask()
        
        let executeCallback: () -> Void = {
            executor.execute {
                let result = callback(self)
                if let resultError = result.error {
                    task.complete(result: nil, error: resultError)
                } else if let resultTask = result.result as? HNTask {
                    resultTask.continueWith { context in
                        task.complete(result: context.result, error: context.error)
                        return (nil, nil)
                    }
                } else {
                    task.complete(result: result.result, error: nil)
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
    
    public func continueWith(callback: (HNTask) -> (result: Any?, error: Any?)) -> HNTask {
        return continueWith(DefaultTaskExecutor.sharedExecutor, callback: callback)
    }
    
    public func then(executor: HNExecutor, onFulfilled: (Any?) -> Any?) -> HNTask {
        return continueWith(executor) { context in
            if context.isError() {
                return (nil, context.error)
            } else {
                return (onFulfilled(context.result), nil)
            }
        }
    }
    
    public func then(onFulfilled: (Any?) -> Any?) -> HNTask {
        return then(DefaultTaskExecutor.sharedExecutor, onFulfilled: onFulfilled)
    }
    
    public func then<T>(executor: HNExecutor, onFulfilledInType: (T) -> Any?) -> HNTask {
        return continueWith(executor) { context in
            if context.isError() {
                return (nil, context.error)
            } else if let result = context.result as? T {
                return (onFulfilledInType(result), nil)
            } else {
                return (nil, HNTaskTypeError(value: context.result))
            }
        }
    }

    public func then<T>(onFulfilledInType: (T) -> Any?) -> HNTask {
        return then(DefaultTaskExecutor.sharedExecutor, onFulfilledInType: onFulfilledInType)
    }
    
    public func then(executor: HNExecutor, onFulfilled: (Any?) -> Any?, onRejected: (Any) -> Any?) -> HNTask {
        return continueWith(executor) { context in
            if let error = context.error {
                return (onRejected(error), nil)
            } else {
                return (onFulfilled(context.result), nil)
            }
        }
    }

    public func then(#onFulfilled: (Any?) -> Any?, onRejected: (Any) -> Any?) -> HNTask {
        return then(DefaultTaskExecutor.sharedExecutor, onFulfilled: onFulfilled, onRejected: onRejected)
    }

    public func then<T>(executor: HNExecutor, onFulfilledInType: (T) -> Any?, onRejected: (Any) -> Any?) -> HNTask {
        return continueWith(executor) { context in
            if let error = context.error {
                return (onRejected(error), nil)
            } else if let result = context.result as? T {
                return (onFulfilledInType(result), nil)
            } else {
                return (nil, HNTaskTypeError(value: context.result))
            }
        }
    }

    public func then<T>(onFulfilledInType: (T) -> Any?, onRejected: (Any) -> Any?) -> HNTask {
        return then(DefaultTaskExecutor.sharedExecutor, onFulfilledInType: onFulfilledInType, onRejected: onRejected)
    }
    
    public func catch(executor: HNExecutor, onRejected: (Any) -> Any?) -> HNTask {
        return continueWith(executor) { context in
            if let error = context.error {
                return (onRejected(error), nil)
            } else {
                return (context.result, nil)
            }
        }
    }

    public func catch(onRejected: (Any) -> Any?) -> HNTask {
        return catch(DefaultTaskExecutor.sharedExecutor, onRejected: onRejected)
    }
    
    public func finally(executor: HNExecutor, onFinal: () -> HNTask?) -> HNTask {
        return continueWith(executor) { context in
            let result = context.result
            let error = context.error
            
            if let finalResultTask = onFinal() {
                let task = HNTask()
                finalResultTask.continueWith { context in
                    task.complete(result: result, error: error)
                    return (nil, nil)
                }
                return (task, nil)
            } else {
                return (result, error)
            }
        }
    }
    
    public func finally(onFinal: () -> HNTask?) -> HNTask {
        return finally(DefaultTaskExecutor.sharedExecutor, onFinal: onFinal)
    }
    
    public func waitUntilCompleted() {
        let doWait = doInLock { () -> Bool in
            if self.isCompleted() {
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
