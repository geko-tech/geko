import Foundation

public typealias Factory<T> = ParameterizedFactory<T, Void>

@dynamicMemberLookup
public struct ParameterizedFactory<T, Parameters> {

    private let factory: (Parameters) -> T

    public init(_ factory: @escaping (Parameters) -> T) {
        self.factory = factory
    }

    public func make(with parameters: Parameters) -> T {
        factory(parameters)
    }

    public func callAsFunction(_ parameters: Parameters) -> T {
        factory(parameters)
    }

    public func map<R>(_ transform: @escaping (T) -> R) -> ParameterizedFactory<R, Parameters> {
        ParameterizedFactory<R, Parameters> { transform(factory($0)) }
    }

    public subscript<R>(dynamicMember keyPath: KeyPath<T, R>) -> ParameterizedFactory<R, Parameters> {
        ParameterizedFactory<R, Parameters> { factory($0)[keyPath: keyPath] }
    }
}

public extension ParameterizedFactory where Parameters == Void {

    init(_ factory: @autoclosure @escaping () -> T) {
        self.init(factory)
    }

    func make() -> T { make(with: ()) }

    func callAsFunction() -> T { callAsFunction(()) }
}

