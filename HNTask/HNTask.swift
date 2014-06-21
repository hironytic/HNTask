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
    var error: Any? { get }
    
    func isError() -> Bool
}

class HNTask : HNTaskContext {

    struct ErrorContainer {
        let value: Any?
        init(value: Any?) {
            self.value = value
        }
    }
    
    let _lock = NSObject()
    var _completed: Bool = false
    var _result: Any? = nil
    var _errorContainer: ErrorContainer? = nil
    var _continuations: (() -> Void)[] = []

    /// create an uncompleted task
    init() {
        
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
    
    var errorContainer: ErrorContainer? {
        get {
            return doInLock { () -> ErrorContainer? in
                return self._errorContainer
            }
        }
    }
    
    var error: Any? {
        get {
            return doInLock { () -> Any? in
                if let errorContainer = self._errorContainer {
                    return errorContainer.value
                } else {
                    return nil
                }
            }
        }
    }
    
    func isError() -> Bool {
        return doInLock { () -> Bool in
            return self._errorContainer ? true : false
        }
    }

    func isCompleted() -> Bool {
        return doInLock({ () -> Bool in
            return self._completed
        })
    }

    func resolve(result: Any?) {
        complete(result: result, errorContainer: nil)
    }
    
    func reject(error: Any?) {
        complete(result: nil, errorContainer: ErrorContainer(value: error))
    }
    
    // @private
    func complete(#result: Any?, errorContainer: ErrorContainer?) {
        doInLock { () -> Void in
            if !self._completed {
                self._completed = true
                self._result = result
                self._errorContainer = errorContainer
            }
            
            // TODO: notify
            
            for callback in self._continuations {
                callback()
            }
            self._continuations.removeAll(keepCapacity: false)
        }
    }
    
    // @private
    func execute(callback: () -> Void) {
        // FIXME:
        callback()
    }
    
    func continueWith(callback: (context: HNTaskContext) -> Any?) -> HNTask {
        let task = HNTask()
        
        let executeCallback = {
            self.execute {
                let result = callback(context: self)
                if let resultTask = result as? HNTask {
                    resultTask.continueWith { context in
                        // TODO: cancel?
                        let prevTask = context as HNTask
                        task.complete(result: prevTask.result, errorContainer: prevTask.errorContainer)
                        return nil
                    }
                } else {
                    task.complete(result: result, errorContainer: self.errorContainer)
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
    
}

// suppose it is used in this way

//func foo() {
//    let task = HNTask()
//    task.resolve(nil)
//    task.continueWith { context in
//        return 10
//    }.continueWith { context in
//        if let num = context.result as? Int {
//            return "moji - \(num)"
//        } else {
//            let errorTask = HNTask()
//            errorTask.reject(NSError(domain: "FooDomain", code: 1, userInfo: nil))
//            return errorTask
//        }
//    }.continueWith { context in
//        if context.isError() {
//            println("\(context.error)")
//            return nil
//        }
//        
//        let result: String? = context.result as? String
//        println(result)
//        return nil
//    }
//}
