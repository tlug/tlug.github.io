{-  |
    An Explanation of Monadic Parsers in Haskell

    This demonstrates, with plenty of explanation, a simple Monadic parser
    built "from scratch."

    This is much simpler than the parser libraries such as Parsec[1][2].

    References:

    * [1]: https://hackage.haskell.org/package/parsec
    * [2]: https://en.wikibooks.org/wiki/Haskell/Practical_monads#Parsing_monads
-}

-- This runs the HTF (Haskell Test Framework) preprocessor to turn our
-- test_* functions below into tests that get run.
{-# OPTIONS_GHC -F -pgmF htfpp #-}

-- This allows us to use type signatures on the functions we define
-- in @instance@ declarations that supply the functions to make a
-- type a member of a class.
{-# LANGUAGE InstanceSigs #-}

module TLUG.MonadicParserDemo (htf_thisModulesTests) where
import Test.Framework


{-  |
    During the parse we need to maintain some state, which we wrap up
    in a value of the following 'ParserState' type. We construct the
    initial version of this state when we start parsing a document
    and, when done, extract any relevant information from it before we
    throw it away.

    The type system will make sure that values of this state exist
    and are handled only during a specific parse run and cannot leak
    out to the rest of the program.
-}
data ParserState = PState
    { input :: String       -- ^Text remaining to be parsed
    }


{-  |
    A "Parser of a" is a function that may be run during a parse and
    will give back a value of type "a". (Frequently it would parse
    this value out of the input stream.) These functions may be
    combined to produce new, more complex parsers, so they are called
    "combinators." They can be used only within a parse run. A parser
    that has no particular value to return will generally give back
    '()', the sole inhabitant of type '()' (pronounced "Unit").

    Hidden inside a @Parser a@ is a function that takes a
    'ParserState' and returns a tuple of @(a, ParserState)@, that is,
    the value it wants to give back and the new, potentially updated
    state. (This function may be extracted with the 'parse' function
    automatically defined by our label on the field below.) So
    internally the parser combinator has full access to use and change
    parser state, such as by reducing the remaining input (consuming
    input characters), though this isn't visible from the outside.

    The whole point behind wrapping functions up in this is to
    separate the "pure" parts of a parsing function (such as
    converting a string to a number) from the other details, such as
    the current parser state and selection and order of parser
    functions, which we call the "structure" of a Parser. (This is
    probably the most difficult part of a monadic parser to
    understand.) We will later see the split between the functions
    that deal with parsing and the other functions that deal with
    these structural issues.
-}
newtype Parser a = Parser { parse :: ParserState -> (a, ParserState) }

{-  |
    This starts and completes a parse run by running a (top-level)
    'Parser a' on the given input, returning a value of type 'a'
    (typically the fully parsed AST) that it produces.

    To do this we need to build a new 'ParserState', feed that into
    the 'parse' function contained inside the 'Parser', and handle the
    result, which is the value of type 'a' the parser gives back and
    the final state.

    In a more sophisticated parser framework we'd want to check the
    final state to see if there are errors, unconsumed input, or the
    like and handle that appropriately. But here we just throw away
    the final state and return the result.
-}
runParser :: String     -- ^Input to be parsed
          -> Parser a   -- ^Parser to run on the input
          -> a          -- ^Giving this result
runParser s (Parser parse) =
    let initialState = PState { input = s }
        (x, _finalState) = parse initialState
     in x

{-  |
    Now comes the first "structural" part. We make our 'Parser' data
    type an instance of 'Functor'. An instance of Functor is an
    (extremely) generic "structure" of some sort, by which we mean
    just that a value of type @Functor a@ has some additional
    information beyond the "pure" value of type @a@ that's "contained
    in" the @Functor a@.

    Some examples:
    1. The optional type 'Maybe a' contains additional information
       about whether a pure value of type @a@ is present or not: a
       @Maybe Int@ can be @Just 42@ (present, and 42) or @Nothing@
       (absent).
    2. The list type '[a]' contains additional information about the
       number of values of type @a@ present (0, 1, 2, etc.) and the
       order of these values in relation to each other. A list of
       'Int' @[Int]@ could be empty (@[]@), one Int (@[3]@) or three
       Ints in a specific order (@[3, 1, 2]@).

    Every instance of Functor has an 'fmap' function that that takes a
    function that can operate on the pure value(s) "contained in" the
    structure of the functorial value and produces an identical
    structure where that function has been applied to the pure values
    "inside" in some appropriate way for that particular instance.

    Examples, where @f x = x + 1@:
    1. @fmap f@ on a @Maybe Int@ has two choices. If the value is
       @Just 3@, it can extract the @3@ and apply @f@ to it,
       afterwards re-enclosing the result @4@ into the structure as
       @Just 4@. If the value is @Nothing@, however, the special
       behaviour of 'Functor Maybe' is triggered, @f@ is not applied
       to anything, and @Nothing@ is the result produced.
    2. The behaviour of @fmap f@ on @[Int]@; is different because it
       must be particular to the list structure: it applies the
       function multiple times, once to each pure value inside the
       structure. Thus @fmap f [2,3]@ results in @[f 2,f 3]@.

    An important characteristic of 'fmap' is that, because the pure
    function passed to 'fmap' knows nothing about the structure,
    'fmap' can never change the structure. 'fmap' on a 'Maybe' may
    never change a @Just x@ to a @Nothing@ or vice versa becuase the
    pure function knows nothing about the presence or absence of an
    optional value; that's part of the structure that 'fmap never
    changes. Similarly, 'fmap' on a list may never change the length
    of a list because the pure function doesn't know anything about
    lengths; the length of a list is part of the list's structure, not
    connected to the pure values in the list.

    This is expressed in the following laws of 'fmap'. (If you are
    mathematically inclined you can prove that any 'fmap' function
    that follows these laws can never change the structure.)

    prop> fmap id  ==  id
    prop> fmap (f . g)  ==  fmap f . fmap g

    Unlike more sophisticated languages, Haskell cannot check these
    laws; we rely on the programmer to make sure that he writes a
    function that will never break them.

    In our case of 'Parser', the extra structure we add is the
    'ParserState' that we always send in to a parse function and
    retrieve (in possibly modified form) as part of the output. We
    provide an 'fmap' function that accepts a pure function (which
    knows nothing about this extra structure) and applies it to the
    result of a Parser, giving us a new Parser incorporating this pure
    function. Thus the type signature:

        @fmap :: (a -> b) -> Parser a -> Parser b@

    @(a -> b)@ is the pure function, @Parser a@ is the Parser
    producing the result to which we will apply this pure function,
    and @Parser b@ is a new parser incorporating this pure function.
    See the tests below for examples of how this works.
-}
instance Functor Parser where
    fmap :: (a -> b) -> Parser a -> Parser b
    fmap f (Parser parse) =
        Parser $                    -- 'fmap' gives back a new 'Parser b'
            \state ->               -- containing a function that takes a state
                let (x, state')     -- where we get back an 'a' and new state
                      = parse state -- from running the 'Parser a'
                 in (f x, state')   -- and put value a through 'f'

test_functor =
     do -- Running Parser 'give42' on any input always produces 42.
        assertEqual  42  (runParser "" give42)
        -- Running the Parser converted to give back a String produces "42".
        assertEqual "42" (runParser "" giveString)
    where
        -- | Parser that just gives the 'Int' 42, leaving the state unchanged.
        give42 :: Parser Int
        give42 = Parser $ \state -> (42, state)
        -- | Turn an 'Int' into its 'String' representation
        toString :: Int -> String
        toString x = show x
        -- | Use 'fmap' with 'toString' to convert the 'give42' parser
        --   into one that gives a String instead of an Int
        giveString = fmap toString give42

{-  |
    The next step towards a Monad is the 'Applicative' typeclass. This
    is actually a special kind of Functor (as evidenced by the fact
    that anything that is an 'Applicative' must also be a 'Functor')
    whose full name is "applicative functor." (Or, if you want to
    impress your friends, you can use the true mathematical name,
    "strong lax monoidal functor.")

    We won't speak too much here about how Applicative is used in
    programs (though some parsers work in just Applicative alone,
    without being Monads), but this is where the structure starts
    covering not just a single functorial value but the relationships
    between applicative functorial values.

    To be applicative we must offer two additional functions that
    bridge the world between pure values and functions and our
    structure.

    The first function is a very simple one: 'pure', which solves the
    problem of how we create a new structure "containing" a pure value
    or function. (This is generally called "lifting" into the
    structure, though the various functions that do this go by many
    names.)

    Examples:
    1. @pure 3@ on a @Maybe Int@ gives us @Just 3@.
    2. @pure 3@ on a a list of Int, @[Int]@, gives us @[3]@.

    This is much more restrictive than what we can do with the actual
    constructors for structure types; we cannot use 'pure' to create a
    'Nothing', an empty list, or a list of more than one value, all of
    these things being part of structure rather than pure values.
    There's no need to worry about the reasons for this in this
    application, though you will find out more about the reasons for
    this if you study further.

    In the case of our parser, 'pure' is quite simple: the pure value
    is what the parser gives back and the structure is a function that
    takes and returns a state, so we simply create a function that
    takes the state, and returns our pure value and the state. Thus,
    as shown in 'test_applicative_pure' (quite a ways below, for
    syntax reasons), using 'runParser' on that Parser should do
    nothing with the state and give back what was put in with 'pure'.
-}
instance Applicative Parser where

    pure :: a -> Parser a
    pure x = Parser $ \state -> (x, state)

    (<*>) :: Parser (a -> b) -> Parser a -> Parser b
    (Parser parseF) <*> (Parser parseX) =
        Parser $ \state ->
            let (f, state')  = parseF state
                (x, state'') = parseX state'
             in (f x, state'')

test_applicative_pure =
     do --  What we put in with pure, we get out
        assertEqual 13 (runParser "" (pure 13))

test_applicative_apply =
     do --  Lift function that doubles and apply to 3.
        assertEqual  6 (runParser "" $ pure (*2) <*> pure 3)
        --  Lift multiply and partially apply to 3, then apply to 5.
        assertEqual 15 (runParser "" $ pure (*) <*> pure 3 <*> pure 5)
