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

precedencegroup ApplyOperatorPrecedence {
    associativity: left
    higherThan: MultiplicationPrecedence
}

// apply operator
infix operator <*>: ApplyOperatorPrecedence

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

precedencegroup MapOperatorPrecedence {
    associativity: left
    higherThan: ApplyOperatorPrecedence
}

// map operator
infix operator <!> : MapOperatorPrecedence

// Operator definition
public func <!> <A, B>(_ f: @escaping (A) -> B, _ a: Optional<A>) -> Optional<B> {
    return mapOption(f)(a)
}

curriedAdd <!> .some(4) <*> .some(5)

public func <!> <A, B>(_ f: @escaping (A) -> B, _ a: Array<A>) -> Array<B> {
    return mapList(f)(a)
}

mapList(curriedAdd)([5, 10])
mapList(curriedAdd)([5, 10]) <*> [1, 2]

curriedAdd <!> [5, 10] <*> [1, 2]

//: lift2


let addTriple = { (a: Int, b: Int, c: Int) in
    return a + b + c
}

let curriedAddTriple = curry(addTriple)

func optionLift2<A, B, C>(_ f: @escaping (A) -> (B) -> (C)) -> (Optional<A>) -> (Optional<B>) -> Optional<C> {
    return {
        x in
        return {
            y in
            f <!> x <*> y
        }
    }
}

func optionLift3<A, B, C, D>(_ f: @escaping (A) -> (B) -> (C) -> (D)) -> (Optional<A>) -> (Optional<B>) -> (Optional<C>) -> Optional<D> {
    return {
        x in
        return {
            y in
            return {
                z in
                f <!> x <*> y <*> z
            }
        }
    }
}

let addPairOpt = optionLift2(curriedAdd)
addPairOpt(.some(1))(.some(2))

let addTripleOpt = optionLift3(curriedAddTriple)
addTripleOpt(.some(1))(.some(2))(.some(3))

//: one sided combinators <* and *>

// NOTE(tp): listLift was not explained in the article, but I presume this to be the correct implementation
func listLift2<A, B, C>(_ f: @escaping (A) -> (B) -> (C)) -> (Array<A>) -> (Array<B>) -> Array<C> {
    return {
        x in
        return {
            y in
            f <!> x <*> y
        }
    }
}

precedencegroup CombineOperatorPrecedence {
    associativity: left
    higherThan: MultiplicationPrecedence
}

infix operator <*: CombineOperatorPrecedence

public func <* <A, B>(_ x: Array<A>, _ y: Array<B>) -> Array<A> {
    return listLift2({ leftA in { rightB in leftA } })(x)(y)
}

[1, 2] <* [3, 4, 5]   // expected: [1; 1; 1; 2; 2; 2]


infix operator *>: CombineOperatorPrecedence

public func *> <A, B>(_ x: Array<A>, _ y: Array<B>) -> Array<B> {
    return listLift2({ leftA in { rightB in rightB } })(x)(y)
}

[1, 2] *> [3, 4, 5]   // expected: [3; 4; 5; 3; 4; 5]

let repeatPattern = { (n: Int) in
    return { (x: Array<Any>) in // NOTE(tp): Fails without the type annotation
        return Array(0..<n) *> x
    }
}

repeatPattern(3)(["a", "b"]) // expected: ["a"; "b"; "a"; "b"; "a"; "b"]

let replicate = { (n: Int) in
    return { (x: Any) in // NOTE(tp): Fails without the type annotation
        return Array(0..<n) *> [x]
    }
}

replicate(5)("A") // expected: ["A"; "A"; "A"; "A"; "A"]
