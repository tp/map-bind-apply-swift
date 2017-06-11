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


//: bind

// has type : ('a -> 'b option) -> 'a option -> 'b option
func bindOption<A, B>(_ f: @escaping (A) -> Optional<B>) -> (Optional<A>) -> Optional<B> {
    return {
        a in
        guard case .some(let a) = a else {
            return .none
        }
    
        return f(a)
    }
}

func bindList<A, B>(_ f: @escaping (A) -> Array<B>) -> (Array<A>) -> Array<B> {
    return {
        a in
        a.flatMap { f($0) }
    }
}

func parseInt(_ s: String) -> Optional<Int> {
    return Int.init(s)
}

struct OrderQuantity {
    let quantity: Int
}

func orderQuantity(_ quantity: Int) -> Optional<OrderQuantity> {
    if (quantity >= 1) {
        return .some(OrderQuantity(quantity: quantity))
    } else {
        return .none
    }
}

let boundOrderQuantity = bindOption(orderQuantity)

// signature is String -> Optional<OrderQuantity>
let parseOrderQty = { str in bindOption(orderQuantity)(parseInt(str)) }

infix operator >>=: ApplyOperatorPrecedence

public func >>= <A, B>(_ a: Optional<A>, _ f: @escaping (A) -> Optional<B>) -> Optional<B> {
    return bindOption(f)(a)
}

let parseOrderQty_alt = { str in parseInt(str) >>= orderQuantity }

// defining the |> operator, so we can write the example like in the series

infix operator |>: ApplyOperatorPrecedence

public func |> <A, B>(_ a: A, _ f: @escaping (A) -> B) -> B {
    return f(a)
}

let parseOrderQty_pipe = { $0 |> parseInt >>= orderQuantity }

parseOrderQty("0")
parseOrderQty("1")

parseOrderQty_alt("0")
parseOrderQty_alt("1")

parseOrderQty_pipe("0")
parseOrderQty_pipe("1")

//: Part 3: Using the core functions in practice

// Example: Validation using applicative style and monadic style

enum ValidatedObjectCreationResult<Value> {
    case success(Value)
    case failure(Array<String>)
}

struct CustomerId {
    let id: Int;
    
    private init(id: Int) {
        self.id = id
    }
    
    public static func create(_ id: Int) -> ValidatedObjectCreationResult<CustomerId> {
        if id > 0 {
            return .success(CustomerId(id: id));
        } else {
            return .failure(["CustomerId must be positive"])
        }
    }
}

struct CustomerEmail {
    let email: String;
    
    private init(email: String) {
        self.email = email
    }
    
    public static func create(_ email: String) -> ValidatedObjectCreationResult<CustomerEmail> {
        if email.isEmpty {
            return .failure(["CustomerEmail must not be empty"])
        } else if !email.contains("@") {
            return .failure(["CustomerEmail must contain @-sign"])
        } else {
            return .success(CustomerEmail(email: email))
        }
    }
}

// Signature: ('a -> 'b) -> Result<'a> -> Result<'b>
func mapResult<A, B>(_ f: @escaping (A) -> B) -> (ValidatedObjectCreationResult<A>) -> ValidatedObjectCreationResult<B> {
    return { a in
        switch a {
        case .success(let aValue):
            return .success(f(aValue))
        case .failure(let failureValue):
            return .failure(failureValue)
        }
    }
}

// T -> Result<T>
func retn<T>(_ v: T) -> ValidatedObjectCreationResult<T> {
    return .success(v)
}

// Signature: Result<('a -> 'b)> -> Result<'a> -> Result<'b>
// apply
func applyResult<A, B>(_ f: ValidatedObjectCreationResult<(A) -> B>) -> (ValidatedObjectCreationResult<A>) -> ValidatedObjectCreationResult<B> {
    return {
        a in
        switch (f, a) {
        case (.success(let f), .success(let a)):
            return .success(f(a))
        case (.failure(let f), .success(_)):
            return .failure(f)
        case (.success(_), .failure(let a)):
            return .failure(a)
        case (.failure(let f), .failure(let a)):
            return .failure(f + a)
        }
    }
}

// Signature: ('a -> Result<'b>) -> Result<'a> -> Result<'b>
// bind
func bindResult<A, B>(_ f: @escaping (A) -> ValidatedObjectCreationResult<B>) -> (ValidatedObjectCreationResult<A>) -> ValidatedObjectCreationResult<B> {
    return {
        a in
        switch a {
            case .success(let a):
                return f(a)
            case .failure(let failure):
                return .failure(failure)
        }
    }
}

struct CustomerInfo {
    let id: CustomerId
    let email: CustomerEmail
}

let createCustomer = curry(CustomerInfo.init)

// operators

func <*> <A, B>(_ f: ValidatedObjectCreationResult<(A) -> B>, _ a: ValidatedObjectCreationResult<A>) -> ValidatedObjectCreationResult<B> {
    return applyResult(f)(a)
}

func <!> <A, B>(_ f: @escaping (A) -> B, _ a: ValidatedObjectCreationResult<A>) -> ValidatedObjectCreationResult<B> {
    return mapResult(f)(a)
}

// Applicative style

func createCustomerInfoResultAf(id: Int, email: String) -> ValidatedObjectCreationResult<CustomerInfo> {
    let id = CustomerId.create(id)
    let email = CustomerEmail.create(email)
    return createCustomer <!> id <*> email
}
let createCustomerInfoResultA = curry(createCustomerInfoResultAf)

// trying it out
let goodId = 1
let badId = 0
let goodEmail = "test@example.com"
let badEmail = "example.com"

let goodCustomerA = createCustomerInfoResultA(goodId)(goodEmail)
let badCustomerA = createCustomerInfoResultA(badId)(badEmail)

// Monadic style

func >>= <A, B>(_ a: ValidatedObjectCreationResult<A>, _ f: @escaping (A) -> ValidatedObjectCreationResult<B>) -> ValidatedObjectCreationResult<B> {
    return bindResult(f)(a)
}

func createCustomerInfoResultMf(id: Int, email: String) -> ValidatedObjectCreationResult<CustomerInfo> {
    return CustomerId.create(id) >>= {
        customerId in
        CustomerEmail.create(email) >>= {
            customerEmail in
            return .success(createCustomer(customerId)(customerEmail))
        }
    }
}
let createCustomerInfoResultM = curry(createCustomerInfoResultMf)

let goodCustomerM = createCustomerInfoResultM(goodId)(goodEmail)
let badCustomerM = createCustomerInfoResultM(badId)(badEmail) // Note: only contains the first error message

