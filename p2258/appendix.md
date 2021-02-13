# Appendix A {#app}

This section provides analysis of other notations we considered.

## P1240 {#app.p1240}

P1240 is our (the authors') initial (and revised) proposal for static
reflection and splicing. For reflecting source constructs, we adopted the `reflexpr` operator
from the Reflection TS [@N4856], making it an expression.  We introduced a similar notation
for splicing (i.e., a keyword followed by `()`s).

As noted, there has always been some baseline dislike for the name `reflexpr`,
which occasionally appears in various proposals ([@P2087R0;@P2237R0]).

The splice notations in P1240 are not very visually distinctive. It's easy,
especially for non-experts, to mistake `typename(x)` as being somehow related to
a [typename-specifier]{.bnf}. After all, in many contexts, parentheses are used
only for grouping. A number of more specific concerns are discussed in P2088
[@P2088R0].

The required use of keywords can lead to some unfortunate compositions. For
example:

```cpp
template<typename meta::info x>
void f() {
  typename typename(x)::type var;
}
```

Historically, repetition of keywords (i.e., `noexcept(noexcept(E))` and
`requires requires`) is often viewed as a design failure by the broader C++
community (even when it is not). It seems like there should be some contexts in
which the extra annotations can be elided because only a limited subset of terms
are allowed, but this requires a careful analysis of contexts where these terms
can appear, but that may have other grammatical consequences. For example,
allowing the elision of the 2nd `typename` above effectively means that we would
need a new splice notation as `(x)` is not a viable choice.

## P2237 {#app.p2237}

P2237 did not propose a replacement for `reflexpr`. An early draft suggested the
name `reify`, but subsequent (offline) discussions showed that it was not an
improvement to the status quo.

The splicing notation presented in P2237 was made with two goals in mind:

1. To be visually distinctive from conventional syntax, and
1. Avoid requiring annotations where they can be elided.

For example:

```cpp
void f() {
  |^int| x = 42; // |^int| is a simple-type-specifier
  |^0|;          // |^0| is an expression
}
```

In cases where multiple productions can start with the same sequence of tokens,
implementations typically produce synthetic tokens containing the fully parsed
and analyzed sequence, effectively caching the parse. For example, GCC and Clang
both do this with [nested-name-specifier]{.bnf}s and [template-id]{.bnf}s. The
same technique would be used here, and we can label the synthetic tokens
according to their computed grammatical category.

Inside templates, the usual rules for adding `typename` and `template` apply.

However, P2237's use of plain `|`s to delimit splices produces some unfortunate
lexical issues. For example:

```cpp
constexpr meta::info x = ^0;
constexpr meta::info y = ^x;
int z = ||^y||; // error: expected expression
```

In order to parse that as a nested splice, the parser would have to perform some
seriously speculative lexical gymnastics. Similar (but resolvable) issues arise
when the splice appears in juxtaposition to other `|` tokens such as the
proposed pipeline rewrite operator. [@P2011R0] All other considerations aside,
this alone kills the plain `|x|` notation.

## Alternative splicing notations {#app.alts}

We discussed (among the authors) a number of alternative notations that fall into roughly
three categories:

- a single bracketed splice notation (`[:x:]`),
- multiple bracketed splice operators (`[:e:]`, `[/t/]`, etc.), and
- a unary splice operator (e.g., `%x`).

We also discuss the impact that strongly typed reflections might have on the
splice notation.

### Bracketed single splice

The single bracketed approach is what we suggest in our proposal. 

One of the major motivating reasons for making the splice operator a bracketed
expression is to allow its use in member access expressions:

```cpp
cout << x.[: get_member() :];
```

We considered a number of different bracket operators, but ended up choosing
`[:` and  `:]`. Some alternatives included:

- `[| R |]`. We think this might be too similar to the attribute brackets.
  Interestingly, this notation is used by Template Haskell for quotes (like
  source code fragments in P2237). These brackets are also a visual
  approximation of evaluation functions in various semantics models.
- `<: R :>`. Not bad, but it combines poorly in template argument lists:
  `vec<<:R:>>`. We might use these brackets for source code fragments, since
  they rarely appear in template argument lists.
- `(: R :)`. Looks like smiley faces.
- `<| R |>`. Also not bad, but the closing token is proposed for the pipeline
  operator [@P2011R0].
- `(| R |)`. Considered briefly.
- `{| R |}`. Not considered.
- `[< R >]`. Proposed in P1240 for splicing template arguments.

There are a lot of way we can combine tokens to create brackets. The current
proposal seems to be a reasonable choice and has been found pleasant enough
while working through use-cases.

### Multiple bracketed splice notations

We don't need to limit ourselves to a single splice notation. We could choose to
use different splice brackets for the different categories of grammatical constructs
being inserted into the program. In fact, P1240 does this for two of its splicers
(which it calls "reifiers"):
identifiers (`[:x:]` and template arguments (`[<x>]`). The identifier splice
(`|#x#|`) in P2237 can also be considered an application of this approach.
Template Haskell takes a similar approach with its splice operator(s).

```cpp
[:expr:] // splice an expression
[/type/] // splice a type
[<temp>] // splice a template
[:ns:]   // splice a namespace
```

The choice of some brackets here approximate some aspect of the thing reflected:
template-ids have `<>`s and namespaces appear in *nested-name-specifier*s. The
choice of brackets for expressions and types are chosen somewhat arbitrarily
(types appear in italics?).

The benefit of this approach is that eliminates the need for keywords in many
contexts.  For example:

```cpp
// template-id
[<temp>]<int>
typename [<temp>]<int>

// simple-type-specifier
[/type/]
foo::[/type/]

// nested-name-specifiers
[/type/]::id
[:ns:]::id
[<temp>]<int>::id

foo::[:ns:]::id
```

Note that we still need a leading `typename` when splicing a [template-id]{.bnf}
as a type. That seems unavoidable.

The downside of this approach is that it can be more than a bit cryptic. It also
means that programmers have to choose the right splice notation in contexts
where only one would be allowed.

### Unary splice

There's no strict requirement for splice notation to be bracketed. The design in
P2237 prefers brackets for its visual appeal, but we could easily choose to do
this with a unary operator, replacing the suggested `[:x:]` notation with, say,
`%x`. 

As above, without qualification a splice is an expression:

```cpp
template<meta::info v, // reflects a variable
         meta::info x> // reflects a non-static data member m in T
void f(T& t) {
  cout << %x;   // OK: prints the value of V
  cout << t.%x; // OK: prints the value of t.m
}
```

For a splice of anything else (in certain contexts), keywords are required.
Again, some example can reveal the flavor implied by such an approach:

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
```

FIXME: Add discussion of precedence and examples from email.

If we choose this direction, then we should also choose an alternative for the
`reflexpr` operator so that they naturally complement each other. For example,
we could choose `/` for the reflection operator.

```cpp
constexpr meta::info x = /int; // reflect
int n = %x;                    // splice
```

and we could choose `\` (yes, backslash) as the splice operator.

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
particularly visually distinctive, and we have found that splice constructs
standing out really helps readability. This also seems just a little too cute.
