{-# LANGUAGE OverloadedStrings #-}

module HPath.IO.CreateDirSpec where


import Test.Hspec
import System.IO.Error
  (
    ioeGetErrorType
  )
import GHC.IO.Exception
  (
    IOErrorType(..)
  )
import Utils
import qualified Data.ByteString as BS
import           Data.ByteString.UTF8 (toString)


setupFiles :: IO ()
setupFiles = do
  createDir' "alreadyExists"
  createDir' "noPerms"
  createDir' "noWritePerms"
  noPerms "noPerms"
  noWritableDirPerms "noWritePerms"



cleanupFiles :: IO ()
cleanupFiles = do
  normalDirPerms "noPerms"
  normalDirPerms "noWritePerms"
  deleteDir' "alreadyExists"
  deleteDir' "noPerms"
  deleteDir' "noWritePerms"


spec :: Spec
spec = before_ setupFiles $ after_ cleanupFiles $
  describe "HPath.IO.createDir" $ do

    -- successes --
    it "createDir, all fine" $ do
      createDir' "newDir"
      removeDirIfExists "newDir"

    -- posix failures --
    it "createDir, can't write to output directory" $
      createDir' "noWritePerms/newDir"
        `shouldThrow`
        (\e -> ioeGetErrorType e == PermissionDenied)

    it "createDir, can't open output directory" $
      createDir' "noPerms/newDir"
        `shouldThrow`
        (\e -> ioeGetErrorType e == PermissionDenied)

    it "createDir, destination directory already exists" $
      createDir' "alreadyExists"
        `shouldThrow`
        (\e -> ioeGetErrorType e == AlreadyExists)

