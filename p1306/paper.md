---
title: Expansion Statements
author: 
  - Andrew Sutton (<asutton@lock3software.com>)
  - Sam Goodrick (<sgoodrick@lock3software.com>)
  - Daveed Vandevoorde (<daveed@edg.com>)
# date: Oct 15, 2020

geometry:
- left=1in
- right=1in
- top=1in
- bottom=1in
---

--------- -------
 Document P1306r2
 Audience CWG
--------- -------

# Version history {#history}

- r2 Removed the ability to expand over parameter packs and added a note
  explaining why. This will be readdressed in the future. Updated wording based
  on CWG review.
- r1 This paper unifies the different forms of expansion statements, so that
  only one syntax is needed. We have further refined the semantics to ensure
  that expansion can be supported for all traversable sequences, including
  ranges of input iterators. We also added discussion about `break` and
  `continue` within expansions.
- r0 The original version of this paper is P0589r0 [@P0589R0]. We have modified
  the original proposal to work with more destructurable objects including
  classes and parameter packs. We have also added a constexpr-for version that
  a) makes the loop variable a constant expression in each repeated expansion,
  and b) makes it possible to expand constexpr ranges. The latter feature is
  particularly important for static reflection [@P1240R0].

# Introduction {#intro}

This paper proposes a new kind of statement that enables the compile-time
repetition of a statement for each element of a tuple, array, class, parameter
pack, or range. Any facility that needs to traverse the elements of a
heterogeneous container inevitably duplicates this kind of repetition using
recursively instantiated templates, which allows some part of the repeated
statement to vary (e.g., by type or constant) in each instantiation.

While this behavior can be encapsulated in a single operation (e.g.,
Boost.Hana’s for_each template), there are a number of reasons we would prefer
language support. First, repetition is a fundamental building block of
algorithms. We should be able to express that concept directly rather than
through recursively instantiated templates.. Second, we’d like that repetition
to be as inexpensive as possible. Recursively instantiating templates generates
a large number of template specializations, which can end up consuming a lot of
compiler memory and compile time. Finally, we’d like the ability to “iterate”
over both destructible classes and parameter packs, and both effectively require
language support to implement correctly.


# Basic usage {#usage}

Here is an example of iterating over the elements of a tuple using the Hana
library:
 
```cpp
auto tup = std::make_tuple(0, ‘a’, 3.14);
hana::for_each(tup, [&](auto elem) {
  std::cout << elem << std::endl;
});
```
 
The `for_each` function applies the generic lambda to print each element of the
tuple in turn, by calling the generic lambda. Each call instantiates a new
function containing a call to `cout` for the corresponding tuple element.

Using the feature described in this proposal, that code could be written like
this:

```cpp
auto tup = std::make_tuple(0, ‘a’, 3.14);
template for (auto elem : tup)
  std::cout << elem << std::endl;
```
 
The template for statement expands the body of the loop once, for each element
of the tuple. In other words, the expansion statement above is equivalent to
this:

```cpp
auto tup = std::make_tuple(0, ‘a’, 3.14);
{
  auto elem = std::get<0>(tup);
  std::cout << elem << std::endl;
}
{
  auto elem = std::get<1>(tup);
  std::cout << elem << std::endl;
}
{
  auto elem = std::get<2>(tup);
  std::cout << elem << std::endl;
}
```

In other words, an expansion statement is not a loop. It is a repeated version
of the loop body, in which the loop variable is initialized to each successive
element in the tuple. Because the loop variable is redeclared in each version
of the loop body, its type is allowed to vary. This makes expansion statements a
useful tool for defining a number of algorithms on heterogeneous collections.

An expansion statement allows expansion over the following:

- Tuples (as above)
- Arrays
- Destructurable classes
- Unexpanded argument packs
- Constexpr ranges

Note that it is also possible to define expansion over a brace-init-list, but we
have opted not to provide that functionality at this time.

# Expansion and static reflection {#reflect}

The ability to repeat statements for collections of entities is central to
practically all useful reflection algorithms. Here is an early generic
implementation of Howard Hinnant’s Types Don’t Know # proposal (N3980).

```cpp
template<HashAlgorithm H, StandardLayoutType T>
bool hash_append(H& algo, const T& t) {
  constexpr meta::info members = meta::data_members_of(reflexpr(T));
  template for (constexpr meta::info member : members)
    hash_append(h, t.|member|);
}
```

Here, `constexpr` appears as *decl-specifier* of  the loop variable member,
meaning that in each expansion, that value is a constant expression (i.e.,
suitable for use in a template argument list). This is necessary since we that
variable with the splice operator (`|x|`), which yields a resolved reference to
the corresponding data member. (The splice notation is taken from [@P2237]).

Note that `data_members_of` returns a constexpr range: a forward-traversable
sequence of `meta::info` values that describe the data members of T (or rather
whatever type T becomes when the template is instantiated. The fully expanded
statement is roughly equivalent to this:

```cpp
{
  constexpr member0 = *std::next(std::begin(members), 0);
  hash_append(h, t.idexpr(member0));
}
{
  constexpr member1 = *std::next(std::begin(members), 1);
  hash_append(h, t.idexpr(member0));
}
...
{
  constexpr memberK = *std::next(std::begin(members), K);
  hash_append(h, t.idexpr(member0));
}
```

The expansion terminates after `K` expansions, where `K` is
`std::distance(std::begin(), std::end())`.

Note that expansion only occurs when the range is non-dependent (e.g., during
template instantiation). 

Without the ability to use an expansion statement, we need a recursive function
template that traverses a list of reflections. That implementation, based on an
earlier version of the forthcoming static reflection proposal is shown below:

```cpp
  // Recursive template
  template<HashAlgorithm H, StandardLayoutType T, meta::info X> 
    requires meta::is_class(X)
  hash_append_impl(H& h, T const& t) {
    // Visit the current member (hash it if you can). 
    if constexpr (!meta::is_invalid(X)) { 
      if constexpr (meta::is_non_static_data_member(X))
        hash_append(h, t.idexpr(X));
    } 
    // Continue hashing until we run out of members.
    if constexpr (!meta::is_invalid(meta::next(X))) 
      hash_append_impl<H, T, meta::next(X)>(h, t); 
  } 

  // Main interface
  template<typename H, typename T> 
  std::enable_if_t<std::is_class<T>::value, void> 
  hash_append(H& h, T const& t) { 
    hash_append_impl<H, T, meta::front(reflexpr(T))>(h, t); 
  }
```

In this implementation `meta::front` and `meta::next` are used to iterate
(statically) over the members of a declaration. They are not included in our
current static reflection proposal since they are no longer needed. 

# Break and continue {#flow}

At this time, we are proposing to disallow `break` and `continue` within
expansion statements. These can be readded as needed. Their meaning is easy to
define and implement. Our main concern is that users will confuse these
statements as providing some kind of control over the expansion itself (they
would not).

# Syntax and semantics {#syn}

The syntax for an expansion statement is identical to that of a range-based for
loop.

```cpp
template for (<expansion-declaration> : <expansion-initializer>) statement
```

The terms `<expansion-declaration>` and `<expansion-initializer>` are syntactic
variables denoting the matched declaration and initializer in their
corresponding positions.[^formatting]

[^formatting]: The programs used to typeset this document do not allow
alternative fonts inside formatted code. We use the `<name>` notation as an
alternative.

An expansion-statement expands statically to a statement that is equivalent to
the following pattern. 

```cpp
{ 
  <constexpr-specifier-opt> <range-initializer-declaration> __range =
    expansion-initializer;
  <constexpr-specifier-opt> auto __begin = <begin-expr>;
  <constexpr-specifier-opt> auto __end = <end-expr>;

  constexpr auto __iter_0 = __begin;
  <stop expansion if __iter_0 == __end>
  { 
    for-range-declaration = get-expr(__iter_0)>;
    statement
  }
  constexpr auto __iter_1 = next-expr(__iter_0);
  <stop expansion if __iter_1 == __end>
  { 
    for-range-declaration = get-expr(__iter_1)>;
    statement
  }

  // ... repeats until __iter_K == __end
}
```

The optional `<constexpr-specifier>` is `constexpr` only if the
`<expansion-declaration>` includes `constexpr` in its [:decl-specifier-seq]{}.
The *range-initializer-declaration* is `auto&&` if the *expansion-initializer*
has array or function type, and auto otherwise (this prevents decay for prvalues
of those types). The meaning of placeholder expressions *begin-expr*,
*end-expr*, *get-expr*, *next-expr* depend on the type of the
expansion-initializer and the presence of the constexpr keyword in the loop
head.

If the substitution of the *expansion-initializer* into a range-based `for`
statement of the form

```cpp
template for (auto&& __unspecified : expansion-initializer) ;
```

would succeed, the expansion is performed over a sequence of iterators `I`
ranged over by expansion-initializer, and the placeholder expressions are:

- *begin-expr* and *end-expr* are that of the range-based for loop,
- *get-expr(I)* is `*I`
- *next-expr(I)* is `std::next(I)`

Otherwise, if the substitution of the expansion-initializer into a structured
binding of the form

```cpp
auto [I0, I1, ..., IK] = expansion-initializer
```

would succeed, the expansion is performed over an integer index I into the
sequence of members selected for destructuring, and the placeholder expressions
are:

- *begin-expr* is `0u`
- *end-expr* is `K`
- *get-expr(I)* is the Ith entity named by the structured binding
- *next-expr(I)* is `I + 1`

Note that the form of the expansion is intended to be valid for any expandable
entity used with the loop. In the most general case, this emulates the
hand-unrolling of range-based for loop over an input range (i.e., a range with
input iterators). Care must be taken not to “accidentally” consume range
elements by call `std::distance` or advancing multiple elements in a single call
to std::next. For unexpanded packs, and destructurable objects, the expansion
can be trivially implemented in terms of a simple integer index. A compiler
might also optimize (for compile-time) certain range-based expansions if they
can determine the iterator category of the range.

Examples:

```cpp
auto tup = std::make_tuple(0, ‘a’);
template for (auto& elem : tup)
  elem += 1;
[[assert: tup == make_tuple(1, ‘b’)]];
 ```

Expands as:

```cpp
{ 
  auto &&__range = tup;
  {
    auto& elem = std::get<0>(__range);
    elem += 1;
  }
  { 
    auto& elem = std::get<1>(__range);
    elem += 1;
  }
}
```

Below is an example of a `constexpr` expansion:

```cpp
constexpr std::vector<int> vec { 1, 2, 3 };
template for (constexpr int n : vec)
  f<n>();
```

Expands as:

```cpp
{
  constexpr auto __range = vec;
  constexpr auto __end = vec.end();

  constexpr auto __iter_0 = vec.begin();
  {
    constexpr int n = *__iter_0;
    f<n>();
  }
  constexpr auto iter_1 = std::next(__iter_0);
  { 
    constexpr int n = *__iter_1;
    f<n>();
  }
  constexpr auto iter_2 = std::next(__iter_1);
  { 
    constexpr int n = *__iter_2;
    f<n>();
  }
}
```

# Observations {#notes}

In the following subsections we discuss some specification details, potential
additions, and implementation notes.

## Required header files {#notes.headers}

This feature does not require users to include additional header files to use
the expansion facilities, just like the range-based for loop. Many expansions
are defined in terms of core language constructs and do not require header
files. Expanding over tuples does require the `<tuple>` header file, but that
will almost certainly have been included before the use of the first
expansion-statement. 

## Enumerating loop bodies {#notes.loops}

It may be useful to access the instantiation count in the loop body. This could
be achieved by using an enumerate facility:
 
```cpp
template for (auto x : enumerate(some_tuple)) {
  // x has a count and a value
  std::cout << x.count << “: “ << x.value << std::endl;

  // The count is also a compile-time constant.
  Using T = decltype(x);
  std::array<int, T::count> a;
}
```
 
The enumerate facility returns a simple tuple adaptor whose elements are
count/value pairs. This facility should be relatively easy to implement.

# Interaction with parameter packs {#notes.packs}

Previous versions of this proposal included the ability to use a bare unexpanded
parameter pack as the expansion-initializer. However, this leads to ambiguities.
Consider this example from Richard Smith:

```cpp
template<typename ...T> 
void f(T ...v) {
  g([&](auto y) {
    template for (auto x : v) { /*...*/ } // Pack expansion or not?
  }(v)...);
}
```

The expansion of `v` can be interpreted in two ways: it can be expanded over all
elements in the pack as we instantiate the outer function `f`, or it could be
expanded over each element of the pack when instantiate the lambda.

# Interaction with initializer lists {#notes.lists}

The feature could be extended to allow brace-init-lists in the
*expansion-initializer*. This is currently ill-formed since it requires deduction
from an initializer list. However, there may be some value in supporting this
syntax:

```cpp
template for (auto x : {0, ‘a’, 3.14})
  std::cout << x;
```
 
which would be equivalent to:

```cpp
  template for (auto x : make_tuple(0, ‘a’, 3.14))
    std::cout << x;
```
 
We are not formally proposing these extensions at this time since they would
(could?) potentially introduce a new form of template argument deduction in
order to avoid an explicit rewrite to make_tuple.

Note that this would also address issues with the use of parameter packs.
However, this feature would require defining deduction from initializer lists,
which requires additional study.

# Implementation experience {#impl}

At the time of writing, the foundations of the feature have been implemented in
a fork of Clang 8.0.0, except for the unified syntax. However, both statements
use the same underlying framework to choose salient operations for expansion.
The SSA-style expansion for input ranges is also unimplemented as it requires a
non-trivial change to our approach.

For these expansion statements to work, the body of the loop must be parsed as
if inside a template and then repeatedly instantiated after the body is parsed.
Moreover, names appearing in expressions within an expansion loop body may not
be ODR-used, even in a non-dependent context. If the expansion operand is empty,
the result of expansion is an empty statement. The statements, expressions, and
declarations within the body will be effectively erased from the program.

# Suggested wording {#word}

The following changes have been made since the initial wording review:

- Add a feature macro
- Disallow identifier labels in expansion statements; case and default are still
  allowed in switch statements in - expansion statements.
- Use for-range-declaration instead of expansion-declaration
- Define iterable and destructurable in their respective sections. Make their
  definitions distinct.
- Don’t make expansion statements template entities
- Rewrite p1 of expansion statements to make them defined in terms of
  unspecified template parameters so that the name of the for-range-declaration
  depends on them.
- Make expansion statements template definitions (p2 in 8.6)
- Provide new wording for iterative expansion to use range for evaluation (p8)
- A for-range-declaration name is only type-dependent if it has placeholders
- Add a notion of “intervening statement” to disallow `break`, `continue`, and
  labels within expansion statements.
- Fixed a missing constexpr-specifier for the case where constexpr is in the
  decl-specifier of a destructuring.

Open issues:

- Template parameter for for-range-declaration
- Removal of cases for dependent names
- Basic.scope.pdecl/p11 -- point of declaration -- add new rule.
- Don’t define new classes in range-for-decl.
- If the iterator value refers to a dynamic allocation, this might work. Can’t
  take a constexpr snapshot of said memory. Probably should not allow -- maybe,
  but successive iterations would not see the same dynamic memory.

# 8 Statements [stmt.stmt] {-}

Modify the grammar of statements in Clause 8 to include expansion statements.

:::{.bnf}
statement:
\ \ \ \ labeled-statement
\ \ \ \ attribute-specifier-seq~opt~ expression-statement
\ \ \ \ attribute-specifier-seq~opt~ compound-statement
\ \ \ \ attribute-specifier-seq~opt~ selection-statement
\ \ \ \ attribute-specifier-seq~opt~ iteration-statement
\ \ \ \ attribute-specifier-seq~opt~ expansion-statement
\ \ \ \ attribute-specifier-seq~opt~ jump-statement
\ \ \ \ declaration-statement
\ \ \ \ attribute-specifier-seq~opt~ try-block      
:::

2. A substatement of a statement is one of the following:
(2.1) — for a labeled-statement, its contained statement,
(2.2) — for a compound-statement, any statement of its statement-seq,
(2.3) — for a selection-statement, any of its statements (but not its init-statement), or 
(2.4) — for an iteration-statement, its contained statement (but not an init-statement), or
(2.5) — for an expansion-statement, its contained statement. 

Add a new paragraph 4.

4. A statement S2 is an intervening statement of statements S1 and S3 if S1 encloses S2 and S2 encloses S3.
8.1 Labeled statement [stmt.ranged]
Add the following:

2. Case labels and default labels shall occur only in switch statements. There shall not be an intervening expansion-statement between the label and its nearest enclosing switch statement.

3. An identifier label shall not occur in an expansion-statement (8.6).
8.5.4 The range-based for statement [stmt.ranged]
Add the following paragraph.

3. An expression is iterable if it can be used as a for-range-initializer.

# 8.6 Expansion statements [stmt.expand] {-}
Insert this section after 8.5 (and renumber accordingly). Note that break and continue are only allowed in specific contexts. No new wording is needed to disallow their appearance within expansion-statements.

1. Expansion statements specify compile-time repetition, with substitutions, of their substatement.

```bnf
expansion-statement:
  template for  ( for-range-declaration : expansion-initializer ) statement

expansion-initializer:
  expression
```

2. The substatement of an expansion-statement implicitly defines a block scope (6.3) which is entered and exited for each expansion. If the substatement in an expansion-statement is a single statement and not a compound-statement, it is rewritten as a compound-statement containing the original statement.

3. If a name introduced in the for-range-declaration in an expansion-statement is redeclared in the outermost block of the substatement, the program is ill-formed.

4. In the decl-specifier-seq of a for-range-declaration in an expansion-statement, each decl-specifier shall be either a type-specifier or constexpr.

5. The substatement is implicitly parameterized by a non-type template parameter of type int that is used to form the initializer for the for-range-declaration. If the expansion-initializer is destructurable (9.5), the initializer is type-dependent. Otherwise, if the expansion-initializer is iterable (8.5.4), the type of the initializer is decltype(*I) where I is an iterator into the range. Otherwise, the program is ill-formed. [Note: The name declared by the range-for declaration is type-dependent if the expansion-initializer is destructurable and value-dependent otherwise. -- end note]

6. For the purpose of name lookup and instantiation, the for-range-declaration and the statement of the expansion-statement are together considered a template definition.

7. An expansion-statement is expanded if its expansion-initializer is not type-dependent and either its type is destructurable or its expansion-initializer is not value-dependent. This entails the repetition of  the substatement for each member of the expansion-initializer. Each repetition of the substatement is called an expansion and is an instantiation (13.8) of the for-range-declaration, its initializer, and the statement. 

8. If the expansion-initializer is destructurable, the expansion-statement is expanded once for each element of the identifier-list of a structured binding declaration of the form auto &&[u1, u2, …, un] = expansion-initializer, where n is the number of elements required in a valid identifier-list for such a structured binding declaration, and is equivalent to:
{
  constexpr-specifieropt auto&& seq = expansion-initializer ;
  { // ith repetition of the substatement
    for-range-declaration = get-expri ;
    statement
  }
}
where get-expri is the initializer for the ith identifier in the corresponding structured binding declaration. The constexpr-specifier is present in the declaration of seq if constexpr appears in for-range-declaration. The name seq is used for exposition only.

9. Otherwise, the expansion-initializer is iterable. The expansion-statement is expanded once for each element in the range computed by the expansion-initializer and is equivalent to:
{
  constexpr auto range = expansion-initializer ;
  { // ith repetition of the substatement
    for-range-declaration = get-expri ;
    statement
  }
}
where get-expri is the ith value in the sequence yielded by the evaluation of the following range-based for loop:
for (auto&& elem : expansion-initializer)
  /* yield */ elem ;
The names range and elem are for exposition only.

10. Otherwise, the expansion-initializer must be iterable. The expansion-statement
is expanded once for each element in the range computed by the expansion-initializer
and is equivalent to:

```cpp
{
  constexpr auto range = expansion-initializer ;
  { // ith repetition of the substatement
    for-range-declaration = * get-expri ;
    statement
  }
}
```

where get-expri is the ith iterator in the sequence yielded by the evaluation of the following for loop:

```
for (auto iter = begin-expr ; iter != end-expr ; ++iter)
  /* yield */ iter ;
```

The names begin-expr and end-expr are the expressions found using the rules for range-based for statements (8.5.4). The names range and iter are for exposition only.

8.[~6]{}[+7]{}.1 The break statement [stmt.break]

Modify paragraph 1.
      
1. The break statement shall occur only in an iteration-statement or a switch statement with no intervening expansion-statement, and causes termination of the smallest enclosing iteration-statement or switch statement; control passes to the statement following the terminated statement, if any.
8.67.2 The continue statement [stmt.cont]
Modify paragraph 1.
          
1. The continue statement shall occur only in an iteration-statement with no intervening expansion-statement, and causes control to pass to the loop-continuation portion of the smallest enclosing iteration-statement, ...

9.5 Structured binding declarations [temp]
Add the following paragraph.

6. An expression is destructurable if it can be used as the initializer of a structured binding declaration.
13.7.2.2 (Dependent names [temp.dep]).

In [temp.dep.expr]/2 add a bullet as follows:
…
the identifier introduced in a postcondition (9.11.4) to represent the result of a templated function whose declared return type contains a placeholder type,
it is a name introduced by a for-range-declaration that contains a placeholder type and is declared in an expansion-statement (8.6) with a destructurable expansion-initializer (9.5),
…
13.7.2.3 Value-dependent expressions [temp.dep.constexpr]
In [temp.dep.constexpr]/2 add a bullet as follows:
…
it is the name of a non-type template parameter,
it is a name introduced by a for-range-declaration in an expansion-statement,
...

15.10 Predefined macro names [cpp.predefined]
Add the following entry to Table 17:

...
...
__cpp_expansion_statements
201907L
...
...

Open Issues

The current proposal does not allow for an initial statement, which is supported
in all other C++20 iteration and selection statements. Adding this should be
straightforward.

Related discussion

There was an overlooked discussion about this feature on std.proposals in 2013
(https://groups.google.com/a/isocpp.org/forum/#!topic/std-proposals/vseNksuBviI).

# References {-}