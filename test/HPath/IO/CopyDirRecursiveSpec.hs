{-# LANGUAGE OverloadedStrings #-}


module HPath.IO.CopyDirRecursiveSpec where


import Test.Hspec
import HPath.IO.Errors
import System.IO.Error
  (
    ioeGetErrorType
  )
import GHC.IO.Exception
  (
    IOErrorType(..)
  )
import System.Exit
import System.Process
import Utils
import qualified Data.ByteString as BS
import           Data.ByteString.UTF8 (toString)





setupFiles :: IO ()
setupFiles = do
  createRegularFile' "alreadyExists"
  createRegularFile' "wrongInput"
  createSymlink' "wrongInputSymL" "inputDir/"
  createDir' "alreadyExistsD"
  createDir' "noPerms"
  createDir' "noWritePerm"

  createDir' "inputDir"
  createDir' "inputDir/bar"
  createDir' "inputDir/foo"
  createRegularFile' "inputDir/foo/inputFile1"
  createRegularFile' "inputDir/inputFile2"
  createRegularFile' "inputDir/bar/inputFile3"
  writeFile' "inputDir/foo/inputFile1" "SDAADSdsada"
  writeFile' "inputDir/inputFile2" "Blahfaselgagaga"
  writeFile' "inputDir/bar/inputFile3"
    "fdfdssdffsd3223sasdasdasdadasasddasdasdasasd4"

  noPerms "noPerms"
  noWritableDirPerms "noWritePerm"


cleanupFiles :: IO ()
cleanupFiles = do
  normalDirPerms "noPerms"
  normalDirPerms "noWritePerm"
  deleteFile' "alreadyExists"
  deleteFile' "wrongInput"
  deleteFile' "wrongInputSymL"
  deleteDir' "alreadyExistsD"
  deleteDir' "noPerms"
  deleteDir' "noWritePerm"
  deleteFile' "inputDir/foo/inputFile1"
  deleteFile' "inputDir/inputFile2"
  deleteFile' "inputDir/bar/inputFile3"
  deleteDir' "inputDir/foo"
  deleteDir' "inputDir/bar"
  deleteDir' "inputDir"




spec :: Spec
spec = before_ setupFiles $ after_ cleanupFiles $
  describe "HPath.IO.copyDirRecursive" $ do

    -- successes --
    it "copyDirRecursive, all fine" $ do
      copyDirRecursive' "inputDir"
                        "outputDir"
      removeDirIfExists "outputDir"

    it "copyDirRecursive, all fine and compare" $ do
      copyDirRecursive' "inputDir"
                        "outputDir"
      (system $ "diff -r --no-dereference "
                          ++ toString tmpDir ++ "inputDir" ++ " "
                          ++ toString tmpDir ++ "outputDir")
        `shouldReturn` ExitSuccess
      removeDirIfExists "outputDir"

    -- posix failures --
    it "copyDirRecursive, source directory does not exist" $
      copyDirRecursive' "doesNotExist"
                        "outputDir"
        `shouldThrow`
        (\e -> ioeGetErrorType e == NoSuchThing)

    it "copyDirRecursive, no write permission on output dir" $
      copyDirRecursive' "inputDir"
                        "noWritePerm/foo"
        `shouldThrow`
        (\e -> ioeGetErrorType e == PermissionDenied)

    it "copyDirRecursive, cannot open output dir" $
      copyDirRecursive' "inputDir"
                        "noPerms/foo"
        `shouldThrow`
        (\e -> ioeGetErrorType e == PermissionDenied)

    it "copyDirRecursive, cannot open source dir" $
      copyDirRecursive' "noPerms/inputDir"
                        "foo"
        `shouldThrow`
        (\e -> ioeGetErrorType e == PermissionDenied)

    it "copyDirRecursive, destination dir already exists" $
      copyDirRecursive' "inputDir"
                        "alreadyExistsD"
        `shouldThrow`
        (\e -> ioeGetErrorType e == AlreadyExists)

    it "copyDirRecursive, destination already exists and is a file" $
      copyDirRecursive' "inputDir"
                        "alreadyExists"
        `shouldThrow`
        (\e -> ioeGetErrorType e == AlreadyExists)

    it "copyDirRecursive, wrong input (regular file)" $
      copyDirRecursive' "wrongInput"
                        "outputDir"
        `shouldThrow`
        (\e -> ioeGetErrorType e == InappropriateType)

    it "copyDirRecursive, wrong input (symlink to directory)" $
      copyDirRecursive' "wrongInputSymL"
                        "outputDir"
        `shouldThrow`
        (\e -> ioeGetErrorType e == InvalidArgument)

    -- custom failures
    it "copyDirRecursive, destination in source" $
      copyDirRecursive' "inputDir"
                        "inputDir/foo"
        `shouldThrow`
        isDestinationInSource

    it "copyDirRecursive, destination and source same directory" $
      copyDirRecursive' "inputDir"
                        "inputDir"
        `shouldThrow`
        isSameFile
