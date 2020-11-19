---
title: Splice Notation for Static Reflection
author: 
  - Andrew Sutton (<asutton@lock3software.com>)
  - Daveed Vandevoorde (<daveed@edg.com>)
date: Oct 15, 2020

geometry:
- left=1in
- right=1in
- top=1in
- bottom=1in
---

--------- --------
 Document D2258R0
 Audience SG7
--------- ---------

# Introduction {#intro}

This paper considers alternative syntax for splice notation for static
reflection. Splicing (previsouly "reification" in P1240) is the inverse of
reflection: it inserts a reference to a reflected entity or expression into a
program [@P1240R1].

For the purpose of brevity, this paper uses the suggested unary `^` operator
as the reflection operator as opposed to `reflexpr`.

The P1240 paper proposal descibes `constexpr`-based support for static
(compile-time) reflection to C++. One of the main components of that proposal
is the ability to insert (or splice) references to reflected entities back
into the program. 

- `typename(refl)` inserts a *type-specifier*.
- `namespace(refl)` inserts a *qualified-namespace-specifier*.
- `exprid(refl)` inserts an *id-expression* referring to a function,
  variable, data member, member function, or bitfield.
- `valueof(refl)` inserts a *constant-expression*.
- `[<refl>]` inserts a *template-argument*.[^more]

[^more]: Lock3's Clang-based implementation spells the template argument splice
`templarg(refl)`. P1240 also includes the splice operator `[:refl:]`, which
we won't consider for this paper, as its intended purpose is quite different
than other splice operators.

For example, `typename(^int)` will generate the *type-id* `int` and
`valueof(^int)` will yield the *constant-expression* 0.

P2237R0 suggests considerably differnt syntax for splicing: there is only one
splice operator, which is to enclose a reflection in `|` tokens [@P2237R0]. For
example, `|^int|` yields the *type-id* `int` and `|^0|` yields the
*constant-expression* 0.

# Design foundations

The design of P1240 is rooted in the idea that the spelling of a splice operator
should indicate the grammar term being inserted into the program. There are a
a number of good reasons to do this:

- The use of keywords is an obvious hint to readers about the kind of term
  being spliced into the program.
- The operator name also provides course-grained requirements on the value of
  the reflection.
- The correspondence between a splice operator's name and its generated syntax
  simplifies the implementation.
- There are no template dependency issues that require different syntax in
  templates, since spliced terms are explicity qualified by their operator.

However, the explicitness of this design can lead to more verbose code:

```cpp
template<meta::info T, meta::info E>
void f(T n) {
  typename(X) var = idexpr(E);
  // ...
}
```

The design in P2237 is primarily motivated by two concerns:

- Minimize the syntactic overhead of splicing by providing a single notation.
- Provide a novel and (initially) unfamiliar beacon that code is being spliced
  into a program.

Using the P2237 notation, the function above is:

```cpp
template<meta::info T, meta::info E>
void f(T n) {
  |X| var = |E|;
  // ...
}
```

This minimal notation makes the programming model decidely script-like since
there are relatively few annotations. The programmer says where reflections will
be spliced into the program, but not what kind of reflections are expected or
what kind of syntax is being generated. The meaning of a splice inferred from
context (by both the compiler and reader). However, unlike dynamically typed
scripting languages, C++ is still strongly typed. Using the wrong reflection or
splice in the wrong context will cause the program to be ill-formed, not
incorrect.

Making notation distinct and unfamiliar is intended to draw the eye, so that
readers better understand that the code should be interepreted differently than
"normal" C++.  Visually, the `|x|` notation is intended to resemble a "gap" in
the flow of the source text, which is filled by the reflection `x`.

# P1240 Evaluation

The splice notation in P1240 are not very visually distinctive. It's easy,
especially for non-experts, to mistake `typename(x)` as being somehow related
to a *typename-specifier*. After all, in many contexts, parentheses are used
only for grouping.

The required use keywords can lead to some unfortunate compositions. For
example:

```cpp
template<typename meta::info x>
void f() {
  typename typename(x)::type var;
}
```

Historically, repetition of keywords is seen as a design failure by the broader
C++ community (even when it is not).

It seems like there should be some contexts in which the extra annotations
can be elided because only a limited subset of terms are allowed. In the
declaration of `var` the spliced term can only be a *nested-name-specifier*
and `x` must reflect a class or namespace. P0634 identified a number of
cases where extra annotations could be elided [@P0634R1].

Note that allowing the ellision of the 2nd `typename` above effectively means
that we would need splice notation: `(x)` is not a viable choice.

# P2237 Evluation

Parsing for P2237's splice notation is interesting but not overly complex
in non-dependent cases. Because the operand is a constant expression, we
can determine the grammatical category of the splice as we parse it.

```cpp
void f() {
  |^int| x = 42; // |^int| is a simple-type-specifier
  |^0|;          // |^0| is an expression
}
```

In cases where multiple productions can start with the same sequence of tokens,
implementations typically produce synthetic tokens containing the fully parsed
and analyzed sequence, effectively caching the parse. For example, GCC and Clang
both do this with *nested-name-specifier*s and *template-id*s. The same
technique would be used here, and we can label the synthetic tokens according to
their computed grammatical category.

Inside templates, the usual rules for adding `typename` and `template` apply.

P2237's use of plain `|`s to delimit splices produces some unfortunate lexing
issues. For example:

```cpp
constexpr meta::info x = ^0;
constexpr meta::info y = ^x;
int z = ||^y||; // error: expected expression
```

In order to parse that as a nested splice (yes, splices can nest), the parser
would have to perform some seriously speculative lexical gymnastics. Similar
(but resolvable) issues arise when the splice appears in juxtoposition to
other `|` tokens such as the proposed pipeline rewrite operator. [@P2011R0]

All other considerations aside, this alone kills the plain `|x|` notation.

# Universal template arguments

FIXME: Write this.

# Suggestion

We probably want something between the distinctive terseness of P2273 and the
specificity of P1240. However, we should try to avoid unnecessary repetition
of keywords, and we should avoid requiring keywords in contexts where they
are not needed.

We suggest the following:

First, adopt `[<` and `>]` as enclosing token pairs for splices.[^tokens] These
are visually distinctive, easily greppable, and don't have weird lexical issues
combining with other tokens. It's tempting to make these distinct tokens, but
doing so could break existing code (e.g., `arr[trait_v<x>]`). We considered
`[|x|]` but were concerned that it was too visually similar to attribute
notation. The `<>`'s also have a nice relationship with the source code
fragments notation in P2237.

Without additional qualification or context, `[<x>]` is an primary expression
that produces an *id-expression* referring to a function, variable, member
function, data member, or bitfield. This is essentially `idexpr` in P1240.
For example:

```cpp
template<meta::info t, // reflects a type T
         meta::info v> // reflects a variable V
void f() {
  cout << [<e>]; // OK: prints the value of V
  [<t>];         // error: T is not an expression
}
```

Note that the error from using `t` occurs during instantiation, not parsing.

Modify the grammar to permit additional uses of the splice notation to produce
different kinds of reflections.

```cpp
template<meta::info t, // reflects a type T
         meta::info x> // reflects a template X
void f() {
  typename [<t>] *p;    // OK: declares a pointer-to-T
  typename [<t>](0, 1); // OK: constructs a T temporary
  [<t>](0, 1);          // error: T is not invocable
  template [<x>]<int> var; // OK: declares var with type X<int>
}
```

In these contexts the splice is not an expression.

FIXME: Add whatever the solution for template arguments is.

# References
