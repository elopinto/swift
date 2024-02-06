//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

/// Creates a sequence of tuples built out of multiple underlying sequences.
///
/// In the `ZipMultiSequence` instance returned by this function, the
/// elements of the *i*th tuple are the *i*th elements of each underlying
/// sequence. The following example uses the `zip(sequences:)` function to
/// iterate over an array of doubles, a countable range, and a string at the
/// same time:
///
///     let word = "four"
///     let integers = 1...4
///     let doubles = [1.0, 2.0, 3.0, 4.0]
///
///     for (char, int, double) in zip(sequences: word, integers, doubles) {
///         print("\(char) - \(double) - \(int)")
///     }
///     // Prints "f - 1.0 - 1"
///     // Prints "o - 2.0 - 2"
///     // Prints "u - 3.0 - 3"
///     // Prints "r - 4.0 - 4"
///
/// If the sequences passed to `zip(sequences:)` are different lengths, the
/// resulting sequence is the same length as the shortest sequence. In this
/// example, the resulting array is the same length as `words`:
///
///     let words = ["one", "two", "three", "four"]
///     let naturalNumbers = 1...Int.max
///     let zipped = Array(zip(sequences: words, naturalNumbers))
///     // zipped == [("one", 1), ("two", 2), ("three", 3), ("four", 4)]
///
/// - Parameter sequence: A comma-separated list of sequences to zip.
/// - Returns: A sequence of tuples, where the elements of each tuple are
///   corresponding elements of the input sequences.
@available(SwiftStdlib 9999, *)
@inlinable
public func zip<each Chain: Sequence>(
  sequences chain: repeat each Chain
) -> ZipMultiSequence<repeat each Chain> {
  return ZipMultiSequence((repeat each chain))
}

/// A sequence of tuples generated from multiple underlying sequences.
///
/// In a `ZipMultiSequence` the *i*th item is a tuple containing the
/// *i*th element of each input sequence. A `ZipMultiSequence` can
/// be made from any number of input sequences of any type.
///
/// Use the `zip(sequences:)` function to create a `ZipMultiSequence`
/// instance.
@available(SwiftStdlib 9999, *)
@frozen
public struct ZipMultiSequence<each Chain: Sequence>: Sequence {

  /// A value pack containing the input sequences, or "chains of the zipper".
  @usableFromInline
  internal let _chain: (repeat each Chain)

  /// Creates an instance of `ZipMultiSequence` from a tuple of zero or more
  /// sequences.
  /// - Parameter chain: A tuple of zero or more sequences.
  @inlinable
  internal init(_ chain: (repeat each Chain)) {
    self._chain = chain
  }

  /// Return an iterator for this sequence.
  @inlinable
  public __consuming func makeIterator() -> Iterator {
    return Iterator(
      iterator: (repeat AnyIterator((each _chain).makeIterator()))
    )
  }

  /// The value of the shortest input sequence.
  @inlinable
  public var underestimatedCount: Int {
    var underestimatedCounts: [Int] = []
    (repeat underestimatedCounts.append((each _chain).underestimatedCount))
    return underestimatedCounts.min() ?? 0
  }
}

@available(SwiftStdlib 9999, *)
extension ZipMultiSequence {

  /// An iterator for `ZipMultiSequence`.
  @available(SwiftStdlib 9999, *)
  @frozen
  public struct Iterator: IteratorProtocol {

    // When attempting to call to call `next()` on the input iterators during
    // value pack expansion, the compiler complains that an attempt is being
    // made to mutate an immutable value. However, `next()` can be called
    // after type-erasing them to `AnyIterator`.
    /// A value pack holding the iterators of the underlying sequences of a
    /// `ZipMultiSequence`.
    @usableFromInline
    internal let _chainIterator: (repeat AnyIterator<(each Chain).Element>)

    /// Set to true when the first underlying sequence finishes iterating.
    @usableFromInline
    internal var _reachedEnd = false

    /// Creates an instance of an interator for a `ZipMultiSequence`.
    /// - Parameter iterator: A tuple of zero or more type-erased iterators from
    /// a `ZipMultiSequence`'s underlying sequences.
    @inlinable
    internal init(iterator: (repeat AnyIterator<(each Chain).Element>)) {
      self._chainIterator = iterator
    }

    /// Returns the next element in the sequence or `nil` when there are no
    /// no more elements.
    ///
    /// This method will return `nil` as soon as one of the underlying
    /// iterators returns `nil`.
    /// - Returns: A tuple containing an item from each underlying iterator or
    /// `nil` when iteration ends.
    @inlinable
    public mutating func next() -> (repeat (each Chain).Element)? {
      // `ZipMultiSequence` stops iterating when the shortest underlying
      // sequence has reached its end. We check here if the sequence has
      // reached the end to prevent elements of longer underlying sequences from
      // being consumed with additional calls to `next()`.
      guard !_reachedEnd else { return nil }

      do {
        // Error handling is used in place of `if-let` or `guard-let`
        // because we have to perform the check in in a pack expansion pattern.
        return (repeat try _someOrThrow((each _chainIterator).next()))
      } catch {
        _reachedEnd = true
        return nil
      }
    }
  }
}

@available(SwiftStdlib 9999, *)
extension ZipMultiSequence.Iterator {
  @frozen
  @usableFromInline
  internal struct _NextIsNil: Error {
    @inlinable internal init() {}
  }

  /// Return the wrapped value or throw an error if it is `nil`.
  ///
  /// This method allows you to use `try-catch` instead of `if-let` or
  /// `guard-let` as Optional-handling control flow.
  ///
  /// - Returns: The wrapped value.
  /// - Throws: A `_NextIsNil`error if `self` is `nil`.
  @inlinable
  internal func _someOrThrow<Wrapped>(
    _ wrapped: Wrapped?
  ) throws -> Wrapped {
    guard let wrapped else { throw _NextIsNil() }
    return wrapped
  }
}


@available(SwiftStdlib 9999, *)
extension ZipMultiSequence: Sendable where repeat each Chain: Sendable {}

// warning: stored property '_chainIterator' of 'Sendable'-conforming struct
// 'Iterator' has non-sendable type '(repeat AnyIterator<(each Chain).Element>)'
// Possible solutions: Make AnyIterator conform to Sendable? Find way to mutate
// iterators in value packs?
// @available(SwiftStdlib 9999, *)
// extension ZipMultiSequence.Iterator: Sendable
//  where repeat each Chain: Sendable, repeat (each Chain).Iterator: Sendable {}
