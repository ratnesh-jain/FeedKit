//
// FaultTolerantDecodingTests.swift
//
// Copyright (c) 2016 - 2026 Nuno Dias
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

@testable import FeedKit
import Foundation
import Testing
import XMLKit

@Suite("Fault-Tolerant Decoding")
struct FaultTolerantDecodingTests: FeedKitTestable {

  // MARK: - RSS

  @Test
  func rssDecodesAllItemsInFaultTolerantMode() throws {
    // Given: RSS feed with valid items and an item with weird data.
    // RSSFeedItem uses decodeIfPresent for all fields, so malformed
    // elements simply result in nil fields rather than decode failures.
    let xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <rss version="2.0">
        <channel>
          <title>Test Feed</title>
          <item>
            <title>Valid Item</title>
            <link>http://example.com/1</link>
          </item>
          <item>
            <title>Item With Weird Category</title>
            <category>
              <category>Nested</category>
            </category>
          </item>
          <item>
            <title>Another Valid Item</title>
            <link>http://example.com/3</link>
          </item>
        </channel>
      </rss>
      """.data(using: .utf8)!

    // When: faultTolerant mode is used
    let feed = try RSSFeed(data: xml, faultTolerant: true)

    // Then: all items decode (weird data just becomes nil fields)
    let items = try #require(feed.channel?.items)
    #expect(items.count == 3)
    #expect(items[0].title == "Valid Item")
    #expect(items[1].title == "Item With Weird Category")
    #expect(items[2].title == "Another Valid Item")
  }

  @Test
  func rssDecodesAllItemsInStrictMode() throws {
    // Given: RSS feed with items. Because RSSFeedItem uses decodeIfPresent
    // for all fields, the decoder never throws on bad data.
    let xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <rss version="2.0">
        <channel>
          <title>Test Feed</title>
          <item>
            <title>Item 1</title>
            <link>http://example.com/1</link>
          </item>
          <item>
            <title>Item 2</title>
            <link>http://example.com/2</link>
          </item>
        </channel>
      </rss>
      """.data(using: .utf8)!

    // When
    let feed = try RSSFeed(data: xml)

    // Then: all items are present
    let items = try #require(feed.channel?.items)
    #expect(items.count == 2)
    #expect(items[0].title == "Item 1")
    #expect(items[1].title == "Item 2")
  }

  // MARK: - Atom

  @Test
  func atomDecodesValidEntriesInFaultTolerantMode() throws {
    // Given: Atom feed with valid entries and an entry with weird data.
    // AtomFeedEntry uses decodeIfPresent for all fields, but when the key
    // exists with corrupt data, decodeIfPresent throws. In fault-tolerant
    // mode, the unkeyed container catches this and skips the bad entry.
    let xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <feed xmlns="http://www.w3.org/2005/Atom">
        <title>Test Atom Feed</title>
        <entry>
          <title>Valid Entry</title>
          <id>urn:uuid:1</id>
          <updated>2024-01-01T00:00:00Z</updated>
        </entry>
        <entry>
          <title>Entry With Weird ID</title>
          <id>
            <id>Nested ID - fails to decode</id>
          </id>
          <updated>2024-01-02T00:00:00Z</updated>
        </entry>
        <entry>
          <title>Another Valid Entry</title>
          <id>urn:uuid:3</id>
          <updated>2024-01-03T00:00:00Z</updated>
        </entry>
      </feed>
      """.data(using: .utf8)!

    // When: faultTolerant mode is used
    let feed = try AtomFeed(data: xml, faultTolerant: true)

    // Then: all entries are decoded; corrupt field becomes nil
    let entries = try #require(feed.entries)
    #expect(entries.count == 3)
    #expect(entries[0].title == "Valid Entry")
    #expect(entries[0].id == "urn:uuid:1")
    #expect(entries[1].title == "Entry With Weird ID")
    #expect(entries[1].id == nil)
    #expect(entries[2].title == "Another Valid Entry")
    #expect(entries[2].id == "urn:uuid:3")
  }

  @Test
  func atomDecodesAllEntriesInStrictMode() throws {
    // Given: Atom feed with valid entries
    let xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <feed xmlns="http://www.w3.org/2005/Atom">
        <title>Test Atom Feed</title>
        <entry>
          <title>Entry 1</title>
          <id>urn:uuid:1</id>
          <updated>2024-01-01T00:00:00Z</updated>
        </entry>
        <entry>
          <title>Entry 2</title>
          <id>urn:uuid:2</id>
          <updated>2024-01-02T00:00:00Z</updated>
        </entry>
      </feed>
      """.data(using: .utf8)!

    // When
    let feed = try AtomFeed(data: xml)

    // Then: all entries are present
    let entries = try #require(feed.entries)
    #expect(entries.count == 2)
    #expect(entries[0].title == "Entry 1")
    #expect(entries[1].title == "Entry 2")
  }

  // MARK: - JSON Feed

  @Test
  func jsonFeedFaultTolerantSkipsBadItem() throws {
    // Given: JSON feed with a valid item and an item with no "id" field
    // (JSONFeedItem requires id via decode(), so this will fail)
    let json = """
      {
        "version": "https://jsonfeed.org/version/1",
        "title": "Test Feed",
        "items": [
          {
            "id": "item-1",
            "title": "Valid Item",
            "content_text": "Hello from item 1"
          },
          {
            "title": "Bad Item - no id",
            "content_text": "This item is missing its id"
          },
          {
            "id": "item-3",
            "title": "Another Valid Item",
            "content_text": "Hello from item 3"
          }
        ]
      }
      """.data(using: .utf8)!

    // When: faultTolerant mode skips the bad item
    let feed = try JSONFeed(data: json, faultTolerant: true)

    // Then: only valid items are returned
    let items = try #require(feed.items)
    #expect(items.count == 2)
    #expect(items[0].id == "item-1")
    #expect(items[0].title == "Valid Item")
    #expect(items[1].id == "item-3")
    #expect(items[1].title == "Another Valid Item")
  }

  @Test
  func jsonFeedStrictModeFailsOnBadItem() throws {
    // Given: JSON feed with a bad item (missing required id)
    let json = """
      {
        "version": "https://jsonfeed.org/version/1",
        "title": "Test Feed",
        "items": [
          {
            "title": "Bad Item - no id",
            "content_text": "This item is missing its id"
          }
        ]
      }
      """.data(using: .utf8)!

    // When/Then: strict mode throws
    #expect(throws: DecodingError.self) {
      try JSONFeed(data: json)
    }
  }

  @Test
  func jsonFeedAllValidItemsDecodedInFaultTolerantMode() throws {
    // Given: JSON feed where all items are valid
    let json = """
      {
        "version": "https://jsonfeed.org/version/1",
        "title": "Test Feed",
        "items": [
          {
            "id": "item-1",
            "title": "Item 1"
          },
          {
            "id": "item-2",
            "title": "Item 2"
          }
        ]
      }
      """.data(using: .utf8)!

    // When
    let feed = try JSONFeed(data: json, faultTolerant: true)

    // Then: all items are present
    let items = try #require(feed.items)
    #expect(items.count == 2)
    #expect(items[0].id == "item-1")
    #expect(items[1].id == "item-2")
  }

  // MARK: - Feed (auto-detect)

  @Test
  func feedFaultTolerantAutoDetect() throws {
    // Given: JSON feed with a bad item
    let json = """
      {
        "version": "https://jsonfeed.org/version/1",
        "title": "Test Feed",
        "items": [
          {
            "id": "item-1",
            "title": "Valid Item"
          },
          {
            "title": "Bad Item"
          }
        ]
      }
      """.data(using: .utf8)!

    // When
    let feed = try Feed(data: json, faultTolerant: true)

    // Then: feed is decoded with only valid items
    let jsonFeed = try #require(feed.json)
    let items = try #require(jsonFeed.items)
    #expect(items.count == 1)
    #expect(items[0].id == "item-1")
  }
}

@Suite("Fault-Tolerant Entry Points")
struct FaultTolerantEntryPointsTests: FeedKitTestable {

  private var rssWithNestedCategory: String {
    """
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0">
      <channel>
        <title>Test Feed</title>
        <item>
          <title>Item 1</title>
        </item>
        <item>
          <title>Item With Weird Category</title>
          <category>
            <category>Nested</category>
          </category>
        </item>
        <item>
          <title>Item 3</title>
        </item>
      </channel>
    </rss>
    """
  }

  @Test
  func stringFaultTolerant() throws {
    // When
    let feed = try Feed(string: rssWithNestedCategory, faultTolerant: true)

    // Then: all items decode, weird data becomes nil fields
    let rss = try #require(feed.rss)
    let items = try #require(rss.channel?.items)
    #expect(items.count == 3)
    #expect(items[0].title == "Item 1")
    #expect(items[1].title == "Item With Weird Category")
    #expect(items[2].title == "Item 3")
  }

  @Test
  func concreteFeedStringFaultTolerant() throws {
    // When: RSSFeed also gains the faultTolerant string initializer
    let feed = try RSSFeed(string: rssWithNestedCategory, faultTolerant: true)

    // Then
    let items = try #require(feed.channel?.items)
    #expect(items.count == 3)
  }

  @Test
  func fileURLFaultTolerant() throws {
    // Given: a local file containing an RSS feed with weird data
    let fileURL = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("xml")
    try rssWithNestedCategory.data(using: .utf8)!.write(to: fileURL)
    defer { try? FileManager.default.removeItem(at: fileURL) }

    // When
    let feed = try Feed(fileURL: fileURL, faultTolerant: true)

    // Then: all items decode
    let rss = try #require(feed.rss)
    let items = try #require(rss.channel?.items)
    #expect(items.count == 3)
  }

  @Test
  func urlFaultTolerantLocalFile() async throws {
    // Given: a local file URL pointing to an RSS feed with weird data
    let fileURL = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("xml")
    try rssWithNestedCategory.data(using: .utf8)!.write(to: fileURL)
    defer { try? FileManager.default.removeItem(at: fileURL) }

    // When: Feed(url:faultTolerant:) detects the file URL
    let feed = try await Feed(url: fileURL, faultTolerant: true)

    // Then
    let rss = try #require(feed.rss)
    let items = try #require(rss.channel?.items)
    #expect(items.count == 3)
  }

  @Test
  func urlStringFaultTolerantLocalFile() async throws {
    // Given: a local file path string pointing to an RSS feed with weird data
    let fileURL = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("xml")
    try rssWithNestedCategory.data(using: .utf8)!.write(to: fileURL)
    defer { try? FileManager.default.removeItem(at: fileURL) }

    // When
    let feed = try await Feed(urlString: fileURL.absoluteString, faultTolerant: true)

    // Then
    let rss = try #require(feed.rss)
    let items = try #require(rss.channel?.items)
    #expect(items.count == 3)
  }
}

// MARK: - XMLDecoder Fault-Tolerant Tests

@Suite("XMLDecoder Fault-Tolerant")
struct XMLDecoderFaultTolerantTests {

  // MARK: - Helper Types

  /// A strict type with a required field for testing decoder-level fault tolerance.
  struct StrictItem: Decodable, Equatable {
    let id: String
    let name: String
  }

  /// Container uses `item` key (matching the XML sibling element name).
  struct StrictItemContainer: Decodable {
    let item: [StrictItem]?
  }

  // MARK: - Tests

  @Test
  func decoderSkipsBadArrayItems() throws {
    // Given: XML with sibling items, some with valid data and one with
    // an empty <id/> element (no text), which fails to decode as String.
    // Items are siblings under <root> matching the `item` coding key.
    let xml = """
      <root>
        <item>
          <id>item-1</id>
          <name>Valid Item</name>
        </item>
        <item>
          <id/>
          <name>Bad Item - empty id</name>
        </item>
        <item>
          <id>item-3</id>
          <name>Another Valid Item</name>
        </item>
      </root>
      """.data(using: .utf8)!

    let decoder: XMLDecoder = .init()
    decoder.faultTolerant = true

    // When
    let result = try decoder.decode(StrictItemContainer.self, from: xml)

    // Then: only valid items are returned
    let items = try #require(result.item)
    #expect(items.count == 2)
    #expect(items[0].id == "item-1")
    #expect(items[0].name == "Valid Item")
    #expect(items[1].id == "item-3")
    #expect(items[1].name == "Another Valid Item")
  }

  @Test
  func decoderStrictModeFailsOnBadItem() throws {
    // Given: XML with a bad item (empty id, no text)
    let xml = """
      <root>
        <item>
          <id/>
          <name>Bad Item</name>
        </item>
      </root>
      """.data(using: .utf8)!

    let decoder: XMLDecoder = .init()

    // When/Then: strict mode throws
    #expect(throws: DecodingError.self) {
      try decoder.decode(StrictItemContainer.self, from: xml)
    }
  }

  @Test
  func decoderAllValidItemsDecoded() throws {
    // Given: XML where all items are valid
    let xml = """
      <root>
        <item>
          <id>item-1</id>
          <name>Item 1</name>
        </item>
        <item>
          <id>item-2</id>
          <name>Item 2</name>
        </item>
      </root>
      """.data(using: .utf8)!

    let decoder: XMLDecoder = .init()
    decoder.faultTolerant = true

    // When
    let result = try decoder.decode(StrictItemContainer.self, from: xml)

    // Then: all items are present
    let items = try #require(result.item)
    #expect(items.count == 2)
    #expect(items[0].id == "item-1")
    #expect(items[1].id == "item-2")
  }

  @Test
  func decoderNilItemsWhenAllAreBad() throws {
    // Given: XML where all items are bad (empty id elements)
    let xml = """
      <root>
        <item>
          <id/>
          <name>Bad Item 1</name>
        </item>
        <item>
          <id/>
          <name>Bad Item 2</name>
        </item>
      </root>
      """.data(using: .utf8)!

    let decoder: XMLDecoder = .init()
    decoder.faultTolerant = true

    // When
    let result = try decoder.decode(StrictItemContainer.self, from: xml)

    // Then: item is nil (all were bad, none decoded)
    #expect(result.item == nil)
  }
}
