#!/usr/bin/env -S scala-cli --power shebang
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

```scala mdoc
//> using options -experimental

import scala.util.TupledFunction

extension [F, Args <: Tuple, R](f: F)
    def tupled(using tf: TupledFunction[F, Args => R]): Args => R = tf.tupled(f)
```

```scala mdoc
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

```scala mdoc
import cats.*
import cats.data.*
import cats.syntax.all.*
import org.scalacheck.{Arbitrary, Prop, Shrink}
```

```scala mdoc
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
```

```scala mdoc
case class PositivePair private(a: Int, b: Int)

object PositivePair:
    def apply(a: Int, b: Int): Validated[String, PositivePair] =
        (
            Either.cond(a > 0, a, "a must be positive").toValidated,
            Either.cond(b > 0, b, "b must be positive").toValidated,
        ).mapN(new PositivePair(_, _))


given Arbitrary[PositivePair] = Genie.arbitrary(PositivePair.apply.tupled)
given Shrink[PositivePair]    = Genie.shrink(PositivePair.apply.tupled, Tuple.fromProductTyped)


Prop
    .forAll: (p: PositivePair) =>
        p.a < 10 || p.b < 1000
    .check()
```

```scala mdoc
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
```

## Meta

This readme was generated from [readme.scala.md](readme.scala.md?plain=1).

Make it executable with `chmod +x readme.scala.md` and run it: `./readme.scala.md`.

```scala mdoc:invisible raw
//> using jvm 22
//> using scala 3.5.0
//> using mainClass Main

//> using options -deprecation -feature -language:strictEquality
//> using options -Xmax-inlines:64 -Xkind-projector:underscores
//> using options -Yexplicit-nulls -Ysafe-init-global
//> using options -Wsafe-init -Wnonunit-statement -Wshadow:all

//> using dep org.scalameta::mdoc:2.5.4
```

```scala mdoc:invisible raw
import scala.util.{Try, Success, Failure, Using}
import scala.io.Source
import java.io.PrintWriter


object Main:
   
    def main(args: Array[String]): Unit =
        val classpath  = System.getProperty("java.class.path")
        val inputFile  = "readme.scala.md"
        val outputFile = inputFile.replace(".scala.md", ".md")
        
        val mdocArgs = List(
            "--classpath", classpath,
            "--in", inputFile,
            "--out", outputFile,
            "--scalac-options", "-experimental -Xkind-projector:underscores",
        )
        val settings = mdoc.MainSettings().withArgs(args.toList ++ mdocArgs)
        
        val program =
            for
                _ <- mdoc.Main.process(settings) match
                         case 0        => Success(())
                         case exitCode => Failure(new RuntimeException(s"mdoc failed with exit code $exitCode"))
                _ <- trimShebang(outputFile)
            yield ()
        
        val exitCode = program.fold(_failure => 1, _success => 0)
        sys.exit(exitCode)
    
    
    def trimShebang(filePath: String): Try[Unit] =
        Using.Manager: use =>
            val lines  = use(Source.fromFile(filePath)).getLines().toList
            val writer = use(new PrintWriter(filePath))
            
            lines.dropWhile(_.startsWith("#!")).foreach(writer.println)
```
