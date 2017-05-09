//: https://fsharpforfunandprofit.com/posts/elevated-world/

//: map

func mapOption<A, B>(_ f: @escaping (A) -> B) -> (Optional<A>) -> Optional<B> {
    return {
        optA in
        guard case .some(let a) = optA else {
            return .none
        }

        return f(a)
    }
}

let add = { (a: Int, b: Int) in
    return a + b
}

let add1 = { b in
    return b + 1
}

add1(2)

let add1IfSomething = mapOption(add1)

add1IfSomething(.none)
add1IfSomething(.some(2))


func mapList<A, B>(_ f: @escaping (A) -> B) -> (Array<A>) -> Array<B> {
    return {
        a in
        return a.map(f)
    }
}

let add1ToEachElement = mapList(add1)

add1ToEachElement([1, 2, 3])

mapList(add1)([4, 5, 6])


//: return

func returnOption<A>(_ a: A) -> Optional<A> {
    return .some(a)
}

func returnList<A>(_ a: A) -> Array<A> {
    return [a]
}

returnOption("🙃")
returnList(1)


//: apply


func applyOption<A, B>(_ f: Optional<(A) -> B>, _ a: Optional<A>) -> Optional<B> {
    guard case .some(let f) = f, case .some(let a) = a else {
        return .none
    }
    
    return .some(f(a))
}

let noneAdd = Optional<(Int) -> Int>.none
applyOption(noneAdd, .none)
applyOption(.some(add1), .none)
applyOption(.some(add1), .some(1))
applyOption(noneAdd, .some(5))

let curriedAdd = curry(add);
let someCurriedAdd = Optional.some(curriedAdd)
let addAnd5 = applyOption(someCurriedAdd, .some(5))
let addAndNone = applyOption(someCurriedAdd, .none) // already returns .none
addAnd5!(3) // needs force unwrap or check
// addAndNone(3) // impossible, already .none

// TODO(tp): Range apply

func applyList<A, B>(_ fs: Array<(A) -> B>, _ a: Array<A>) -> Array<B> {
    return fs.flatMap {
        f in
        a.map(f)
    }
}

let add5 = curriedAdd(5)
let add10 = curriedAdd(10)
applyList([add5, add10], [0, 1, 2])

precedencegroup ApplyPrecedence {
    associativity: left
    higherThan: MultiplicationPrecedence
}

infix operator <*>: ApplyPrecedence

// Operator definition
public func <*> <A, B>(_ f: Optional<(A) -> B>, _ a: Optional<A>) -> Optional<B> {
    return applyOption(f, a)
}


Optional.some(curriedAdd) <*> .some(5) <*> .some(3)

public func <*> <A, B>(_ fs: Array<(A) -> B>, a: Array<A>) -> Array<B> {
    return applyList(fs, a)
}

[add5] <*> [1, 2]
[curriedAdd] <*> [0, 1]
[curriedAdd] <*> [0, 2] <*> [10, 20, 30]
