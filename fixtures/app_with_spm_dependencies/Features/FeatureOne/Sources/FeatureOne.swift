import Alamofire
import Stringify

public func start() {
    // Use Alamofire to make sure it links fine
    _ = AF.download("http://www.google.com")
    
    let x = 3
    let y = 4
    
    let new = #stringify(x + y)
    print(new)
}
