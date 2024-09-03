# Genie

**Table of Contents**

- [About](#about)
- [Implementation](#implementation)
- [Usage](#usage)
- [Meta](#meta)

## About

Genie conjures ScalaCheck `Arbitrary` and `Shrink` instances for your domain objects based on their smart constructors.

Inspired by Haskell's Validity.

## Implementation

<details>
<summary>Source code</summary>

```scala
//> using options -experimental

import scala.util.TupledFunction

extension [F, Args <: Tuple, R](f: F)
    def tupled(using tf: TupledFunction[F, Args => R]): Args => R = tf.tupled(f)
```

```scala
//> using dep org.typelevel::cats-core:2.12.0
//> using dep org.scalacheck::scalacheck:1.18.0

import cats.data.Validated
import org.scalacheck.{Arbitrary, Gen, Shrink}


given Arbitrary[EmptyTuple] =
    Arbitrary(Gen.const(EmptyTuple))

given [H, T <: Tuple](using head: Arbitrary[H], tail: Arbitrary[T]): Arbitrary[H *: T] =
    Arbitrary(Gen.zip(head.arbitrary, tail.arbitrary).map(_ *: _))


trait Valid[F[_], VALUE]:
    extension (x: F[VALUE])
        def isValid:  Boolean
        def toOption: Option[VALUE]

given [VALUE]: Valid[Option, VALUE] with
    extension (x: Option[VALUE])
        def isValid:  Boolean       = x.isDefined
        def toOption: Option[VALUE] = x

given [VALUE, ERROR]: Valid[Either[ERROR, _], VALUE] with
    extension (x: Either[ERROR, VALUE])
        def isValid:  Boolean       = x.isRight
        def toOption: Option[VALUE] = x.toOption

given [VALUE, ERROR]: Valid[Validated[ERROR, _], VALUE] with
    extension (x: Validated[ERROR, VALUE])
        def isValid:  Boolean       = x.isValid
        def toOption: Option[VALUE] = x.toOption


object Genie:
    
    def arbitrary[I <: Tuple : Arbitrary, F[_], O](apply: I => F[O])(using Valid[F, O]): Arbitrary[O] =
        val input:  Gen[I] = summon[Arbitrary[I]].arbitrary
        val output: Gen[O] = input.map(apply).retryUntil(_.isValid).map(_.toOption.get)
            
        Arbitrary(output)
    
    
    def shrink[I <: Tuple : Shrink, F[_], O](apply: I => F[O], unapply: O => I)(using Valid[F, O]): Shrink[O] =
        val input:  Shrink[I] = summon[Shrink[I]]
        val output: Shrink[O] = Shrink(o => input.shrink(unapply(o)).map(apply).filter(_.isValid).map(_.toOption.get))

        output
```

</details>

## Usage

```scala
import cats.*
import cats.data.*
import cats.syntax.all.*
import org.scalacheck.{Arbitrary, Prop, Shrink}
```

```scala
def isPrime(n: Int): Boolean = 
    if      n < 2                    then false
    else if n == 2 || n == 3         then true
    else if n % 2 == 0 || n % 3 == 0 then false
    else
        (5 to Math.sqrt(n.toDouble).toInt by 6).forall: x =>
            n % x != 0 && n % (x + 2) != 0


case class Prime private(value: Int)

object Prime:
    def apply(n: Int): Option[Prime] =
        Option.when(isPrime(n))(new Prime(n))


given Arbitrary[Prime] = Genie.arbitrary(Prime.apply.tupled)
given Shrink[Prime]    = Genie.shrink(Prime.apply.tupled, Tuple.fromProductTyped)


Prop
    .forAll: (n: Prime) =>
        isPrime(n.value)
    .check()
// + OK, passed 100 tests.
```

```scala
case class PositivePair private(a: Int, b: Int)

object PositivePair:
    def apply(a: Int, b: Int): Validated[String, PositivePair] =
        (
            Either.cond(a > 0, a, "a must be positive").toValidated,
            Either.cond(b > 0, b, "b must be positive").toValidated,
        ).mapN: (a, b) =>
            new PositivePair(a, b)


given Arbitrary[PositivePair] = Genie.arbitrary(PositivePair.apply.tupled)
given Shrink[PositivePair]    = Genie.shrink(PositivePair.apply.tupled, Tuple.fromProductTyped)


Prop
    .forAll: (p: PositivePair) =>
        p.a < 10 || p.b < 1000
    .check()
// ! Falsified after 0 passed tests.
// > ARG_0: PositivePair(14,1943)
// > ARG_0_ORIGINAL: PositivePair(991850837,2038365786)
```

```scala
// TODO: Work around type erasure.
case class Flags private(values: List[Boolean])

object Flags:
    def apply(xs: List[Boolean]): Option[Flags] =
        xs match
            case Nil      => None
            case nonempty => Some(new Flags(nonempty))


given Arbitrary[Flags] = Genie.arbitrary(Flags.apply.tupled)
given Shrink[Flags]    = Genie.shrink(Flags.apply.tupled, Tuple.fromProductTyped)


Prop
    .forAll: (flags: Flags) =>
        flags.values.nonEmpty
    .check()
// ! Exception raised on property evaluation.
// > Exception: org.scalacheck.Gen$RetryUntilException: retryUntil failed afte
//   r 10001 attempts
// org.scalacheck.Gen$RetryUntilException$.apply(Gen.scala:290)
// org.scalacheck.Gen.loop$2(Gen.scala:301)
// org.scalacheck.Gen.retryUntil$$anonfun$1(Gen.scala:306)
// org.scalacheck.Gen$Parameters.useInitialSeed(Gen.scala:494)
// org.scalacheck.Gen$$anon$7.doApply(Gen.scala:437)
```

## Meta

This readme was generated from [readme.scala.md](readme.scala.md?plain=1).

Make it executable with `chmod +x readme.scala.md` and run it: `./readme.scala.md`.


