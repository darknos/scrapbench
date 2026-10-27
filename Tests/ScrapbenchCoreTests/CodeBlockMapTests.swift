import Foundation
import Testing
@testable import ScrapbenchCore

@Suite struct CodeBlockMapTests {
    func map(_ s: String) -> CodeBlockMap { CodeBlockMap(text: s as NSString) }

    @Test func closedFence() {
        let text = "intro\n```json\n{\"a\": 1}\n```\nafter\n"
        let m = map(text)
        #expect(m.blocks.count == 1)
        let b = m.blocks[0]
        #expect(b.language == "json")
        #expect(b.fenceOpen == NSRange(location: 6, length: 7))
        #expect(b.body == NSRange(location: 14, length: 9))
        #expect(b.fenceClose == NSRange(location: 23, length: 3))
        #expect(b.whole == NSRange(location: 6, length: 20))
    }

    @Test func unclosedFenceExtendsToEnd() {
        let text = "a\n```sql\nselect 1\n"
        let b = map(text).blocks[0]
        #expect(b.fenceClose == nil)
        #expect(b.body == NSRange(location: 9, length: 9))
        #expect(b.whole.upperBound == (text as NSString).length)
    }

    @Test func adjacentFences() {
        let text = "```go\nx\n```\n```yaml\ny: 1\n```\n"
        let m = map(text)
        #expect(m.blocks.map(\.language) == ["go", "yaml"])
    }

    @Test func fenceMapHandlesCRLF() {
        let text = "a\r\n```json\r\n{}\r\n```\r\nb\r\n"
        let m = map(text)
        #expect(m.blocks.count == 1)
        #expect(m.blocks[0].language == "json")
        #expect(m.blocks[0].fenceClose != nil)
    }

    @Test func fenceWithTrailingSpacesAndNoLanguage() {
        let text = "```   \nraw\n```  \n"
        let m = map(text)
        #expect(m.blocks.count == 1)
        #expect(m.blocks[0].language == nil)
        #expect(m.blocks[0].fenceClose != nil)
    }

    @Test func indentedFenceIsIgnored() {
        #expect(map("    ```json\nx\n").blocks.isEmpty)
    }

    @Test func blockContainingOffset() {
        let text = "a\n```json\n{}\n```\nb\n"
        let m = map(text)
        #expect(m.block(containing: 0) == nil)
        #expect(m.block(containing: 4) != nil)   // inside the opening fence
        #expect(m.block(containing: 11) != nil)  // body
        #expect(m.block(containing: 17) == nil)  // "b"
    }

    @Test func shiftedMovesBlocksAfterEdit() {
        let text = "a\n```json\n{}\n```\nb\n"
        let m = map(text).shifted(after: 1, by: 3)   // inserted "xyz" at offset 1
        #expect(m.blocks[0].fenceOpen.location == 5)
        #expect(m.blocks[0].fenceClose?.location == 16)
    }

    @Test func shiftedGrowsBlockWhenEditInsideBody() {
        let text = "```json\n{}\n```\n"
        let m = map(text).shifted(after: 9, by: 5)
        #expect(m.blocks[0].body == NSRange(location: 8, length: 8))
        #expect(m.blocks[0].fenceClose?.location == 16)
    }

    @Test func fenceIntersects() {
        let text = "a\n```json\n{}\n```\nb\n"
        let m = map(text)
        #expect(m.fenceIntersects(NSRange(location: 3, length: 0)))
        #expect(!m.fenceIntersects(NSRange(location: 11, length: 1)))
        #expect(m.fenceIntersects(NSRange(location: 14, length: 2)))
    }

    @Test func blocksIntersectingUsesBinarySearch() {
        var text = ""
        for i in 0..<500 { text += "```\n\(i)\n```\n" }
        let m = map(text)
        #expect(m.blocks.count == 500)
        let last = m.blocks[499]
        #expect(m.blocks(intersecting: NSRange(location: last.body.location, length: 1)).count == 1)
        #expect(m.block(containing: last.body.location)?.whole == last.whole)
        #expect(m.block(containing: (text as NSString).length) == nil)
    }
}
