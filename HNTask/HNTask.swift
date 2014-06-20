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

class HNTask<TResult> {

    struct Privates {
        let lock = NSObject()
        var completed: Bool = false
        var result: TResult?
        var error: Any?
        var following: (() -> Void)[] = []
        
        init() {}
    }
    var privates = Privates()

    init() {
        
    }

    var result: TResult? {
        get {
            var value: TResult?
            locked {
                value = self.privates.result
            }
            return value
        }
    }
    
    var error: Any? {
        get {
            var value: Any?
            locked {
                value = self.privates.error
            }
            return value
        }
    }
    
    func isCompleted() -> Bool {
        var value: Bool = false
        locked {
            value = self.privates.completed
        }
        return value
    }
    
    func locked(callback: () -> Void) {
        objc_sync_enter(privates.lock)
        callback()
        objc_sync_exit(privates.lock)
    }
    
    func complete(#result: TResult?, error: Any?) {
        locked {
            if !self.privates.completed {
                self.privates.completed = true
                self.privates.result = result
                self.privates.error = error
            }
            
            // TODO: notify
            
            for callback in self.privates.following {
                callback()
            }
            self.privates.following.removeAll(keepCapacity: false)
        }
    }
    
    func execute(callback: () -> Void) {
        // FIXME:
        callback()
    }
    
    func continueWith<TCBResult>(callback: (context: HNTaskContext<TResult>) -> TCBResult?) -> HNTask<TCBResult> {
        let task = HNTask<TCBResult>()
        
        let executeCallback: () -> Void = {
            self.execute {
                let result = callback(context: HNTaskContext<TResult>(result: self.result))
                if let resultTask = result as? HNTask {
                    resultTask.continueWith { (context: HNTaskContext<TResult>) -> Void? in
                        // TODO: cancel?
                        task.complete(result: context.result as? TCBResult, error: context.error)
                        return nil
                    }
                } else {
                    task.complete(result: result as? TCBResult, error: nil)
                }
            }
        }

        var wasCompleted = false
        locked {
            wasCompleted = self.isCompleted()
            if !wasCompleted {
                self.privates.following.append(executeCallback)
            }
        }
        if wasCompleted {
            executeCallback()
        }
        
        return task
    }
    
}

class HNTaskContext<TResult> {
    let result: TResult?
    var error: Any?
    
    init(result: TResult?) {
        self.result = result
    }
}


