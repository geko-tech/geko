import Foundation

// Expected: All bellow unsafe
public let publicInferredIntegerCase = 1
public let publicInferredStringCase = "string"
public let publicInferredArrayCase = [1, 2, 3]
public let publicInferredDictionaryCase = ["one": 1]
public let publicInferredConstructorCase = PublicInferenceConstructedCase(value: 4)
public let publicInferredFactoryCase = publicInferenceFactoryFunction()
public let publicInferredClosureCase = { (value: Int) -> String in String(value) }
public let publicInferredTupleCase = (count: 1, name: "one")


