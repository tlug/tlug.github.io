{-
    MediaWiki transclusion, magic words, and other {{...}} syntax is
    documented not terribly well at:
        https://en.wikipedia.org/wiki/Wikipedia:Transclusion
        https://www.mediawiki.org/wiki/Transclusion

    Transcludes appear to be done before parsing the markup, so the
    parsing is done on a complete page that's the concatenation of the
    transcluded markup and intervening markup from the original page.

    Summary:
    - {{Foo:Bar}}: Substitute contents of `Templates:Foo:Bar` page.
    - {{:Foo:Bar}}: Substitute contents of `Foo:Bar` page.
    - {{Foo|baz|quux}}: Subsitute with positional parameters `baz` and `quux`.
    - {{Foo|foo=bar}}: Substitute with named parameter `foo` valued `bar`.
    - {{Foo Bar|a pos param|named param=other text}}: Spaces in names/params.

    "Magic words" look the same but are distinguished by being somehow
    defined as such, and use a colon to start the arguments:
    - {{FULLPAGENAME}}
    - {{FULLPAGENAME:A different name}}
    - {{subst:OtherPage}}

    Some magic words have templates that call the magic word:
    - {{FULLPAGENAME|A different name}}

    Tags affecting transclusion:
    - <noinclude>:   Not rendered when transcluded.
    - <onlyinclude>: Everything but this rendered when transcluded.
    - <includeonly>: Don't even ask.

    There's much more; hopefully we won't need to handle too much of
    it for the TLUG pages.
-}
module TLUG.MediaWiki
    ( Page, Chunk(..)
    , parsePage
    , runParser, char, readNothingGiveInt,
    ) where

type Page = [Chunk]

type ParamList = [(String,String)]
data Chunk
    = Markup String
    | Transclude
      { pageName :: String
      , params   :: ParamList
      }
    deriving (Show, Eq)

parsePage :: String -> Page
parsePage s = runParser chunks s

data ParserState = ParserState
    { remaining :: String
    }
newtype Parser a = Parser (ParserState -> (a, ParserState))

doParse :: Parser a -> ParserState -> (a, ParserState)
doParse (Parser f) s = f s

instance Functor Parser where
    -- fmap :: (a -> b) -> Parser a -> Parser b
    fmap abFunc aParser = Parser (
        \aState -> let (aResult, bState) = doParse aParser aState in
            (abFunc aResult, bState)
        )

instance Applicative Parser where
    -- pure :: a -> Parser a
    pure x = Parser $ \state -> (x, state)
    -- <*> :: Parser (a -> b) -> Parser a -> Parser b
    (<*>) abParser aParser = Parser (
        \aState -> let (abFunc, bState) = doParse abParser aState in
            doParse (fmap abFunc aParser) bState
        )

instance Monad Parser where
    -- Parser a -> (a -> Parser b) -> Parser b
    --   Is above type correct?
    --   Below, where do we get an `a` to feed to `f`?
    --   And how do we get the `b` out to return?
    -- (Parser pf) >>= f = Parser $ \state -> (?b?, state)
    (>>=) = error "Write (>>=)!"

    -- (>>) :: Parser a -> Parser b -> Parser b

runParser :: Parser a -> String -> a
runParser (Parser f) s =
    case f (ParserState s) of
        (x, ParserState "")  -> x
        otherwise            -> error "Incomplete parse"

-- Just for a test? Maybe we don't really need this.
char :: Parser Char
char = Parser (\state ->
            case (remaining state) of
                ""       -> error "Unexpected EOF!"
                (c:cs)   -> (c, ParserState cs)
              )

readNothingGiveInt :: Parser Int
readNothingGiveInt = return 17

chunks :: Parser [Chunk]
chunks = do
    nthng <- nothing
    chunks <- many chunk
    return chunks

nothing :: Parser ()
nothing = return ()

many :: Parser a -> Parser [a]
many = undefined

chunk :: Parser Chunk
chunk = undefined

type MarkupAcc = String
type Remainder = String

parseMarkup :: MarkupAcc -> Remainder -> [Chunk]
parseMarkup acc rem = parseMarkup' acc rem
    where
        parseMarkup' :: MarkupAcc -> Remainder -> [Chunk]
        parseMarkup' acc [] = [unaccumulate acc]
        parseMarkup' acc ('{':'{':xs) = unaccumulate acc : parseTransclude "" xs
        parseMarkup' acc (x:xs) = parseMarkup' (x:acc) xs
        unaccumulate acc = Markup $ reverse acc

parseTransclude :: String -> Remainder -> [Chunk]
parseTransclude acc ('}':'}':xs) = Transclude (reverse acc) [] : parseMarkup "" xs
parseTransclude acc ('|':xs) =
    let (args,remainder) = parseTranscludeArgs xs
     in Transclude (reverse acc) args : remainder
parseTransclude acc (x:xs) = parseTransclude (x:acc) xs
parseTransclude acc [] = [Transclude (reverse acc) []]

parseTranscludeArgs :: Remainder -> (ParamList, [Chunk])
parseTranscludeArgs ('}':'}':xs) = ([], parseMarkup "" xs)
parseTranscludeArgs (x:xs) = parseTranscludeArgs xs
parseTranscludeArgs [] = ([], [])
