---
title: Better Typing for Static Reflection
author: 
  - Andrew Sutton (<asutton@lock3software.com>)
  - Wyatt Childers (<wchilders@lock3software.com>)
date: Oct 15, 2020

geometry:
- left=1in
- right=1in
- top=1in
- bottom=1in
---

--------- --------
 Document P2269R0
 Audience SG7
--------- ---------

# Introduction {#intro}

This paper considers a change to the P1240 model of static reflection, that
would allow for multiple, interconvertible reflection types that correspond
(roughly) to the construct or entities reflected.

# Background

P09532 proposes a hierarchical representation of reflections [@P0953R2]. Despite
the advantages of having typed reflections (especially modern programming
techniques), there are two drawbacks. First, the use of class objects during
constant expression evaluation can significantly inflate compile times. That
could be particularly bad for heavily metaprogrammed translation units. Second,
interrelated systems of types are hard to evolve. A change in the relationship
between types in the system will break more code than a change to a single type,
which breaks more code than a change to a function.

In P1240, all reflections are represented by a single scalar type: `meta::info`
[@P1240R1].

```cpp
constexpr meta::info expr = reflexpr(0);
constexpr meta::info type = reflexpr(int);
constexpr meta::info ns = reflexpr(std);
```

As a scalar type, we avoid the typical safety checks necessary for class member
objects in constant expression evaluators, so there is less compile-time
overhead. Because the library is comprised of only free functions, there should
be less breakage of use code as the language and its concepts evolve. We can
deprecate individual functions rather than parts of classes or their
relationships. In exchange, this approach gives up the usual benefits we expect
of more strongly typed interfaces.

P1733 suggests a compromise in which P1240 provides a low-level foundation for
program introspection, and the language provides tools for building type-safe
abstractions above it [@P1733R0]. The proposal requires a language change that
allows constraints (as in concepts) to be evaluated on function arguments that
are constant expressions. This feature was intended to be used with constructors
as a mechanism for filtering out invalid constructions. During the Prague
meeting, discussion led to the inherent tabling of this proposal while
`constexpr` function parameters were explored; they provide a more general model
for achieving this.

# Core reflections

There are two sources of reflection values: the reflection operator (`^`)
and `meta` library functions. The former is used to directly access information
about a source code construct, while the latter is used to navigate between
them.

There are four possible facets of a reflection.

- Entity---the semantic elements of a program.
- Name---the use of a term to refer to a (possibly declared) entity.
- Declaration---introduce entities or aliases for entities.
- Expression---the use of a term to denote an entity or compute value.

The "name" category is more general than in the standard. A *type-id* is a kind of
name. Note that names emphasize *use*, not existence. These are (a subset) of
operands of the reflection operator.

An entity declaration introduces a distinct entity and is defined according to
its kind (a variable is defined by its initializer, a function is defined by its
body, a class is defined by its specification, etc.). An alias declaration is
defined to be a name.

For expressions, we can only access the denotation or value if it is known
statically.

Every reflection is always comprised of two or more facets?

- A reflection of `std::size_t` is a name of an alias defined as (possibly)
  `unsigned long`.
- An *expression* can have all of them.

FIXME: What is the type of a reflection.


This system defines overlapping subsets of reflection values by defining a
small-ish number of reflection types. The names of these types all end in
`_info`. A reflection type provides access to the union of syntactic and
semantic properties reachable from the reflection value, which can include:

- the use of a name (or name-like grammar term),
- the declaration of a name, and
- the entity declared by a declaration.

The set of properties depends on the kind of construct reflected, which is
determined by the operand (and consequently type) of the reflection operator.

```cpp
// Entity reflections
constexpr meta::function_info fn = ^main;
constexpr meta::variable_info var = ^argc;
constexpr meta::type_info t = ^std::size_t;
constexpr meta::template_info tmp = ^std::pair;
constexpr meta::concept_info con = ^std::integral;
constexpr meta::namespace_info ns = ^std;

// Expression reflections
constexpr meta::expression_info e = ^0;
```

The type of the reflection operator is that which most closely describes the
thing reflected. Tor types, templates, concepts, and namespaces, reflection
straightforward. For example, a reflection of `std::size_t` only ever reflects
(the use and declaration of) a type. The reflections of `main` and `argc` are
reflections if both *expression*s (having a type and value category) and the
(declared) entities.

When returned from the reflection operator, the following properties can be
queried:

- A `function_info` can be used to query the properties of the *id-expression*
  naming the declaration of a function, the properties of that declaration,
  and the semantic properties of the declared entity.
- A `variable_info` can be used to query the properties of the *id-expression*
  naming the declaration of an object or reference, the properties of that
  declaration, and the semantic properties of the declared entity.


- A `variable_info` represents the syntactic and semantic properties of the
  *id-expression* naming the declaration of an object or reference.
- A `type_info` represents the syntactic and semantic properties of a *type-id*
  including its declaration (if any) and corresponding type. This can also
  describe *base-specifier*s.
- A `template_info` represents the syntactic and semantic properties of a
  (possibly qualified) *template-name* and its corresponding template.
- A `concept_info` represents the syntactic and semantic properties of a
  (possibly qualified) *template-name* naming a concept and its corresponding
  entity.[^concepts]
- An `expression_info` is reflects the syntactic and semantic properties of
  an expression described below.
- A `namespace_info` represents the syntactic and semantic properties of a
  *qualified-namespace-specifier* and its corresponding namespace.

represents the syntactic and semantic properties of an expression, including the
  declaration of an *id-expression* and its corresponding value, object,
  reference, function, data member, or bit-field.

[^concepts]: C++20 does not define concepts to be a distinct entity from
templates, but it probably should.

When we talk of *syntactic properties*, we are concerned with properties
related to the actual spelling of the source code reflected. Source location
is an obvious (and interesting) syntactic property. For the reflection `^x`,
the source location is that of the id-expression `x`, not the declaration it
names.

The library provides additional information about declarations:

```cpp
constexpr meta::declaration_info d1 = meta::declaration_of(^std);
constexpr meta::declaration_info d2 = meta::declaration_of(^std::pair);
constexpr meta::declaration_info d3 = meta::declaration_of(^std::stoi);
constexpr meta::declaration_info d3 = meta::callee_of(^f(3));
constexpr std::vector<meta::declaration_info> ds = meta::members_of(some_enum);
```

A `declaration_info` object represents the syntactic form of a declaration and
the entity it declares (if any). To keep the core set of reflection types as
small as possible, *base-specifier*s are considered to be declarations.

The reflection types above can be converted to `declaration_info` in various
cases.

- An `expression_info` can be converted to a `declaration_info` if it reflects
  *id-expression* denoting a single entity.
- A `type_info` can be converted to a `declaration_info` if it reflects a 
  (possibly qualified) *type-name*.
- A `namespace_info` can be converted to a `declaration_info`.
- A `template_info` can be converted to a `declaration_info`.
- A `concept_info` can be converted to a `declaration_info`.

Conversely, `declaration_info` values can be converted to the reflection types
above in various cases:

- A `declaration_info` reflecting the declaration of a variable, function,
  enumerator, data member, or bit-field can be converted to an
  `expression_info`.
- A `declaration_info` reflecting a `typedef` declaration or *type-alias* can be
  converted to a `type_info`.
- A `declaration_info` reflecting a *base-specifier* can be converted to a
  `type_info`.
- A `declaration_info` reflecting a namespace-definition or namespace-alias can
  be converted to a `namespace_info`.
- A `declaration_info` reflecting a *template-declaration* can be converted to a
  `template_info`.
- A `declaration_info` reflecting a *concept-definition* can be converted to a
  `concept_info`.

When converting declaration reflections to other categories, the syntactic
properties of the converted value are those of the declaration, not the use of
its name. For example:

```cpp
constexpr meta::type_info t1 = ^std::uint32_t;
constexpr meta::type_info t2 = meta::declaration_of(t1);
assert(location_of(t1) != location_of(t2));
```

Note that the initializaiton of `t2` converts the reflection of the `typedef`
declaration of `std::uint32_t` (or alias) to a `type_info`.

None of these conversions are considered narrowing. Information is never lost
by these conversions. These are also not widening conversions.

The primary reflection types and `declaration_info` are called the *fundamental
reflection types*. Ideally, the fundamental reflection types---and the
relationships between them---will not change in ways that user break code. For
that to happen, the following must hold:

1. primary reflection types are never interconvertible.
1. All `declaration_info` values can be converted to exactly one primary
   reflection.

Note that some, but not all, primary reflections can be converted to
`declaration_info` reflections. The following sections describe a richer (and
less evolutionarily stable) set of reflections to wich primary reflections might
be converted. Note, however, that the likelihood of requiring deprecations
increases with the number of reflection types.

# Type reflections

It seems desirable to provide `_info` types that further partition the set of
types, declarations, and aliases.

- `fundamental_type_info`
- `pointer_type_info`
- ...
- `class_type_info`
- `union_type_info`
- `enum_type_info`

We probably don't want a `qualified_type_info`, since most types can be
cv-qualified. Instead, the library should provide operations to determine if
a type has any qualifiers.

Any `_type_info` reflection can be converted to a `type_info` reflection.

The `class_`, `union_`, and `enum_` type info classes can also be converted
to `declaration_info`.

# Expression reflections

We could provide... Bob Lob Law.

# Declaration reflections

Given the richness of C++'s declaration system, it seems reasonable to want
a reflection type for each (useful) kind of declaration. This organization
of these types roughly follows that of a conventional AST.

- A `variable_info` reflects the declaration of an object or reference or
  static data member.
- A `function_info` reflects the declaration of a function or static member
  function.
- A `data_member_info` reflects the declaration of a non-static data member.
- A `member_function_info` reflects the declaration of a non-static member
  function, including constructors, destructors, and conversions.
- A `enumerator_info` reflects an enumerator in an `enum` declaration.

And so forth and so on.

**FIXME: Write this**

A value of any of these reflection types can be converted to `declaration_info`
and to `expression_info`.

# Reflection types and splicing

**FIXME:** Import discussion for p2258.

# References
