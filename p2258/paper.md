---
title: The Syntax of Static Reflection
author: 
  - Andrew Sutton (<asutton@lock3software.com>)
  - Wyatt Childers (<wchilders@lock3software.com>)
  - Daveed Vandevoorde (<daveed@edg.com>)
date: Oct 15, 2020

geometry:
- left=1in
- right=1in
- top=1in
- bottom=1in

bibliography:
  - ../bib/wg21.bib
---

--------- --------
 Document D2258R0
 Audience SG7
--------- ---------

# Introduction {#intro}

This paper suggests a new syntax for reflection and splicing that differs from
both [@P1240R1] and [@P2237R0]. The syntax in both proposals has various
weaknesses. P1240R1 is largely written using placeholder notation, and while
P2237 offers some concrete improvements, it turns out to have some ambiguity
issues.

We (the authors) considered several notations for the two operations with
respect to several criteria:

- Expressive. The syntax must support a wide array of metaprogramming use
  cases. Broadly, we need syntax to a) inspect the compile-time properties of
  expressions, names, declarations, and entities, b) splice entity references
  and expressions back into source code, and c) expand such splices in contexts
  where pack expansion is allowed.
- Readability. Obviously, we'd like our programs to be readable. We want syntax
  that is both visually distinctive yet comprehensible. Because metaprogramming
  (especially splicing) is a new C++ programming concept, we think it should
  be sufficiently different from existing notations.
- Futureproof. We shouldn't design notation that prevents future extensions. We
  should also consider future extensions to metaprogramming (like code
  injection) so that we don't end up with wildly different notations for
  similar kinds of functionality.
- Unambiguous grammar. The grammar for these terms should be unambiguous, if
  possible (this is C++, not all things are possible).
- Implementability. The notation must be implementable. Syntax (and semantics)
  that cannot be supported by all implementations is not viable.

Section XXX presents the notation we've chosen for reflection and splicing.
Appendix YYY presents other notations and brief analyses.

# Proposal

There are three features of static reflection that require syntax:
reflection (Section [](#refl)), splicing (Section [](#splice.refl)), and
pack expansion (Section [](#splice.pack)).

## Reflection {#refl}

We chose to represent reflection using `^` as a unary operator. Becuase
reflection is such a fundamental (and primitive) operation for metaprogramming,
it should have a simple spelling. The `^` is intended to imply "lifting"
or "raising" a term into the metaprogramming environment.

```cpp
meta::info r1 = ^int;  // reflects the type-id int
meta::info r2 = ^x;    // reflects the id-expression x
meta::info r2 = ^f(x); // reflects the call f(x)
```

The suggested grammar for the reflection is:

:::{.bnf}
- unary-expression
  - ...
  - reflection-expression

- reflection-expression
  - `^` postfix-expression
  - `^` type-id
  - `^` qualified-namespace-specifier
  - `^` qualified-template-specifier
  - `^` `::`
:::

## Splicing reflections {#splice.refl}

We chose the notation `[: R :]` to denote the splice of a reflection `R`. Here,
the use of bracket notation is explicitly chosen to denote a "gap" in the source
code, filled in by the "reflected value" of `R`. The notation is intentionally
designed to be visually distinctive because it represents a new programming
concept for C++. We prefer to encourage a degree of unfamiliarity.

In general, and without qualification, `[: R :]` splices an expression into the
program (assuming `R` reflects a variable, function, or some other expression).
If `R` reflects a type, template, or namespace, the splice operator must be
qualified with an appropriate keyword, except in contexts where the meaning
is obvious. For example:

```cpp
struct S { struct Inner { }; };
template<int N> struct X;

auto refl = ^S;
auto tmpl = ^X;

void f() {
  typename [:refl:] * x;  // OK: declares x to be a pointer-to-S
  [:refl:] * x;           // error: attempt to multiply int by x
  [:refl:]::Inner i;      // OK: splice as part of a nested-name-specifier
  typename [:refl:]{};    // OK: default-constructs an S temporary
  using T = [:refl:];     // OK: operand must be a type
  struct C : [:refl:] {}; // OK: base classes are types
  template [:tmpl:]<0>;   // OK: names the specialization
  [:tmpl:] < 0 > x;       // error: attempt to compare X with 0
}
```

Note that the extra annotations are necessary even in non-dependent contexts.
We expect future proposals to relax the requirement for qualifying syntax when
the splice operand is not value-dependent. For example, most of the statements
above could be written without the extra annotations. We do expect this to
impose additional implementation burdens.

The addition of splicing requires modification of the following grammar terms.

:::{.bnf}
- splice
  - `[:` conditional-expression `:]`
:::

:::{.bnf}
- primary-expression
  - ...
  - `template`~opt~ splice
:::

:::{.bnf}
- postfix-expression
  - ...
  - postfix-expression `.` splice
:::

:::{.bnf}
- nested-name-specifier:
  - ...
  - splice `::`
  - nested-name-specifier `template`~opt~ splice
:::

:::{.bnf}
- typename-specifier:
  - ...
  - typename `template`~opt~ splice
:::

Annotations differentiating type and non-type [template-argument]{.bnf}s in a
[template-argument-list]{.bnf} can be omitted. This is a special case that
allows reflections (and packs thereof) to be forwarded to a template taking
mixed type/value template arguments or to an overload set where the kind and
type of arguments may vary. For example:

```cpp
template<typename T> void f();
template<int N> void f();

template<meta::info Refl>
void g() {
  f<[:Refl:]>();
}
```

Here, `Refl` can reflect either a type or integer constant expression. To 
"force" `Refl` to be spliced as a type, we would write:

```cpp
template<meta::info Refl>
void g() {
  f<typename [:Refl:]>();
}
```

We don't currently offer a way to force `Refl` to be an expression.


## Splicing packs {#splice.pack}

The ability to expand a range of reflections into a list of function arguments,
template arguments, base classes, etc. is an important use case for
metaprogramming. However, the expansion of non-packs is a novel feature and
requires new syntax to nominate a term as being expandable. Our preferred
approach is to require an ellipsis *before* the term being expanded. For
example:

```cpp
using T = std::tuple<int, ...[:range_of_types:]..., bool>;
```

Here, `range_of_types` is a sequence of type reflections. The leading `...`
nominates the splice as expandable, and the trailing `...` explicitly indicates
its expansion.

We propose to allow such nominations in every context where expansion is
allowed (and no others). There are a number of reasons for choosing this
syntax. First, a prefix annotation is necessary to be implementable by all
vendors.[^impl] Second, the choice of `...` is chosen specifically because
of the symmetry with expansion "operator" and the way in which packs are
declared (the `...`precedes the identifier).

[^impl]: Not all implementations preserve tokens during or construct syntax
trees during parsing. The prefix ellipsis in these context would alerts the
compiler that it needs to preserve those tokens for subsequent expansion.

For fold expressions, at most one cast-expression can be nominated as expandable.

```cpp
(...[:range:] && ...)      // Right fold over a splice
(... && ...[:range:])      // Left fold over a splice
(0.0 + ... + ...[:range:]) // Left binary fold over a splice
```

There is a potential redundancy in the notation. It could be argued that a term
nominated for expansion must always be expanded, so we could omit the trailing
ellipsis, and this would be true today. However, this "optimization" is not
applicable in fold expressions and may not be futureproof. In the future, we
might introduce a "pass-by-reflection" convention that accepts unexpanded
parameter packs. For now, we choose to require ellipses for nomination and
expansion.

Semantically, the expansion of such expressions is just like the expansion of
normal template and function parameter packs. Here are some examples:

```cpp
fn(0, 1, ...[:range:]...); // OK: expansion after normal arguments
fn(...[:range:]..., 0, 1); // OK: expansion before normal arguments
fn(...[:range:] * 2...);   // OK: [:range:] * 2 is the pattern
fn(...[:r1:] * [:r2:]...); // OK: iff r1 and r2 have equal size
```

To support this feature, we need to change the following grammar definitions:

:::{.bnf}
- initializer-list:
  - `...`~opt~ initializer-clause `...`~opt~
  - initializer-list `,` `...`~opt~ initializer-clause `...`~opt~
:::

:::{.bnf}
- template-argument-list:
  - `...`~opt~ template-argument `...`~opt~
  - template-argument-list `,` `...`~opt~ template-argument `...`~opt~
:::

:::{.bnf}
- base-specifier-list:
  - `...`~opt~ base-specifier `...`~opt~
  - base-specifier-list `,` `...`~opt~ base-specifier `...`~opt~
:::

:::{.bnf}
- mem-initializer-list:
  - `...`~opt~ mem-initializer `...`~opt~
  - mem-initializer-list `,` `...`~opt~ mem-initializer `...`~opt~
:::

:::{.bnf}
- fold-expression
  - `(` `...`~opt~ cast-expression fold-operator `...` `)`
  - `(` `...` fold-operator `...`~opt~ cast-expression `)`
  - `(` `...`~opt~ cast-expression fold-operator `...` fold-operator `...`~opt~ cast-expression `)`
:::

In the fold expression, at most one [cast-expression]{.bnf} can be nominated
as expandabe.

# Conclusions

We think the notation presented here is concise, visually distinctive, and
generally readable and writable. We have also considered the implementability
of the proposed grammar and believe that the grammar proposes no serious
or novel challenges.

# References
