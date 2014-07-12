HNTask
======

Utility for asynchronous operations, written in Swift.

With `HNTask`, you can organize asynchronous operations in the pattern like a JavaScript Promise. The core algorithm is inspired by `BFTask` in [Bolts-iOS](https://github.com/BoltsFramework/Bolts-iOS) and the core syntax came from JavaScript Promise.

## Example

In this example, `countUserAsync()` and `makeTotalUserStringAsync()` are functions which require some asynchronous operation to get a result. Each of these functions returns an `HNTask` object.
When the asynchronous operation is done in success, the next then-block is called. If an error occurs in the operation, then-block is skipped and the next catch-block is called.

```swift
extension NSError: HNTaskError { }

userList.countUsersAsync().then { (count: Int) in
    if count <= 0 {
        return HNTask.reject(NSError(domain: "MyDomain",
                                       code: 1,
                                   userInfo: nil))
    } else {
        return makeTotalUserStringAsync(count)
    }
}.then { (message: String) in
    showMessage(message)
    return nil
}.catch { error in
    let err = error as NSError
    showMessage(err.description)
    return nil
}
```

## Creating a New Task

Use `HNTask.newTask()` to create a new task. It returns an unresolved (uncompleted) task object which should be resolved or rejected when the operation is done. The passed block is called immediately to start asynchronous operation. It takes two function parameters, `resolve` and `reject`. Call one of these function to resolve or reject the task.

For convenience, you can also create a new task by `HNTask.resove()` or `HNTask.reject()`. These functions return a resolved or rejected task. Use these functions if you know the result of the task before creating it.

For more information about rejecting, see *Error Handling*.

```swift
let unresolvedTask = HNTask.newTask { (resolve, reject) in
    // do some asynchronous operation
    SomeAPI.post(url, 
        success: { result in
            resolve(result)
        }, 
        failure: { error in
            reject(error)
        })
}

let resolvedTask = HNTask.resolve(100)

let rejectedTask = HNTask.reject(MyError(code: 100))
```

## Chaining Tasks

An `HNTask` object has a method `then()`. It returns a new `HNTask` object. You can chain then-blocks by calling `then()` of the returned `HNTask`.

The then-block, closure parameter of `then()`, is executed after the task is resolved. The block takes one parameter whose value is the result of the task, which was passed to `resolve` function or was a return value in previous then-block. If you specify the type of the closure parameter, as shown in the first and the second then-blocks in example below, the type of the result value is checked. When types are mismatch, the then-block is not executed and the task is rejected with an `HNTaskTypeError` value. You cannot specify an optional (such as `FooType?`) in type.

You must return a result value in the block. If you have no result, return `nil`. When you return an `HNTask` object in then-block, it is executed prior to next block. In the following example, the last then-block, in which a value is printed out, is executed after the task returned by `eatAsync()` is executed. In fact, it is the time `resolve("I ate \(food)")` run.

```swift
func eatAsync(food: String) -> HNTask {
    let task = HNTask.newTask { (resolve, reject) in
        // suppose callItAfter runs the block 300 milliseconds later
        callItAfter(300) {
            resolve("I ate \(food)")
        }
    }
    return task
}

HNTask.resolve(3).then { (number: Int) in
    return "\(number) apples"       // number == 3
}.then { (string: String) in
    return eatAsync(string)         // string == "3 apples"
}.then { value in
    println(value)                  // value == "I ate 3 apples."
    return nil
}
```

## Error Handling

When an asynchronous operation fails, you can make an error by calling `reject` function which is passed as parameter of newTask-block (see *Creating a New Task*). If an error has occured in then-block, you can reject the task chain by returning rejected `HNTask` object.

Both of `reject` function or `HNTask.reject()` take one error object which conforms to `HNTaskError` protocol. `HNTaskError` protocol requires no property nor method. You can define your own class for error object, or you can extend an existing class by extension to make it adopt `HNTaskError`. In the first example shown in *Example*, `NSError` class is extended.

If a task was rejected, next then-blocks are not called but catch-block is called. You can handle errors in catch-block. The error object which was used in rejection is passed to catch-block as a pameter.

The method `catch()` returns a new `HNTask` like `then()` and you can chain more then-block and/or catch-block.

```swift
class MyError: HNTaskError {
    let code: Int
    init(code: Int) {
        self.code = code
    }
}

HNTask.resolve(-3).then { (number: Int) in
    if number >= 0 {
        return "\(number) apples"
    } else {
        return HNTask.reject(MyError(code: -3))
    }
}.then { value in
    // this block will not be executed
    return nil
}.catch { error in
    if let myError = error as? MyError {
        println(myError.code)
    }
    return nil
}
```

The method `finally()` returns a new `HNTask` like `then()` but the returned task will be resolved or rejected with the same value of the previous task, in other words, it does not modify the final value. You can return another task in finally-block. In this case, the completion of the task returned by `finally()` will be delayed until the task returned by finally-block is finished. If you don't have another task in finally-block, simply return nil. Unlike `then()`, you cannot return other values because the finally-block cannot change the resolved value (or rejected value) of the task.

## Run Tasks in Series

You can run tasks in series by simply chaining tasks.
Here is an example of tasks in the for-in loop.

```swift
userList.countUsersAsync().then { (count: Int) in
    var task = HNTask.resolve(nil)
    for index in 0..count {
        task = task.then { value in
            return userList.getUserNameAsync(index)
        }.then { value in
            if let name = value as? String {
                addNameToList(name)
            }
            return nil
        }
    }
    
    return nil
}
```

## Waiting for Multiple Tasks

By using `HNTask.all()`, you can wait until all tasks are resolved. As following example, `HNTask.all()` returns an HNTask object and next then-block receives the array contains the resolved values in the same order as the original tasks.

If one of the tasks is rejected, the task returned by `HNTask.all()` is rejected immediately. If you want to wait until all tasks are completed (resoved or even rejected), use `HNTask.allSettled()`. 

```swift
let tasks = [
    userList.getUserNameAsync(1),
    userList.getUserNameAsync(3),
    userList.getUserNameAsync(5)
]

HNTask.all(tasks).then { value in
    // after all task is resolved, this block is executed.
    // the parameter value is an array contains the
    // resolved values of each task in the same order.
    let list = value as [Any?]
    for v in list {
        if let name = v as? String {
            addNameToList(name)
        }
    }
    return nil
}.catch { error in
    // when one of the tasks rejected, this block is executed
    // in this case, other tasks could be uncompleted yet
    println(error)
    return nil
}
```

```swift
HNTask.allSettled(tasks).then { value in
    // after all task is resolved/rejected, this block is executed
    // parameter value is an array contains resolved/rejected values
    // of each task in the same order.
    let list = value as [Any?]
    for v in list {
        if let error = v as? MyError {
            println(error)
        } else if let name = v as? String {
            addNameToList(name)
        }
    }
    return nil
}
```

By using `HNTask.race()`, you can wait until one of the task is resolved. In this case, the next then-block receives the one result value of the resolved task.

```swift
func setTimeoutAsync(milliseconds: Int) -> HNTask {
    return HNTask.newTask { resolve, reject in
        callItAfter(milliseconds) {
            resolve("(timeout)")
        }
    }
}

HNTask.race([
    userList.getUserNameAsync(1),
    setTimeoutAsync(1000)
]).then { value in
    // if getUserNameAsync() takes more time than 1 second,
    // the result will be "(timeout)"
    if let name = value as? String {
        addNameToList(name)
    }
    return nil
}
```


## Executors

A subsequent task generated by `then()` or `catch()` is executed by "executor". An executor is the object which conforms to the `HNExecutor` protocol. Both `then()` and `catch()` have the version which takes an executor at first parameter. If you don't specify an executor, i.e. you use the method which takes no executor, an instance of `HNAsyncExecutor` class is used as the default executor. If you want to change the default executor, you can assign an executor to `HNTask.DefaultTaskExecutor.sharedExecutor`.

There are three executor classes. `HNAsyncExecutor`, `HNDispatchQueueExecutor` and `HNMainQueueExecutor`.

#### HNAsyncExecutor

`HNAsyncExecutor` executes a task in background  asynchronously. To get an instance of `HNAsyncExecutor`, use `HNAsyncExecutor.sharedExecutor` instead of creating a new instance.

For convenience, `HNAsyncExecutor` has method `runAsync()`. You can use this method to create an asynchronous task easily.

```swift
func doSomethingAsync() -> HNTask {
    return HNAsyncExecutor.sharedExecutor.runAsync() {
        // do something asynchrounously
            ...
        return theResultOfTask
    }
}
``` 

#### HNDispatchQueueExecutor

`HNDispatchQueueExecutor` executes a task on specified GCD queue. It also has `runAsync()` and makes you possible to create an asynchrounous task which should be executed on specific queue.

#### HNMainQueueExecutor

`HNMainQueueExecutor` executes a task on main queue. The task is executed on main thread. To get an instance of `HNMainQueueExecutor`, use `HNMainQueueExecutor.sharedExecutor` instead of creating a new instance.

By using this executor, you can force the task execute on main thread. For example, you may want to update the UI controls on main thread.

```swift
userList.getUserNameAsync(1).then(HNMainQueueExecutor.sharedExecutor) { (value: String) in
    // this block is executed on main thread.
    nameLabel.text = value
    return nil
}
```

#### Your Own Executor
In addition to that, you can also create your own executor by adapting to the `HNExecutor` protocol.
