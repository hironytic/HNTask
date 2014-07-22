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
        let expectation = expectationWithDescription("finish task");
        let task = HNTask.resolve(nil)
        task.continueWith { context in
            expectation.fulfill()
            return (nil, nil)
        }
        waitForExpectationsWithTimeout(5.0, handler: nil)
    }

    func testContinuationShouldRunWhenRejected() {
        let expectation = expectationWithDescription("finish task");
        let task = HNTask.reject(MyError(message: "error"))
        task.continueWith { context in
            expectation.fulfill()
            return (nil, nil)
        }
        waitForExpectationsWithTimeout(5.0, handler: nil)
    }
    
    func testResultShouldBePassed() {
        let expectation = expectationWithDescription("finish task");
        let task = HNTask.resolve(10)
        task.continueWith { context in
            if let value = context.result as? Int {
                XCTAssertEqual(value, 10, "previous result should be passed.")
            } else {
                XCTFail("previous result should be Int.")
            }
            expectation.fulfill()
            return (nil, nil)
        }
        waitForExpectationsWithTimeout(5.0, handler: nil)
    }
    
    func testReturnValueShouldBeResult() {
        let expectation = expectationWithDescription("finish task");
        let task = HNTask.resolve(nil)
        task.continueWith { context in
            return ("result", nil)
        }.continueWith { context in
            if let value = context.result as? String {
                XCTAssertEqual(value, "result", "previous return value should be result.")
            } else {
                XCTFail("previous result should be String.")
            }
            expectation.fulfill()
            return (nil, nil)
        }
        waitForExpectationsWithTimeout(5.0, handler: nil)
    }
    
    func testRejectShouldCauseError() {
        let expectation = expectationWithDescription("finish task");
        let task = HNTask.reject(MyError(message: "error"))
        task.continueWith { context in
            XCTAssertTrue(context.isError(), "error should be occured.")
            expectation.fulfill()
            return (nil, nil)
        }
        waitForExpectationsWithTimeout(5.0, handler: nil)
    }
    
    func testErrorValueShouldBePassed() {
        let expectation = expectationWithDescription("finish task");
        let task = HNTask.reject(MyError(message: "error"))
        task.continueWith { context in
            if let error = context.error {
                if let myError = error as? MyError {
                    XCTAssertEqual(myError.message, "error", "error value should be passed.")
                } else {
                    XCTFail("error value should be type of MyError.")
                }
            } else {
                XCTFail("error value should be exist.")
            }
            expectation.fulfill()
            return (nil, nil)
        }
        waitForExpectationsWithTimeout(5.0, handler: nil)
    }
    
    func testThreadShouldSwitchedByExecutor() {
        let myQueue = dispatch_queue_create("com.hironytic.hntasktests", nil)
        class MyExecutor: HNExecutor {
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
        
        let expectation = expectationWithDescription("finish task");
        let task = HNTask.resolve(nil)
        task.continueWith(MyExecutor(queue: myQueue)) { context in
            XCTAssertFalse(testThread.isEqual(NSThread.currentThread()), "thread should be switched")
            expectation.fulfill()
            return (nil, nil)
        }
        waitForExpectationsWithTimeout(5.0, handler: nil)
    }

    func testResolvedTask() {
        let expectation = expectationWithDescription("finish task");
        let task = HNTask.resolve(20)
        XCTAssertTrue(task.isCompleted(), "task should be completed.")
        task.continueWith { context in
            if let value = context.result as? Int {
                XCTAssertEqual(value, 20, "resolved value should be passed.")
            } else {
                XCTFail("resolved value should be Int.")
            }
            expectation.fulfill()
            return (nil, nil)
        }
        waitForExpectationsWithTimeout(5.0, handler: nil)
    }
    
    func testRejectedTask() {
        let expectation = expectationWithDescription("finish task");
        let task = HNTask.reject(MyError(message: "rejected"))
        XCTAssertTrue(task.isCompleted(), "task should be completed.")
        task.continueWith { context in
            XCTAssertTrue(context.isError(), "task should be in error state.")
            if let error = context.error {
                if let myError = error as? MyError {
                    XCTAssertEqual(myError.message, "rejected", "error message should be 'rejected'")
                } else {
                    XCTFail("error value should be MyError.")
                }
            } else {
                XCTFail("error value should be exist.")
            }
            expectation.fulfill()
            return (nil, nil)
        }
        waitForExpectationsWithTimeout(5.0, handler: nil)
    }
    
    
    func testThenShouldRunWhenSucceeded() {
        let expectation = expectationWithDescription("finish task");
        HNTask.resolve(30).then { value in
            if let intValue = value as? Int {
                XCTAssertEqual(intValue, 30, "previous value should be passed.")
            } else {
                XCTFail("previous value should be Int.")
            }
            expectation.fulfill()
            return nil
        }
        waitForExpectationsWithTimeout(5.0, handler: nil)
    }
    
    func testThenShouldNotRunWhenError() {
        let expectation = expectationWithDescription("finish task");
        var ran = false
        HNTask.reject(MyError(message: "myError")).then { value in
            ran = true
            return nil
        }.finally {
            expectation.fulfill()
            return nil
        }
        waitForExpectationsWithTimeout(5.0, handler: nil)
        XCTAssertFalse(ran, "then closure should not run.")
    }
    
    func testTypeCheckThenShouldRunWhenSucceeded() {
        let expectation = expectationWithDescription("finish task");
        HNTask.resolve(30).then { (value: Int) in
            XCTAssertEqual(value, 30, "previous value should be passed.")
            expectation.fulfill()
            return nil
        }
        waitForExpectationsWithTimeout(5.0, handler: nil)
    }
    
    func testTypeCheckThenShouldNotRunWhenError() {
        let expectation = expectationWithDescription("finish task");
        var ran = false
        HNTask.reject(MyError(message: "myError")).then { (value: Int) in
            ran = true
            return nil
        }.finally {
            expectation.fulfill()
            return nil
        }
        waitForExpectationsWithTimeout(5.0, handler: nil)
        XCTAssertFalse(ran, "then closure should not run.")
    }
    
    func testTypeCheckThenShouldNotRunWhenTypeMismatch() {
        let expectation = expectationWithDescription("finish task");
        var ran = false
        HNTask.resolve(40).then { (value: String) in
            ran = true
            return nil
        }.finally {
            expectation.fulfill()
            return nil
        }
        waitForExpectationsWithTimeout(5.0, handler: nil)
        XCTAssertFalse(ran, "then closure should not run.")
    }
    
    func testTypeCheckThenShouldMakeError() {
        let expectation = expectationWithDescription("finish task");
        HNTask.resolve(40).then { (value: String) in
            return nil
        }.catch { error in
            if let typeError = error as? HNTaskTypeError {
                if let errorValue = typeError.value as? Int {
                    XCTAssertEqual(errorValue, 40, "error value shoule be 40.")
                } else {
                    XCTFail("error value shoule be Int")
                }
            } else {
                XCTFail("error shoule be kind of HNTaskTypeError")
            }
            expectation.fulfill()
            return nil
        }
        waitForExpectationsWithTimeout(5.0, handler: nil)
    }
    
    func testCatchShouldNotRunWhenSucceeded() {
        let expectation = expectationWithDescription("finish task");
        var ran = false
        HNTask.resolve(30).catch { error in
            ran = true
            return nil
        }.finally {
            expectation.fulfill()
            return nil
        }
        waitForExpectationsWithTimeout(5.0, handler: nil)
        XCTAssertFalse(ran, "catch closure should not run.")
    }

    func testCatchShouldRunWhenError() {
        let expectation = expectationWithDescription("finish task");
        HNTask.reject(MyError(message: "myError")).catch { error in
            if let myError = error as? MyError {
                XCTAssertEqual(myError.message, "myError", "error message should be 'myError'")
            } else {
                XCTFail("error value should be MyError.")
            }
            expectation.fulfill()
            return nil
        }
        waitForExpectationsWithTimeout(5.0, handler: nil)
    }

    func testCatchShouldConsumeError() {
        let expectation = expectationWithDescription("finish task");
        HNTask.reject(MyError(message: "myError")).catch { error in
            return 100
        }.continueWith { context in
            XCTAssertFalse(context.isError(), "error should be consumed.")
            if let intValue = context.result as? Int {
                XCTAssertEqual(intValue, 100, "previous value should be passed.")
            } else {
                XCTFail("previous value should be Int.")
            }
            expectation.fulfill()
            return (nil, nil)
        }
        waitForExpectationsWithTimeout(5.0, handler: nil)
    }
    
    func testFinallyShouldRunWhenSucceeded() {
        let expectation = expectationWithDescription("finish task");
        HNTask.resolve(30).finally {
            expectation.fulfill()
            return nil
        }
        waitForExpectationsWithTimeout(5.0, handler: nil)
    }

    func testFinallyShouldRunWhenFailed() {
        let expectation = expectationWithDescription("finish task");
        HNTask.reject(MyError(message: "myError")).finally {
            expectation.fulfill()
            return nil
        }
        waitForExpectationsWithTimeout(5.0, handler: nil)
    }
    
    func testFinallyShouldCompleteAfterReturnedTasksCompletion() {
        let expectation = expectationWithDescription("finish task");
        var v = 0
        HNTask.resolve(30).finally {
            return self.delayAsync(1) {
                v = 100
            }
        }.then { value in
            XCTAssertEqual(v, 100, "called after the task returnd from finally()")
            expectation.fulfill()
            return nil
        }
        waitForExpectationsWithTimeout(5.0, handler: nil)
    }
    
    // TODO: testFinallyShouldNotChangeResultValue()
    
    func makeStringAsync(str: String) -> HNTask {
        let task = HNTask.resolve(str + "s")
        return task
    }
    
    func testExecutionOrder() {
        let expectation = expectationWithDescription("finish task");
        HNTask.resolve("").then { value in
            if let str = value as? String {
                return str + "a"
            } else {
                return HNTask.reject(MyError(message: "error"))
            }
        }.then { value in
            if var str = value as? String {
                str += "b"
                return self.makeStringAsync(str)
            } else {
                return HNTask.reject(MyError(message: "error"))
            }
        }.then { value in
            if let str = value as? String {
                return str + "c"
            } else {
                return HNTask.reject(MyError(message: "error"))
            }
        }.continueWith { context in
            XCTAssertFalse(context.isError(), "error should not occured")
            if let str = context.result as? String {
                XCTAssertEqual(str, "absc", "check order")
            } else {
                XCTFail("result value should be String")
            }
            expectation.fulfill()
            return (nil, nil)
        }
        waitForExpectationsWithTimeout(5.0, handler: nil)
    }
    
    func delayAsync(milliseconds: Int, callback: () -> Void) -> HNTask {
        let task = HNTask.newTask { (resolve, reject) in
            let delta: Int64 = Int64(milliseconds) * Int64(NSEC_PER_MSEC)
            let time = dispatch_time(DISPATCH_TIME_NOW, delta);
            dispatch_after(time, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
                callback()
                resolve(milliseconds)
            }
        }
        return task
    }
    
    func timeoutAsync(milliseconds: Int) -> HNTask {
        let task = HNTask.newTask { (resolve, reject) in
            let delta: Int64 = Int64(milliseconds) * Int64(NSEC_PER_MSEC)
            let time = dispatch_time(DISPATCH_TIME_NOW, delta);
            dispatch_after(time, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
                reject(MyError(message: "timeout"))
            }
        }
        return task
    }
    
    func testThenShouldBeCalledAfterAllTasksAreCompleted() {
        let expectation = expectationWithDescription("finish task");
        var value = 0
        let task1 = delayAsync(100, callback:{ value += 100 })
        let task2 = delayAsync(300, callback:{ value += 300 })
        let task3 = delayAsync(200, callback:{ value += 200 })
        HNTask.all([task1, task2, task3]).then { values in
            XCTAssertEqual(value, 600, "all task shoule be completed")
            if let results = values as? Array<Any?> {
                let v1 = results[0] as Int
                let v2 = results[1] as Int
                let v3 = results[2] as Int
                XCTAssertEqual(v1, 100, "task1 should return 100")
                XCTAssertEqual(v2, 300, "task1 should return 300")
                XCTAssertEqual(v3, 200, "task1 should return 200")
            } else {
                XCTFail("values should be a type of Array")
            }
            expectation.fulfill()
            return nil
        }
        waitForExpectationsWithTimeout(5.0, handler: nil)
    }
    
    func testCatchAfterAllShouleBeCalledWhenTaskReturnsError() {
        let expectation = expectationWithDescription("finish task");
        var value = 0
        let task1 = delayAsync(100, callback:{ value += 100 })
        let task2 = timeoutAsync(150)
        let task3 = delayAsync(200, callback:{ value += 200 })
        HNTask.all([task1, task2, task3]).then { values in
            return nil
        }.catch { error in
            if let err = error as? MyError {
                XCTAssertEqual(err.message, "timeout")
            } else {
                XCTFail("error should be a type of MyError")
            }
            expectation.fulfill()
            return nil
        }
        waitForExpectationsWithTimeout(5.0, handler: nil)
    }
    
    func testThenShouldBeCalledAfterOneTaskInRaceIsCompleted() {
        let expectation = expectationWithDescription("finish task");
        let task1 = delayAsync(100, callback:{ })
        let task2 = delayAsync(700, callback:{ })
        let task3 = delayAsync(500, callback:{ })
        HNTask.race([task1, task2, task3]).then { value in
            if let result = value as? Int {
                XCTAssertEqual(result, 100, "first task should pass the result")
            } else {
                XCTFail("result should be a type of Int")
            }
            expectation.fulfill()
            return nil
        }
        waitForExpectationsWithTimeout(5.0, handler: nil)
    }
    
    func testCatchAfterRaceShouleBeCalledWhenTaskReturnsError() {
        let expectation = expectationWithDescription("finish task");
        var value = 0
        let task1 = delayAsync(500, callback:{ })
        let task2 = timeoutAsync(150)
        let task3 = delayAsync(700, callback:{ })
        HNTask.race([task1, task2, task3]).then { values in
            return nil
        }.catch { error in
            if let err = error as? MyError {
                XCTAssertEqual(err.message, "timeout")
            } else {
                XCTFail("error should be a type of MyError")
            }
            expectation.fulfill()
            return nil
        }
        waitForExpectationsWithTimeout(5.0, handler: nil)
    }

    func testThenShouldBeCalledAfterAllTasksAreSettled() {
        let expectation = expectationWithDescription("finish task");
        var value = 0
        let task1 = delayAsync(100, callback:{ value += 100 })
        let task2 = delayAsync(300, callback:{ value += 300 })
        let task3 = delayAsync(200, callback:{ value += 200 })
        HNTask.allSettled([task1, task2, task3]).then { values in
            XCTAssertEqual(value, 600, "all task shoule be completed")
            if let results = values as? Array<Any?> {
                let v1 = results[0] as Int
                let v2 = results[1] as Int
                let v3 = results[2] as Int
                XCTAssertEqual(v1, 100, "task1 should return 100")
                XCTAssertEqual(v2, 300, "task1 should return 300")
                XCTAssertEqual(v3, 200, "task1 should return 200")
            } else {
                XCTFail("values should be a type of Array")
            }
            expectation.fulfill()
            return nil
        }
        waitForExpectationsWithTimeout(5.0, handler: nil)
    }

    func testThenShouldBeCalledAfterAllTasksAreSettledEvenIfOneOfThemIsRejected() {
        let expectation = expectationWithDescription("finish task");
        var value = 0
        let task1 = delayAsync(100, callback:{ value += 100 })
        let task2 = timeoutAsync(150)
        let task3 = delayAsync(200, callback:{ value += 200 })
        HNTask.allSettled([task1, task2, task3]).then { values in
            XCTAssertTrue(task1.isCompleted(), "task1 should be completed")
            XCTAssertTrue(task2.isCompleted(), "task2 should be completed")
            XCTAssertTrue(task3.isCompleted(), "task3 should be completed")
            
            if let results = values as? Array<Any?> {
                let v1 = results[0] as Int
                let v3 = results[2] as Int
                XCTAssertEqual(v1, 100, "task1 should return 100")
                XCTAssertEqual(v3, 200, "task1 should return 200")
                
                if let v2 = results[1] as? MyError {
                    XCTAssertEqual(v2.message, "timeout", "task2 should be timeout.")
                } else {
                    XCTFail("values[1] should be a type of MyError.")
                }
            } else {
                XCTFail("values should be a type of Array.")
            }
            
            expectation.fulfill()
            return nil
        }
        waitForExpectationsWithTimeout(5.0, handler: nil)
    }

    
    func testAsyncExecutorsRunAsync() {
        let expectation = expectationWithDescription("finish task");
        HNAsyncExecutor.sharedExecutor.runAsync {
            return "ran"
        }.then { value in
            if let result = value as? String {
                XCTAssertEqual(result, "ran", "return value should be passed.")
            } else {
                XCTFail("result should be a type of String")
            }
            expectation.fulfill()
            return nil
        }
        waitForExpectationsWithTimeout(5.0, handler: nil)
    }
    
}
