HNTask
======

Utility for asynchronous operations, written in Swift.

With `HNTask`, you can organize asynchronous operations in the pattern like a JavaScript Promise. The core algorithm is inspired by `BFTask` in [Bolts-iOS](https://github.com/BoltsFramework/Bolts-iOS) and the core syntax came from JavaScript Promise.

## Example

In this example, `UserList.countUserAsync()` and `self.makeTotalUserStringAsync()` are functions which require some asynchronous operation to get a result. Each of these functions returns a `HNTask` object.
When the asynchronous operation is done in success, the next `then` block is called. If error occurs in the operation, `then` block is skipped and the next `catch` block is called.

```swift
extension NSError: HNTaskError { }

UserList.countUsersAsync().then { value in
    let count = value as Int
    if count <= 0 {
        return HNTask.reject(NSError(domain: "MyDomain",
                                       code: 1,
                                   userInfo: nil))
    } else {
        return self.makeTotalUserStringAsync(count)
    }
}.then { value in
    let message = value as String
    self.showMessage(message)
    return nil
}.catch { error in
    let err = error as NSError
    self.showMessage(err.description)
    return nil
}
```

## Creating New Task

Use `HNTask.newTask()` to create a new task. It returns an unresolved (uncompleted) task object which is resolved or rejected when the operation is done. The passed block is called immediately to start asynchronous operation and it takes two function parameters, `resolve` and `reject`. Call one of these function to resolve or reject the task.

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

An `HNTask` object has `then()` method. It takes a block called after the task is resolved. When the block is called, the result value of the task, which was passed to `resolve()`, is passed as a block's parameter.

`then()` returns new `HNTask` object. You can chain `then` blocks by calling `then()` of the returned `HNTask`.

If you return `HNTask` object in `then` block, it is executed prior to next block. In the following example, the last `then` block, in which a value is printed out, is executed after the task returned by `eatAsync()` is executed. In fact, it is the time `resolve("I ate \(food)")` run.

```swift
func eatAsync(food: String) -> HNTask {
    let task = HNTask.newTask { (resolve, reject) in
        // supporse callItAfter fires 300 milliseconds later
        callItAfter(300) {
            resolve("I ate \(food)")
        }
    }
    return task
}

HNTask.resolve(3).then { value in
    let number = value as Int       // number == 3
    return "\(number) apples"
}.then { value in
    let string = value as String    // string == "3 apples"
    return eatAsync(string)
}.then { value in
    println(value)                  // value == "I ate 3 apples."
    return nil
}
```

## Error Handling

TODO:

- reject with `newTask()`'s `reject` function
- reject by returning rejected task.
- handle erro by `catch` block.

## Run Tasks in Series

TODO:

write about ```task = task.then({ })``` style in for-loop.

## Waiting Multiple Tasks

TODO:

- `BNTask.all()`
- `BNTask.race()`

## Executor

TODO:
