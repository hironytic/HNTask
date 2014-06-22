//
// HNTaskTests.swift
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

import XCTest

class HNTaskTests: XCTestCase {
    
    struct MyError: HNTaskError {
        let message: String
    }
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testContinuationShouldRun() {
        var continued = false
        let task = HNTask()
        task.resolve(nil)
        task.continueWith { context in
            continued = true
        }.waitUntilCompleted()
        XCTAssertTrue(continued, "continuation closure should run.")
    }

    func testContinuationShouldRunWhenRejected() {
        var continued = false
        let task = HNTask()
        task.reject(MyError(message: "error"))
        task.continueWith { context in
            continued = true
        }.waitUntilCompleted()
        XCTAssertTrue(continued, "continuation closure should run.")
    }
    
    func testResultShouldBePassed() {
        let task = HNTask()
        task.resolve(10)
        task.continueWith { context in
            if let value = context.result as? Int {
                XCTAssertEqual(value, 10, "previous result should be passed.")
            } else {
                XCTFail("previous result shoule be Int.")
            }
            return nil
        }.waitUntilCompleted()
    }
    
    func testReturnValueShouldBeResult() {
        let task = HNTask()
        task.resolve(nil)
        task.continueWith { context in
            return "result"
        }.continueWith { context in
            if let value = context.result as? String {
                XCTAssertEqual(value, "result", "previous return value should be result.")
            } else {
                XCTFail("previous result shoule be String.")
            }
            return nil
        }.waitUntilCompleted()
    }
    
    func testRejectShouldCauseError() {
        let task = HNTask()
        task.reject(MyError(message: "error"))
        task.continueWith { context in
            XCTAssertTrue(context.isError(), "error should be occured.")
            return nil
        }.waitUntilCompleted()
    }
    
    func testErrorValueShouldBePassed() {
        let task = HNTask()
        task.reject(MyError(message: "error"))
        task.continueWith { context in
            if let error = context.error {
                if let myError = error as? MyError {
                    XCTAssertEqual(myError.message, "error", "error value shoule be passed.")
                } else {
                    XCTFail("error value shoule be type of MyError.")
                }
            } else {
                XCTFail("error value shoule be exist.")
            }
            return nil
        }.waitUntilCompleted()
    }
    
    func testThreadShouldSwitchedByExecutor() {
        let myQueue = dispatch_queue_create("com.hironytic.hntasktests", nil)
        class MyExecutor: HNTaskExecutor {
            let queue: dispatch_queue_t
            init(queue: dispatch_queue_t) {
                self.queue = queue
            }
            func execute(callback: () -> Void) {
                dispatch_async(queue) {
                    callback()
                }
            }
        }
        
        let testThread = NSThread.currentThread()
        
        let task = HNTask()
        task.resolve(nil)
        let lastTask = task.switchExecutor(MyExecutor(queue: myQueue)).continueWith { context in
            XCTAssertNotEqualObjects(testThread, NSThread.currentThread(), "thread shoule be switched")
        }
    
        lastTask.waitUntilCompleted()
    }
    
}
