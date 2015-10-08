--------------------------------------------------------------------------------
{-# LANGUAGE OverloadedStrings #-}
import           Data.Monoid (mappend)
import           Hakyll
import           System.FilePath.Posix  (takeBaseName, takeDirectory,
                                         (</>), takeFileName)
import           Data.List              (isSuffixOf, isPrefixOf, isInfixOf,
                                         intercalate, sort)

--------------------------------------------------------------------------------
archiveTemplate  = "templates/archive.html"
centeredTemplate = "templates/centered.html"
postTemplate     = "templates/post.html"
defaultTemplate  = "templates/default.html"

main :: IO ()
main = hakyll $ do
    match "images/*" $ do
        route   idRoute
        compile copyFileCompiler

    match "css/*" $ do
        route   idRoute
        compile compressCssCompiler

    match "js/*" $ do
        route   idRoute
        compile copyFileCompiler

    match (fromList ["about.rst", "contact.md"]) $ do
        route   $ cleanRoute
        compile $ pandocCompiler
            >>= loadAndApplyTemplate centeredTemplate defaultContext
            >>= loadAndApplyTemplate defaultTemplate defaultContext
            >>= relativizeUrls
            >>= cleanIndexUrls

    match "posts/*" $ do
        route $ cleanRoute
        compile $ pandocCompiler
            >>= loadAndApplyTemplate postTemplate    postCtx
            >>= loadAndApplyTemplate defaultTemplate postCtx
            >>= relativizeUrls
            >>= cleanIndexUrls

    create ["archive.html"] $ do
        route   $ cleanRoute
        compile $ do
            posts <- recentFirst =<< loadAll "posts/*"
            let archiveCtx =
                    listField "posts" postCtx (return posts) `mappend`
                    constField "title" "Archives"            `mappend`
                    defaultContext

            makeItem ""
                >>= loadAndApplyTemplate archiveTemplate archiveCtx
                >>= loadAndApplyTemplate defaultTemplate archiveCtx
                >>= relativizeUrls
                >>= cleanIndexUrls


    match "index.md" $ do
        route   $ setExtension "html"
        compile $ do
            posts <- recentFirst =<< loadAll "posts/*"
            let indexCtx =
                    listField "posts" postCtx (return posts) `mappend`
                    defaultContext

            pandocCompiler
                >>= applyAsTemplate indexCtx
                >>= loadAndApplyTemplate centeredTemplate indexCtx
                >>= loadAndApplyTemplate defaultTemplate indexCtx
                >>= relativizeUrls
                >>= cleanIndexUrls

    match "templates/*" $ compile templateCompiler


--------------------------------------------------------------------------------
postCtx :: Context String
postCtx =
    dateField "date" "%B %e, %Y" `mappend`
    defaultContext

-- Folder with index.html in them
cleanRoute :: Routes
cleanRoute = customRoute createIndexRoute
  where
    createIndexRoute ident = takeDirectory p </> takeBaseName p </> "index.html"
                           where p = toFilePath ident

cleanIndexUrls :: Item String -> Compiler (Item String)
cleanIndexUrls = return . fmap (withUrls cleanIndex)

cleanIndexHtmls :: Item String -> Compiler (Item String)
cleanIndexHtmls = return . fmap (replaceAll pattern replacement)
    where
      pattern = "/index.html"
      replacement = const "/"

cleanIndex :: String -> String
cleanIndex url
    | idx `isSuffixOf` url = take (length url - length idx) url
    | otherwise            = url
    where idx = "index.html"
