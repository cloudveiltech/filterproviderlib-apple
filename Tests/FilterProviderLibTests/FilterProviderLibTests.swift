import XCTest
@testable import FilterProviderLib

final class FilterProviderLibTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(FilterProviderLib().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
