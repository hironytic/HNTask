HNTask
======

Utility for asynchronous operations written in Swift.

With `HNTask`, you can organize asynchronous operations in the pattern like a JavaScript Promise. The core algorithm is inspired by `BFTask` in [Bolts-iOS](https://github.com/BoltsFramework/Bolts-iOS) and the core syntax came from JavaScript Promise.

## Using HNTask

### Example

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

### Creating New Task

TODO:

- unresolved task with ```newTask()```, resolve or reject future.
- resolved task with ```resolve()```.
- rejected task with ```reject()```. also refers HNTaskError protocol.


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

let rejectedTask = HNTask.reject(NSError(domain: "MyDomain",
                                           code: 1,
                                       userInfo: nil))
```

### Chaining Tasks

TODO:

- a result value is passed to the next block.
- if result value is HNTask object, next ```then``` block is called after the result task is resolved and its chained blocks are executed.


### Error Handling

TODO:

- reject with `newTask()`'s `reject` function
- reject by returning rejected task.
- handle erro by `catch` block.

### Run Tasks in Series

TODO:

write about ```task = task.then({ })``` style in for-loop.

### Waiting Multiple Tasks

TODO:

- `BNTask.all()`
- `BNTask.race()`

### Executor

TODO:


## License

- MIT License
