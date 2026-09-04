import Checkpoint
import Coder
import Parser
import Serializer
import Signature_Derivation
import Testing

private enum Spike {
    @Signature
    protocol `Protocol` {
        func create(value: Int) -> Int
        func read(value: Int) -> Int
        func update(value: Int) -> Int
        func delete(value: Int) -> Int
        func list(value: Int) -> Int
        func search(value: Int) -> Int
        func count(value: Int) -> Int
        func head(value: Int) -> Int
        func patch(value: Int) -> Int
        func replace(value: Int) -> Int
        func archive(value: Int) -> Int
        func restore(value: Int) -> Int
        func publish(value: Int) -> Int
        func unpublish(value: Int) -> Int
        func tag(value: Int) -> Int
        func untag(value: Int) -> Int
    }
}

private struct Record: Equatable, Restorable {
    typealias Checkpoint = Record

    var path: [String]
    var body: Int?
}

private enum Mismatch: Swift.Error, Equatable {
    case absent
    case malformed
}

private struct Segment<Index: Operation.Symbol>: Coding where Index.Input == Int {
    typealias Input = Record
    typealias Output = Operation.Application<Index>
    typealias Buffer = Record
    typealias Failure = Mismatch

    let name: String

    borrowing func parse(_ input: inout Record) throws(Mismatch) -> Operation.Application<Index> {
        guard input.path.first == name else { throw .absent }
        guard let value = input.body else { throw .malformed }
        input.path.removeFirst()
        input.body = nil
        return .init(value)
    }

    borrowing func serialize(
        _ output: borrowing Operation.Application<Index>,
        into buffer: inout Record
    ) throws(Mismatch) {
        buffer.path.append(name)
        buffer.body = output.input
    }
}

@Suite
private struct `Router Tests` {
    @Test
    func `a derived labelled product router routes all sixteen cases both ways`() throws {
        let router = Spike.Call.Router(
            absent: Mismatch.absent,
            create: Segment<Spike.Operations.Create>(name: "create"),
            read: Segment<Spike.Operations.Read>(name: "read"),
            update: Segment<Spike.Operations.Update>(name: "update"),
            delete: Segment<Spike.Operations.Delete>(name: "delete"),
            list: Segment<Spike.Operations.List>(name: "list"),
            search: Segment<Spike.Operations.Search>(name: "search"),
            count: Segment<Spike.Operations.Count>(name: "count"),
            head: Segment<Spike.Operations.Head>(name: "head"),
            patch: Segment<Spike.Operations.Patch>(name: "patch"),
            replace: Segment<Spike.Operations.Replace>(name: "replace"),
            archive: Segment<Spike.Operations.Archive>(name: "archive"),
            restore: Segment<Spike.Operations.Restore>(name: "restore"),
            publish: Segment<Spike.Operations.Publish>(name: "publish"),
            unpublish: Segment<Spike.Operations.Unpublish>(name: "unpublish"),
            tag: Segment<Spike.Operations.Tag>(name: "tag"),
            untag: Segment<Spike.Operations.Untag>(name: "untag")
        )

        let label = Spike.Call.Eliminator<String>(
            create: { _ in "create" },
            read: { _ in "read" },
            update: { _ in "update" },
            delete: { _ in "delete" },
            list: { _ in "list" },
            search: { _ in "search" },
            count: { _ in "count" },
            head: { _ in "head" },
            patch: { _ in "patch" },
            replace: { _ in "replace" },
            archive: { _ in "archive" },
            restore: { _ in "restore" },
            publish: { _ in "publish" },
            unpublish: { _ in "unpublish" },
            tag: { _ in "tag" },
            untag: { _ in "untag" }
        )

        let value = Spike.Call.Eliminator<Int>(
            create: { $0.input },
            read: { $0.input },
            update: { $0.input },
            delete: { $0.input },
            list: { $0.input },
            search: { $0.input },
            count: { $0.input },
            head: { $0.input },
            patch: { $0.input },
            replace: { $0.input },
            archive: { $0.input },
            restore: { $0.input },
            publish: { $0.input },
            unpublish: { $0.input },
            tag: { $0.input },
            untag: { $0.input }
        )

        let routes: [(name: String, value: Int, call: Spike.Call)] = [
            ("create", 1, .create(value: 1)),
            ("read", 2, .read(value: 2)),
            ("update", 3, .update(value: 3)),
            ("delete", 4, .delete(value: 4)),
            ("list", 5, .list(value: 5)),
            ("search", 6, .search(value: 6)),
            ("count", 7, .count(value: 7)),
            ("head", 8, .head(value: 8)),
            ("patch", 9, .patch(value: 9)),
            ("replace", 10, .replace(value: 10)),
            ("archive", 11, .archive(value: 11)),
            ("restore", 12, .restore(value: 12)),
            ("publish", 13, .publish(value: 13)),
            ("unpublish", 14, .unpublish(value: 14)),
            ("tag", 15, .tag(value: 15)),
            ("untag", 16, .untag(value: 16)),
        ]

        for route in routes {
            var buffer = Record(path: [], body: nil)
            try router.serialize(route.call, into: &buffer)
            #expect(buffer == Record(path: [route.name], body: route.value))

            var input = buffer
            let parsed = try router.parse(&input)
            #expect(label(parsed) == route.name)
            #expect(value(parsed) == route.value)
            #expect(input == Record(path: [], body: nil))
        }
    }
}
