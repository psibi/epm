-----------------------------------------------------------------------------
-- |
-- Module      :  Distribution.Simple.Program.Builtin
-- Copyright   :  Isaac Jones 2006, Duncan Coutts 2007-2009
--
-- Maintainer  :  cabal-devel@haskell.org
-- Portability :  portable
--
-- The module defines all the known built-in 'Program's.
--
-- Where possible we try to find their version numbers.
--
module Distribution.Simple.Program.Builtin (

    -- * The collection of unconfigured and configured programs
    builtinPrograms,

    -- * Programs that Cabal knows about
    ghcProgram,
    ghcPkgProgram,
    ghcjsProgram,
    ghcjsPkgProgram,
    etaProgram,
    javaProgram,
    javacProgram,
    gitProgram,
    etaPkgProgram,
    lhcProgram,
    lhcPkgProgram,
    hmakeProgram,
    jhcProgram,
    haskellSuiteProgram,
    haskellSuitePkgProgram,
    uhcProgram,
    gccProgram,
    arProgram,
    stripProgram,
    happyProgram,
    alexProgram,
    hsc2hsProgram,
    c2hsProgram,
    cpphsProgram,
    hscolourProgram,
    haddockProgram,
    greencardProgram,
    ldProgram,
    tarProgram,
    cppProgram,
    pkgConfigProgram,
    hpcProgram,
  ) where

import Distribution.Simple.Program.Find
         ( findProgramOnSearchPath )
import Distribution.Simple.Program.Run
         ( getProgramInvocationOutput, programInvocation )
import Distribution.Simple.Program.Types
         ( Program(..), ConfiguredProgram(..), ProgramSearchPath
         , ProgramSearchPathEntry(..), simpleProgram )
import Distribution.Simple.Utils
         ( findProgramVersion )
import Distribution.Compat.Exception
         ( catchIO )
import Distribution.Verbosity
         ( Verbosity, lessVerbose )
import Distribution.Version
         ( Version(..), withinRange, earlierVersion, laterVersion
         , intersectVersionRanges )
import Data.Char
         ( isDigit )

import Data.List
         ( isInfixOf )
import qualified Data.Map as Map
import System.Environment
         ( lookupEnv )
import System.FilePath
         ( (</>) )

-- ------------------------------------------------------------
-- * Known programs
-- ------------------------------------------------------------

-- | The default list of programs.
-- These programs are typically used internally to Cabal.
builtinPrograms :: [Program]
builtinPrograms =
    [
    -- compilers and related progs
      ghcProgram
    , ghcPkgProgram
    , ghcjsProgram
    , ghcjsPkgProgram
    , etaProgram
    , etaPkgProgram
    , haskellSuiteProgram
    , haskellSuitePkgProgram
    , hmakeProgram
    , jhcProgram
    , lhcProgram
    , lhcPkgProgram
    , uhcProgram
    , hpcProgram
    -- preprocessors
    , hscolourProgram
    , haddockProgram
    , happyProgram
    , alexProgram
    , hsc2hsProgram
    , c2hsProgram
    , cpphsProgram
    , greencardProgram
    -- platform toolchain
    , gccProgram
    , arProgram
    , stripProgram
    , ldProgram
    , tarProgram
    -- configuration tools
    , pkgConfigProgram
    -- ETA-specific tools
    , javaProgram
    , javacProgram
    , gitProgram
    ]

ghcProgram :: Program
ghcProgram = (simpleProgram "ghc") {
    programFindVersion = findProgramVersion "--numeric-version" id,

    -- Workaround for https://ghc.haskell.org/trac/ghc/ticket/8825
    -- (spurious warning on non-english locales)
    programPostConf    = \_verbosity ghcProg ->
    do let ghcProg' = ghcProg {
             programOverrideEnv = ("LANGUAGE", Just "en")
                                  : programOverrideEnv ghcProg
             }
           -- Only the 7.8 branch seems to be affected. Fixed in 7.8.4.
           affectedVersionRange = intersectVersionRanges
                                  (laterVersion   $ Version [7,8,0] [])
                                  (earlierVersion $ Version [7,8,4] [])
       return $ maybe ghcProg
         (\v -> if withinRange v affectedVersionRange
                then ghcProg' else ghcProg)
         (programVersion ghcProg)
  }

ghcPkgProgram :: Program
ghcPkgProgram = (simpleProgram "ghc-pkg") {
    programFindVersion = findProgramVersion "--version" $ \str ->
      -- Invoking "ghc-pkg --version" gives a string like
      -- "GHC package manager version 6.4.1"
      case words str of
        (_:_:_:_:ver:_) -> ver
        _               -> ""
  }

ghcjsProgram :: Program
ghcjsProgram = (simpleProgram "ghcjs") {
    programFindVersion = findProgramVersion "--numeric-ghcjs-version" id
  }

-- note: version is the version number of the GHC version that ghcjs-pkg was built with
ghcjsPkgProgram :: Program
ghcjsPkgProgram = (simpleProgram "ghcjs-pkg") {
    programFindVersion = findProgramVersion "--version" $ \str ->
      -- Invoking "ghcjs-pkg --version" gives a string like
      -- "GHCJS package manager version 6.4.1"
      case words str of
        (_:_:_:_:ver:_) -> ver
        _               -> ""
  }

etaProgram :: Program
etaProgram = (simpleProgram "eta") {
    programFindVersion = findProgramVersion "--numeric-version" id
  }

-- TODO: Clean this up
underscoreToDot = map (\c -> if c == '_' then '.' else c)

findProgramInJavaHomeOrSearchPath :: String
                                  -> Verbosity
                                  -> ProgramSearchPath
                                  -> IO (Maybe FilePath)
findProgramInJavaHomeOrSearchPath name verbosity searchPath = do
  mJavaHome <- lookupEnv "JAVA_HOME"
  case mJavaHome of
    Just javaHome ->
      let
        bin         = javaHome </> "bin"
        searchPath' = ProgramSearchPathDir bin : searchPath
      in findProgramOnSearchPath verbosity searchPath' name
    Nothing ->
      findProgramOnSearchPath verbosity searchPath name

javaProgram :: Program
javaProgram = (simpleProgram "java") {
    programFindLocation = \v p -> findProgramInJavaHomeOrSearchPath "java" v p
  , programFindVersion = findProgramVersion "-version" $ \str ->
        -- Invoking "java -version" gives a string like
        -- "java version \"1.7.0_79\""
        case lines str of
          (l:_)
            | (_:_:quotedVersion:_) <- words l -> underscoreToDot $ drop 1 (init quotedVersion)
          _ -> ""
  }

javacProgram :: Program
javacProgram = (simpleProgram "javac") {
    programFindLocation = \v p -> findProgramInJavaHomeOrSearchPath "javac" v p
  , programFindVersion = findProgramVersion "-version" $ \str ->
        -- Invoking "javac -version" gives a string like
        -- "javac 1.7.0_79"
        case words str of
          (_:version:_) -> underscoreToDot version
          _             -> ""
  }

gitProgram :: Program
gitProgram = (simpleProgram "git") {
    programFindVersion = findProgramVersion "--version" $ \str ->
        -- Invoking "git --version" gives a string like
        --- "git version 2.7.4 (Apple Git-66)"
        let split cs = case break (=='.') cs of
              (chunk,[])     -> chunk : []
              (chunk,_:rest) -> chunk : split rest
            join [s] = s
            join (s:ss) = s ++ ('.' : join ss)
        in case words str of
          (_:_:version:_) -> join . take 3 $ split version
          _               -> ""
  }

-- note: version is the version number of the GHC version that eta-pkg was built with
etaPkgProgram :: Program
etaPkgProgram = (simpleProgram "eta-pkg") {
    programFindVersion = findProgramVersion "--version" $ \str ->
      -- Invoking "eta-pkg --version" gives a string like
      -- "ETA package manager version 0.0.1"
      case words str of
        (_:_:_:_:ver:_) -> ver
        _               -> ""
  }

lhcProgram :: Program
lhcProgram = (simpleProgram "lhc") {
    programFindVersion = findProgramVersion "--numeric-version" id
  }

lhcPkgProgram :: Program
lhcPkgProgram = (simpleProgram "lhc-pkg") {
    programFindVersion = findProgramVersion "--version" $ \str ->
      -- Invoking "lhc-pkg --version" gives a string like
      -- "LHC package manager version 0.7"
      case words str of
        (_:_:_:_:ver:_) -> ver
        _               -> ""
  }

hmakeProgram :: Program
hmakeProgram = (simpleProgram "hmake") {
    programFindVersion = findProgramVersion "--version" $ \str ->
    -- Invoking "hmake --version" gives a string line
    -- "/usr/local/bin/hmake: 3.13 (2006-11-01)"
      case words str of
        (_:ver:_) -> ver
        _         -> ""
  }

jhcProgram :: Program
jhcProgram = (simpleProgram "jhc") {
    programFindVersion = findProgramVersion "--version" $ \str ->
    -- invoking "jhc --version" gives a string like
    -- "jhc 0.3.20080208 (wubgipkamcep-2)
    -- compiled by ghc-6.8 on a x86_64 running linux"
      case words str of
        (_:ver:_) -> ver
        _         -> ""
  }

uhcProgram :: Program
uhcProgram = (simpleProgram "uhc") {
    programFindVersion = findProgramVersion "--version-dotted" id
  }

hpcProgram :: Program
hpcProgram = (simpleProgram "hpc")
    {
        programFindVersion = findProgramVersion "version" $ \str ->
            case words str of
                (_ : _ : _ : ver : _) -> ver
                _ -> ""
    }

-- This represents a haskell-suite compiler. Of course, the compiler
-- itself probably is not called "haskell-suite", so this is not a real
-- program. (But we don't know statically the name of the actual compiler,
-- so this is the best we can do.)
--
-- Having this Program value serves two purposes:
--
-- 1. We can accept options for the compiler in the form of
--
--   --haskell-suite-option(s)=...
--
-- 2. We can find a program later using this static id (with
-- requireProgram).
--
-- The path to the real compiler is found and recorded in the ProgramDb
-- during the configure phase.
haskellSuiteProgram :: Program
haskellSuiteProgram = (simpleProgram "haskell-suite") {
    -- pretend that the program exists, otherwise it won't be in the
    -- "configured" state
    programFindLocation =
      \_verbosity _searchPath -> return $ Just "haskell-suite-dummy-location"
  }

-- This represent a haskell-suite package manager. See the comments for
-- haskellSuiteProgram.
haskellSuitePkgProgram :: Program
haskellSuitePkgProgram = (simpleProgram "haskell-suite-pkg") {
    programFindLocation =
      \_verbosity _searchPath -> return $ Just "haskell-suite-pkg-dummy-location"
  }


happyProgram :: Program
happyProgram = (simpleProgram "happy") {
    programFindVersion = findProgramVersion "--version" $ \str ->
      -- Invoking "happy --version" gives a string like
      -- "Happy Version 1.16 Copyright (c) ...."
      case words str of
        (_:_:ver:_) -> ver
        _           -> ""
  }

alexProgram :: Program
alexProgram = (simpleProgram "alex") {
    programFindVersion = findProgramVersion "--version" $ \str ->
      -- Invoking "alex --version" gives a string like
      -- "Alex version 2.1.0, (c) 2003 Chris Dornan and Simon Marlow"
      case words str of
        (_:_:ver:_) -> takeWhile (\x -> isDigit x || x == '.') ver
        _           -> ""
  }

gccProgram :: Program
gccProgram = (simpleProgram "gcc") {
    programFindVersion = findProgramVersion "-dumpversion" id
  }

arProgram :: Program
arProgram = simpleProgram "ar"

stripProgram :: Program
stripProgram = (simpleProgram "strip") {
    programFindVersion = \verbosity ->
      findProgramVersion "--version" selectVersion (lessVerbose verbosity)
  }
  where
    selectVersion str =
      -- Invoking "strip --version" gives very inconsistent
      -- results. We look for the first word that starts with a
      -- number, and try parsing out the first two components of
      -- it. Non-GNU 'strip' doesn't appear to have a version flag.
      let numeric ""    = False
          numeric (x:_) = isDigit x
      in case dropWhile (not . numeric) (words str) of
        (ver:_) ->
          -- take the first two version components
          let isDot         = (== '.')
              (major, rest) = break isDot ver
              minor         = takeWhile (not . isDot) (dropWhile isDot rest)
          in major ++ "." ++ minor
        _ -> ""

hsc2hsProgram :: Program
hsc2hsProgram = (simpleProgram "hsc2hs") {
    programFindVersion =
      findProgramVersion "--version" $ \str ->
        -- Invoking "hsc2hs --version" gives a string like "hsc2hs version 0.66"
        case words str of
          (_:_:ver:_) -> ver
          _           -> ""
  }

c2hsProgram :: Program
c2hsProgram = (simpleProgram "c2hs") {
    programFindVersion = findProgramVersion "--numeric-version" id
  }

cpphsProgram :: Program
cpphsProgram = (simpleProgram "cpphs") {
    programFindVersion = findProgramVersion "--version" $ \str ->
      -- Invoking "cpphs --version" gives a string like "cpphs 1.3"
      case words str of
        (_:ver:_) -> ver
        _         -> ""
  }

hscolourProgram :: Program
hscolourProgram = (simpleProgram "hscolour") {
    programFindLocation = \v p -> findProgramOnSearchPath v p "HsColour",
    programFindVersion  = findProgramVersion "-version" $ \str ->
      -- Invoking "HsColour -version" gives a string like "HsColour 1.7"
      case words str of
        (_:ver:_) -> ver
        _         -> ""
  }

haddockProgram :: Program
haddockProgram = (simpleProgram "haddock") {
    programFindVersion = findProgramVersion "--version" $ \str ->
      -- Invoking "haddock --version" gives a string like
      -- "Haddock version 0.8, (c) Simon Marlow 2006"
      case words str of
        (_:_:ver:_) -> takeWhile (`elem` ('.':['0'..'9'])) ver
        _           -> ""
  }

greencardProgram :: Program
greencardProgram = simpleProgram "greencard"

ldProgram :: Program
ldProgram = simpleProgram "ld"

tarProgram :: Program
tarProgram = (simpleProgram "tar") {
  -- See #1901. Some versions of 'tar' (OpenBSD, NetBSD, ...) don't support the
  -- '--format' option.
  programPostConf = \verbosity tarProg -> do
     tarHelpOutput <- getProgramInvocationOutput
                      verbosity (programInvocation tarProg ["--help"])
                      -- Some versions of tar don't support '--help'.
                      `catchIO` (\_ -> return "")
     let k = "Supports --format"
         v = if ("--format" `isInfixOf` tarHelpOutput) then "YES" else "NO"
         m = Map.insert k v (programProperties tarProg)
     return $ tarProg { programProperties = m }
  }

cppProgram :: Program
cppProgram = simpleProgram "cpp"

pkgConfigProgram :: Program
pkgConfigProgram = (simpleProgram "pkg-config") {
    programFindVersion = findProgramVersion "--version" id
  }
