{-# LANGUAGE LambdaCase #-}

import Prelude
import GHC.Int
import Data.Maybe
import System.Environment
import System.IO

import qualified Data.ByteString as B
import qualified Data.ByteString.Lazy as BL
import qualified Data.ByteString.Unsafe as B
import qualified Data.Vector.Unboxed as V

import Data.ByteString.Builder
import Data.List.Split (chunksOf)

--  We don't need big ints, we don't even need more than 16 bits!
type Short = Int16


--  For this demo, several string types are used:
--    String, strict ByteString, lazy ByteString.

type Chunk = B.ByteString

digits60 :: V.Vector Char
digits60 = V.fromList
   $ filter (`notElem` ['I','O']) $ ['0'..'9'] ++ ['A'..'Z'] ++ ['a'..'z']

back60 :: V.Vector Int
back60 = V.fromList
   [ fromMaybe (-1) $ V.findIndex (== c) digits60 | c <- take 256 ['\0'..] ]

isG60Char :: Char -> Bool
isG60Char c = back60 V.! fromEnum c /= -1

g60ToBuilder :: String -> Builder
g60ToBuilder s = foldMap (word8 . fromIntegral) [
           b1,         r1*20 +b2,   r2*90 + b3', 128*r3' + b4
         , r4*30 + b5, r5*150 + b6, r6*12 + b7,  60*r7 + c10 ]
   where
   c0 : c1 : c2 : c3 : c4 : c5 : c6 : c7 : c8 : c9 : c10 : _
      = map (fromIntegral . (back60 V.!) . fromEnum) s
         :: [Short]
   (b1, r1)   = (60*c0 + c1) `divMod` 14
   (b2, r2)   = c2           `divMod` 3
   (b3, r3)   = c4           `divMod` 20
   (b3', r3') = (3*c3 + b3)  `divMod` 2
   (b4, r4)   = (60*r3 + c5) `divMod` 9
   (b5, r5)   = c6           `divMod` 2
   (b6, r6)   = (60*c7 + c8) `divMod` 24
   (b7, r7)   = c9           `divMod` 5

chunkToG60 :: Chunk -> String
chunkToG60 s = map ((digits60 V.!) . fromIntegral) [
           c1, r1, 3*r2 + c3, c4, 20*r4 + c5, r5
         , 2*r6 + c7, c8, 12*r8 + c9, 5*r9 + c10, r10]
   where
   get :: Int -> Short
   get = fromIntegral . B.unsafeIndex s
   (c2, r2)   = get 1             `divMod` 20
   (c1, r1)   = (14 * get 0 + c2) `divMod` 60
   (c3, r3)   = get 2             `divMod` 90
   (b3h, b3l) = get 3             `divMod` 128
   (c4, r4)   = (2*r3 + b3h)      `divMod` 3
   (c6, r6)   = get 4             `divMod` 30
   (c5, r5)   = (9*b3l + c6)      `divMod` 60
   (c7, r7)   = get 5             `divMod` 150
   (c8a, r8a) = get 6             `divMod` 144
   (c8, r8)   = (2*r7 + c8a)      `divMod` 5
   (c9, r9)   = r8a               `divMod` 12
   (c10, r10) = get 7             `divMod` 60

encodeG60 :: BL.ByteString -> String
encodeG60 s = case BL.splitAt 8 s of
      (a, b) | BL.null b -> take ((B.length a' * 11 + 7) `div` 8)
                              $ tr (BL.toStrict $ a <> BL.replicate 8 0)
             | True      -> tr a' ++ encodeG60 b
         where a' = BL.toStrict a
   where tr = chunkToG60

decodeG60 :: String -> BL.ByteString
decodeG60 = toLazyByteString . mconcat . loop where
   loop s = case splitAt 11 s of
         (a, []) -> [lazyByteString
                     $ BL.take ((fromIntegral (length a) * 8) `div` 11)
                     $ toLazyByteString
                     $ tr (a <> replicate (11 - length a) '0')]
         (a, b) -> tr a : loop b
   tr = g60ToBuilder

main :: IO ()
main = getArgs >>= \case
   []     -> mapM_ putStrLn =<< chunksOf 77 <$> encodeG60 <$> BL.getContents
   ["-d"] -> BL.putStr =<< decodeG60 <$> filter isG60Char <$> getContents
   _      -> getProgName >>= \pn -> hPutStrLn stderr
               $ "Usage: " <> pn <> " [-d] <infile >outfile"

