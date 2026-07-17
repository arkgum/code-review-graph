import XCTest
@testable import LimitlessKit

final class LifelogDecodingTests: XCTestCase {
    private func decode(_ json: String) throws -> LifelogsResponse {
        try LimitlessClient.decoder.decode(LifelogsResponse.self, from: Data(json.utf8))
    }

    func testDecodesFullResponse() throws {
        let json = """
        {
          "data": {
            "lifelogs": [
              {
                "id": "abc123",
                "title": "Morning standup",
                "markdown": "# Morning standup\\n- discussed roadmap",
                "startTime": "2026-07-17T09:00:00.000Z",
                "endTime": "2026-07-17T09:15:30.000Z",
                "isStarred": true,
                "updatedAt": "2026-07-17T09:16:00.000Z",
                "contents": [
                  {
                    "type": "heading1",
                    "content": "Morning standup",
                    "startOffsetMs": 0,
                    "endOffsetMs": 1200,
                    "children": [
                      {
                        "type": "blockquote",
                        "content": "Let's discuss the roadmap.",
                        "speakerName": "Alex",
                        "speakerIdentifier": "user",
                        "startOffsetMs": 1200,
                        "endOffsetMs": 4000
                      }
                    ]
                  }
                ]
              }
            ]
          },
          "meta": { "lifelogs": { "nextCursor": "cursor-2", "count": 1 } }
        }
        """
        let response = try decode(json)
        XCTAssertEqual(response.lifelogs.count, 1)
        XCTAssertEqual(response.nextCursor, "cursor-2")

        let log = try XCTUnwrap(response.lifelogs.first)
        XCTAssertEqual(log.id, "abc123")
        XCTAssertEqual(log.title, "Morning standup")
        XCTAssertTrue(log.isStarred)
        XCTAssertNotNil(log.updatedAt)

        let heading = try XCTUnwrap(log.contents.first)
        XCTAssertEqual(heading.type, "heading1")
        XCTAssertEqual(heading.children.count, 1)
        XCTAssertEqual(heading.children.first?.speakerName, "Alex")
        XCTAssertEqual(heading.children.first?.speakerIdentifier, "user")
    }

    func testDecodesTimestampsWithoutFractionalSeconds() throws {
        let json = """
        {
          "data": { "lifelogs": [
            { "id": "x", "title": "t", "startTime": "2026-07-17T09:00:00Z" }
          ] },
          "meta": { "lifelogs": { "nextCursor": null } }
        }
        """
        let response = try decode(json)
        XCTAssertNotNil(response.lifelogs.first?.startTime)
        XCTAssertNil(response.nextCursor)
    }

    func testToleratesMissingOptionalFields() throws {
        let json = """
        {
          "data": { "lifelogs": [ { "id": "y", "title": "only required" } ] },
          "meta": { "lifelogs": {} }
        }
        """
        let response = try decode(json)
        let log = try XCTUnwrap(response.lifelogs.first)
        XCTAssertEqual(log.id, "y")
        XCTAssertNil(log.markdown)
        XCTAssertFalse(log.isStarred)
        XCTAssertTrue(log.contents.isEmpty)
        XCTAssertNil(response.nextCursor)
    }
}
