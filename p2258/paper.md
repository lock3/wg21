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
reflection. Splicing (previously "reification" in P1240) is the inverse of
reflection: it inserts a reference to a reflected entity or expression into a
program [@P1240R1].

For the purpose of brevity, this paper uses the suggested unary `^` operator
as the reflection operator as opposed to `reflexpr`.

The P1240 paper proposal describes `constexpr`-based support for static
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

P2237R0 suggests considerably different syntax for splicing: there is only one
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
  templates, since spliced terms are explicitly qualified by their operator.

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

This minimal notation makes the programming model decidedly script-like since
there are relatively few annotations. The programmer says where reflections will
be spliced into the program, but not what kind of reflections are expected or
what kind of syntax is being generated. The meaning of a splice inferred from
context (by both the compiler and reader). However, unlike dynamically typed
scripting languages, C++ is still strongly typed. Using the wrong reflection or
splice in the wrong context will cause the program to be ill-formed, not
incorrect.

Making notation distinct and unfamiliar is intended to draw the eye, so that
readers better understand that the code should be interpreted differently than
"normal" C++. Visually, the `|x|` notation is intended to resemble a "gap" in
the flow of the source text, which is filled by the entity or expression
reflected by `x`.

# Evaluation {#eval}

This section examines some weaknesses of the proposed approaches.

## P1240 Evaluation {#eval.p1240}

The splice notations in P1240 are not very visually distinctive. It's easy,
especially for non-experts, to mistake `typename(x)` as being somehow related
to a *typename-specifier*. After all, in many contexts, parentheses are used
only for grouping.

The required use of keywords can lead to some unfortunate compositions. For
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

Note that allowing the elision of the 2nd `typename` above effectively means
that we would need a new splice notation as `(x)` is not a viable choice.

## P2237 {#eval.p2237}

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
(but resolvable) issues arise when the splice appears in juxtaposition to
other `|` tokens such as the proposed pipeline rewrite operator. [@P2011R0]

All other considerations aside, this alone kills the plain `|x|` notation.

<!--
# Adaptive splice {#adapt}

One of the more interesting aspets of splicing is that it gives rise to a novel
form of dependence, which we call reflection dependence. A splice is *reflection
dependent* if its operand is type-dependent or value-dependent, meaning that
the splice can belong to any syntactic categories. Consider:

```cpp
template<typname t, int n, meta::info x>
void f() {
  vector<t> vec1;     // OK
  vector<n> vec2;     // error: n is not a type
  vector<typename(x)> vec3; // P1240 OK
  vector<[<x>]> vec3; // P1240 Deferred check
  vector<|x|> vec3;   // P2237 Deferred check
}
```

In many cases, the language provides a good level of checking in templates,
which results in `vector<t>` being accepted and `vector<int>` being rejected.
Because we don't kow the value of `x`, we can't determine its syntactic category
at parse time. 

In P1240, the user could specify the template argument as `typename(x)`, which
can be checked at parse time, although instantiating with any other kind of
reflection would result in a type error during instantiation. However, writing
the template argument as `[<x>]` would explicitly defer the check until
instantiation time.[^templarg] When `x` is instantiated, the splice becomes
a type, template, or expression splice depending on the entity reflected by
`x`.


Because P2237 does not support explicit kinding of splices, the checking of all
spliced template arguments are deferred until instantiation.
In both cases, we could describe the template argument splice as "adaptive".

[^templarg]: The Clang implementation spells this `templarg(x)`.

Adaptive splices are most useful when forwarding reflections of template
arguments through parameter packs:

```cpp
template<meta::info... xs>
void f() {
  // Assuming various template overloads of g
  g<[xs|...>();   // P2237
  g<[<...xs>]>(); // P1240
}
```

No parse-time checking of template arguments is done here.
-->

# Splice notation

We probably want something between the distinctive terseness of P2273 and the
specificity of P1240. However, we should try to avoid unnecessary repetition of
keywords, and we should avoid requiring keywords in contexts where they are not
needed. The following sections present potential splicing notations that fall
within that spectrum. There three notations discussed:

- a single bracketed splice notation (`[|x|]`),
- multiple bracketed splice operators (`[|e|]`, `[/t/]`, etc.), and
- a unary splice operator (e.g., `%x`).

We also discuss the impact that strongly typed reflections might have on the
splice notation.

## Bracketed single splice

One approach is to adopt `[|` and `|]` as enclosing token pairs for splices.
These are visually distinctive, easily greppable, and don't have weird lexical
issues combining with other tokens. This notation may be too visually similar to
attribute syntax (`[[` and `]]`), which may motivate a change in the future.

Without additional qualification or context, `[|x|]` is a primary expression
that produces an *id-expression* referring to a function, variable, member
function, data member, or bitfield. This is essentially `idexpr` in P1240.
For example:

```cpp
template<meta::info t, // reflects a type T
         meta::info v, // reflects a variable V
         meta::info x> // reflects a non-static data member m in T
void f() {
  cout << [|e|];   // OK: prints the value of V
  cout << t.[|x|]; // OK: prints the value of t.m
  [|t|];           // error: T is not an expression
}
```

Note that the error from using `t` occurs during instantiation, not parsing.

We can then the grammar to permit splices of types, templates, and namespaces
in other contexts:

```cpp
template<meta::info t, // reflects a type T
         meta::info x> // reflects a template X
void f() {
  typename [|t|] *p;    // OK: declares a pointer-to-T
  typename [|t|](0, 1); // OK: constructs a T temporary
  [|t|](0, 1);          // error: T is not invocable
  template [|x|]<int> var; // OK: declares var with type X<int>
}
```

Here is the complete list of cases where the grammar would need to be modified
to support splices. Here, `type` reflects a type, `temp` reflects a template
with a single type parameter, and `ns` reflects a namespace.

```cpp
// unqualified-id (as an expression)
template [|temp|]<int>

// typename-specifier
typename [|type|]
typename template [|temp|]<int>
typename foo::[|type|]
typename foo::template [|temp|]<int>

// nested-name-specifiers
[|type|]::id
[|ns|]::id
template [|temp|]<int>::id
foo::[|type|]::id
foo::[|ns|]::id
foo::template [|temp|]<int>::id

// FIXME: Others? Using declarations?
```

The `typename template` notation is unfortunate but unavoidable (even in P1240).
Reflections have a kind of higher-order dependence than normal type or value
dependent terms. For example, unlike template template parameters, we don't know
whether a template reflection reflects a class template, function template, or
variable template. When a reflection is value-dependent, we need the `template`
to parse the *template-argument-list*, and we need the `typename` to ensure the
entire term is parsed as a *type-specifier*. The latter avoids this ambiguity:

```cpp
template [|temp|]<int> * p // multiplication by p
typename template [|temp|]<int> * p // declaration of a pointer p
```

Keywords are not required in other contexts (e.g., *base-specifier*s)
because only one kind of term can appear:

```cpp
template<meta::info x> // reflects a template
struct s : [|x|]<int> { ... };
```

## Multiple bracketed splice notations

We don't need to limit ourselves to a single splice notation. We could choose to
use different splice brackets for the different kinds of grammars being inserted
into the programmer. In fact, P1240 does this for two of its reifiers:
identifiers (`[:x:]` and template arguments (`[<x>]`). The identifier splice
(`|#x#|`) in P2237 can also be considered an application of this approach.
Template Haskell takes a similar approach with its splice operator(s).

```cpp
[|expr|] // splice an expression
[/type/] // splice a type
[<temp>] // splice a template
[:ns:]   // splice a namespace
```

The choice of some brackets here approximate some aspect of the thing reflected:
template-ids have `<>`s and namespaces appear in *nested-name-specifier*s. The
choice of brackets for expressions and types are chosen somewhat arbitrarily
(types appear in italics?).

The benefit of this approach is that eliminates the need for keywords in many
contexts:

```cpp
// template-id
[<temp>]<int>

// simple-type-specifier
[/type/]
foo::[/type/]

// typename specifier
typename [<temp>]<int>
typename foo::[<temp>]<int>

// nested-name-specifiers
[/type/]::id
[:ns:]::id
[<temp>]<int>::id
foo::[/type/]::id
foo::[:ns:]::id
foo::[<temp>]<int>::id

// FIXME: Others? Using declarations?
```

Note that we still need a leading `typename` when splicing a *template-id* as a
type. That seems unavoidable.

The downside of this notation is that it can be a bit cryptic. It also means
that programmers have to choose the right splice notation in contexts where
only one would be allowed.

## Unary single splice

There's not strict requirement for splice notation to be bracketed. The design
in P2237 prefers brackets for its visual appeal, but we could easily choose to
do this with a unary operator, replacing the suggested `[<x>]` notation with,
say, `%x`.

As above, without qualification any splice is an expression:

```cpp
template<meta::info v, // reflects a variable
         meta::info x> // reflects a non-static data member m in T
void f(T& t) {
  cout << %x;   // OK: prints the value of V
  cout << t.%x; // OK: prints the value of t.m
}
```

For a splice of anything else (in certain contexts), keywords are required.

```cpp
// unqualified-id (as an expression)
template %temp<int>

// typename-specifier
typename %type
typename template %temp<int>
typename foo::%type
typename foo::template %temp<int>

// nested-name-specifiers
%type::id
%ns::id
template %temp<int>::id
foo::%type::id
foo::%ns::id
foo::template %temp<int>::id

// FIXME: Others? Using declarations?
```

If we choose this direction, then we should also choose notation for the
`reflexpr` operator so that they naturally complement each other. For example,
we could choose `/` for the reflection operator.

```cpp
constexpr meta::info x = /int; // reflect
int n = %x;                    // splice
```

Or we could choose `\` (yes, backslash) as the splice operator.

```cpp
constexpr meta::info x = /int; // reflect
int n = \x;                    // splice
```

We could also choose to make the splice operator a suffix instead of a prefix.

```cpp
constexpr meta::info x = /int; // reflect
int n = x\;                    // splice
```

Giving the operator lower precedence than a unary operator would allow this
somewhat clever construction:

```cpp
/int\ // splices the reflection of int (i.e., identity)
```

A downside of this approach is that single character unary operators are not
particularly visually distinctive.

## Type-based splicing

We should also consider how splicing works in the context of strongly typed
reflections. If we move to a system where we know more about the constructs
reflected by an entity, then we can elide certain keywords. This works
particularly well with a single splice notation:

```cpp
template<meta::type_info t, meta::expr_info e>
void f() {
    [|t|] * p; // declares a pointer
    [|e|] * p; // multiplies by p
}
```

And it provides stronger checks with multiple splice notations:

```cpp
template<meta::type_info t,
         meta::expr_info e>
void f() {
    [|t|] * p; // error: t does not reflect an expression
    [/e/] * p; // error: e does not reflect a type
}
```

Note that this feature could be applied as an extension to the notations above,
but not as an alternative. Templates can still be parameterized by the most
general kind of reflection (`meta::info`).

# Conclusions

After lengthy discussions and negotiations, we strongly recommend XXX as the
splicing notation for static reflection.

# References
