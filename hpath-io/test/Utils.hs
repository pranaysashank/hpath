{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE PackageImports #-}


module Utils where


import Control.Applicative
  (
    (<$>)
  )
import Control.Monad
  (
    forM_
  , void
  )
import Control.Monad.IfElse
  (
    whenM
  )
import qualified Data.ByteString as BS
import Data.IORef
  (
    newIORef
  , readIORef
  , writeIORef
  , IORef
  )
import HPath.IO
import Prelude hiding (appendFile, readFile, writeFile)
import Data.Maybe
  (
    fromJust
  )
import qualified HPath as P
import System.IO.Unsafe
  (
    unsafePerformIO
  )
import qualified System.Posix.Directory.Traversals as DT
import Data.ByteString
  (
    ByteString
  )
import qualified Data.ByteString.Lazy as L
import System.Posix.Files.ByteString
  (
    groupExecuteMode
  , groupReadMode
  , nullFileMode
  , otherExecuteMode
  , otherReadMode
  , ownerExecuteMode
  , ownerReadMode
  , setFileMode
  , unionFileModes
  )

baseTmpDir :: IORef (Maybe ByteString)
{-# NOINLINE baseTmpDir #-}
baseTmpDir = unsafePerformIO (newIORef Nothing)


tmpDir :: IORef (Maybe ByteString)
{-# NOINLINE tmpDir #-}
tmpDir = unsafePerformIO (newIORef Nothing)



    -----------------
    --[ Utilities ]--
    -----------------


setTmpDir :: ByteString -> IO ()
{-# NOINLINE setTmpDir #-}
setTmpDir bs = do
  tmp <- fromJust <$> readIORef baseTmpDir
  writeIORef tmpDir (Just (tmp `BS.append` bs))


createTmpDir :: IO ()
{-# NOINLINE createTmpDir #-}
createTmpDir = do
  tmp <- P.parseAbs =<< (fromJust <$> readIORef tmpDir)
  void $ createDir newDirPerms tmp


deleteTmpDir :: IO ()
{-# NOINLINE deleteTmpDir #-}
deleteTmpDir = do
  tmp <- P.parseAbs  =<< (fromJust <$> readIORef tmpDir)
  void $ deleteDir tmp


deleteBaseTmpDir :: IO ()
{-# NOINLINE deleteBaseTmpDir #-}
deleteBaseTmpDir = do
  tmp <- (fromJust <$> readIORef baseTmpDir) >>= P.parseAbs
  contents <- getDirsFiles tmp
  forM_ contents deleteDir
  void $ deleteDir tmp


withRawTmpDir :: (P.Path P.Abs -> IO a) -> IO a
{-# NOINLINE withRawTmpDir #-}
withRawTmpDir f = do
  tmp <- P.parseAbs =<< (fromJust <$> readIORef tmpDir)
  f tmp


getRawTmpDir :: IO ByteString
{-# NOINLINE getRawTmpDir #-}
getRawTmpDir = withRawTmpDir (return . flip BS.append "/" . P.fromAbs)


withTmpDir :: ByteString -> (P.Path P.Abs -> IO a) -> IO a
{-# NOINLINE withTmpDir #-}
withTmpDir ip f = do
  tmp <- P.parseAbs =<< (fromJust <$> readIORef tmpDir)
  p <- (tmp P.</>) <$> P.parseRel ip
  f p


withTmpDir' :: ByteString
            -> ByteString
            -> (P.Path P.Abs -> P.Path P.Abs -> IO a)
            -> IO a
{-# NOINLINE withTmpDir' #-}
withTmpDir' ip1 ip2 f = do
  tmp <- P.parseAbs =<< (fromJust <$> readIORef tmpDir)
  p1 <- (tmp P.</>) <$> P.parseRel ip1
  p2 <- (tmp P.</>) <$> P.parseRel ip2
  f p1 p2


removeFileIfExists :: ByteString -> IO ()
{-# NOINLINE removeFileIfExists #-}
removeFileIfExists bs =
  withTmpDir bs $ \p -> whenM (doesFileExist p) (deleteFile p)


removeDirIfExists :: ByteString -> IO ()
{-# NOINLINE removeDirIfExists #-}
removeDirIfExists bs =
  withTmpDir bs $ \p -> whenM (doesDirectoryExist p) (deleteDirRecursive p)


copyFile' :: ByteString -> ByteString -> CopyMode -> IO ()
{-# NOINLINE copyFile' #-}
copyFile' inputFileP outputFileP cm =
  withTmpDir' inputFileP outputFileP (\p1 p2 -> copyFile p1 p2 cm)


copyDirRecursive' :: ByteString -> ByteString
                  -> CopyMode -> RecursiveErrorMode -> IO ()
{-# NOINLINE copyDirRecursive' #-}
copyDirRecursive' inputDirP outputDirP cm rm =
  withTmpDir' inputDirP outputDirP (\p1 p2 -> copyDirRecursive p1 p2 cm rm)


createDir' :: ByteString -> IO ()
{-# NOINLINE createDir' #-}
createDir' dest = withTmpDir dest (createDir newDirPerms)

createDirRecursive' :: ByteString -> IO ()
{-# NOINLINE createDirRecursive' #-}
createDirRecursive' dest = withTmpDir dest (createDirRecursive newDirPerms)

createRegularFile' :: ByteString -> IO ()
{-# NOINLINE createRegularFile' #-}
createRegularFile' dest = withTmpDir dest (createRegularFile newFilePerms)


createSymlink' :: ByteString -> ByteString -> IO ()
{-# NOINLINE createSymlink' #-}
createSymlink' dest sympoint = withTmpDir dest
  (\x -> createSymlink x sympoint)


renameFile' :: ByteString -> ByteString -> IO ()
{-# NOINLINE renameFile' #-}
renameFile' inputFileP outputFileP =
  withTmpDir' inputFileP outputFileP $ \i o -> do
    renameFile i o
    renameFile o i


moveFile' :: ByteString -> ByteString -> CopyMode -> IO ()
{-# NOINLINE moveFile' #-}
moveFile' inputFileP outputFileP cm =
  withTmpDir' inputFileP outputFileP $ \i o -> do
    moveFile i o cm
    moveFile o i Strict


recreateSymlink' :: ByteString -> ByteString -> CopyMode -> IO ()
{-# NOINLINE recreateSymlink' #-}
recreateSymlink' inputFileP outputFileP cm =
  withTmpDir' inputFileP outputFileP (\p1 p2 -> recreateSymlink p1 p2 cm)


noWritableDirPerms :: ByteString -> IO ()
{-# NOINLINE noWritableDirPerms #-}
noWritableDirPerms path = withTmpDir path $ \p ->
  setFileMode (P.fromAbs p) perms
  where
    perms =            ownerReadMode
      `unionFileModes` ownerExecuteMode
      `unionFileModes` groupReadMode
      `unionFileModes` groupExecuteMode
      `unionFileModes` otherReadMode
      `unionFileModes` otherExecuteMode


noPerms :: ByteString -> IO ()
{-# NOINLINE noPerms #-}
noPerms path = withTmpDir path $ \p -> setFileMode (P.fromAbs p) nullFileMode


normalDirPerms :: ByteString -> IO ()
{-# NOINLINE normalDirPerms #-}
normalDirPerms path =
  withTmpDir path $ \p -> setFileMode (P.fromAbs p) newDirPerms


normalFilePerms :: ByteString -> IO ()
{-# NOINLINE normalFilePerms #-}
normalFilePerms path =
  withTmpDir path $ \p -> setFileMode (P.fromAbs p) newFilePerms


getFileType' :: ByteString -> IO FileType
{-# NOINLINE getFileType' #-}
getFileType' path = withTmpDir path getFileType


getDirsFiles' :: ByteString -> IO [P.Path P.Abs]
{-# NOINLINE getDirsFiles' #-}
getDirsFiles' path = withTmpDir path getDirsFiles


deleteFile' :: ByteString -> IO ()
{-# NOINLINE deleteFile' #-}
deleteFile' p = withTmpDir p deleteFile


deleteDir' :: ByteString -> IO ()
{-# NOINLINE deleteDir' #-}
deleteDir' p = withTmpDir p deleteDir


deleteDirRecursive' :: ByteString -> IO ()
{-# NOINLINE deleteDirRecursive' #-}
deleteDirRecursive' p = withTmpDir p deleteDirRecursive


canonicalizePath' :: ByteString -> IO (P.Path P.Abs)
{-# NOINLINE canonicalizePath' #-}
canonicalizePath' p = withTmpDir p canonicalizePath


writeFile' :: ByteString -> ByteString -> IO ()
{-# NOINLINE writeFile' #-}
writeFile' ip bs = 
  withTmpDir ip $ \p -> writeFile p bs


appendFile' :: ByteString -> ByteString -> IO ()
{-# NOINLINE appendFile' #-}
appendFile' ip bs =
  withTmpDir ip $ \p -> appendFile p bs


allDirectoryContents' :: ByteString -> IO [ByteString]
{-# NOINLINE allDirectoryContents' #-}
allDirectoryContents' ip =
  withTmpDir ip $ \p -> DT.allDirectoryContents' (P.fromAbs p)


readFile' :: ByteString -> IO ByteString
{-# NOINLINE readFile' #-}
readFile' p = withTmpDir p (fmap L.toStrict . readFile)

