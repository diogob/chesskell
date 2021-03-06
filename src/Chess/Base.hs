{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE FlexibleInstances #-}

module Chess.Base
  ( CastleRights(..)
  , Coordinate(..)
  , File
  , Game(..)
  , isOnBoard
  , Move(..)
  , MoveType(..)
  , Piece(..)
  , PieceType(..)
  , Player(..)
  , Rank
  , RegularBoardRepresentation
  , RegularGame(..)
  , Square(..)

  , coordinateEuclideanDistance
  , offsetBy
  , opponent
  , scaleBy
  , squareAt
  , toFEN
  , unoccupied
  , unoccupiedByAlly
  ) where

import Control.Applicative
import Control.Monad.State.Lazy

import Data.List
import Data.Maybe

data Square = Square
  { pieceOn  :: Maybe Piece
  , location :: Coordinate
  } deriving(Eq, Read, Show)

data Piece = Piece
  { pieceType  :: PieceType
  , pieceOwner :: Player
  } deriving(Eq, Read)

data Move = Move
  { moveFrom         :: Coordinate
  , moveTo           :: Coordinate
  , moveType         :: MoveType
  , movePromoteTo    :: Maybe Piece
  } deriving(Eq, Read, Show)

data MoveType = Standard | Capture | Castle | Promotion | EnPassant deriving(Eq, Read, Show)

instance Show Piece where
  show (Piece Rook White)   = "R"
  show (Piece Knight White) = "N"
  show (Piece Bishop White) = "B"
  show (Piece Queen White)  = "Q"
  show (Piece King White)   = "K"
  show (Piece Pawn White)   = "P"

  show (Piece Rook Black)   = "r"
  show (Piece Knight Black) = "n"
  show (Piece Bishop Black) = "b"
  show (Piece Queen Black)  = "q"
  show (Piece King Black)   = "k"
  show (Piece Pawn Black)   = "p"

data PieceType  = Pawn | Knight | Bishop | Rook | Queen | King deriving (Enum, Eq, Read)
data Player = White | Black deriving (Enum, Eq, Read, Show)

data Coordinate = Coordinate File Rank deriving(Eq, Read, Show)
type Rank   = Int
type File   = Char

-- KkQq
data CastleRights = CastleRights Bool Bool Bool Bool deriving(Eq, Show)

type RegularBoardRepresentation   = [[Square]]

data Game r = Game
  { placement       :: r
  , activeColor     :: Player
  , castlingRights  :: CastleRights
  , enPassantSquare :: Maybe Coordinate
  , halfMoveClock   :: Int
  , fullMoveNumber  :: Int
  } deriving(Eq)

type RegularGame = Game RegularBoardRepresentation

instance Show (Game RegularBoardRepresentation) where
  show g =    "\n"
           ++ "  abcdefgh \n"
           ++ "8 " ++ concatMap (maybe "-" show) eighthRank  ++ " 8\n"
           ++ "7 " ++ concatMap (maybe "-" show) seventhRank ++ " 7\n"
           ++ "6 " ++ concatMap (maybe "-" show) sixthRank   ++ " 6\n"
           ++ "5 " ++ concatMap (maybe "-" show) fifthRank   ++ " 5\n"
           ++ "4 " ++ concatMap (maybe "-" show) fourthRank  ++ " 4\n"
           ++ "3 " ++ concatMap (maybe "-" show) thirdRank   ++ " 3\n"
           ++ "2 " ++ concatMap (maybe "-" show) secondRank  ++ " 2\n"
           ++ "1 " ++ concatMap (maybe "-" show) firstRank   ++ " 1\n"
           ++ "  abcdefgh \n "
           ++ "\n"
           ++ show (activeColor g) ++ " to move\n"
           ++ show ( castlingRights g) ++ "\n"
           ++ "En passant on " ++ show (enPassantSquare g) ++ "\n"
           ++ "Halfmove clock at " ++ show (halfMoveClock g) ++ "\n"
           ++ "Fullmove number " ++ show (fullMoveNumber g) ++ "\n" where
    eighthRank  = map pieceOn $ placement g !! 7
    seventhRank = map pieceOn $ placement g !! 6
    sixthRank   = map pieceOn $ placement g !! 5
    fifthRank   = map pieceOn $ placement g !! 4
    fourthRank  = map pieceOn $ placement g !! 3
    thirdRank   = map pieceOn $ placement g !! 2
    secondRank  = map pieceOn $ placement g !! 1
    firstRank   = map pieceOn $ head $ placement g

isOnBoard                  :: Coordinate -> Bool
isOnBoard (Coordinate f r) | f < 'a'   = False
                           | f > 'h'   = False
                           | r < 1     = False
                           | r > 8     = False
                           | otherwise = True

unoccupiedByAlly         :: RegularBoardRepresentation -> Coordinate -> Maybe Player -> Bool
unoccupiedByAlly b c ply | isNothing targetOwner = True
                         | ply /= targetOwner = True
                         | ply == targetOwner = False where
  targetPiece = pieceOn $ squareAt b c
  targetOwner = pieceOwner <$> targetPiece

unoccupied     :: RegularBoardRepresentation -> Coordinate -> Bool
unoccupied b c = isNothing . pieceOn $ squareAt b c

squareAt                    :: RegularBoardRepresentation -> Coordinate -> Square
squareAt b (Coordinate f r) = (b !! (r-1)) !! (fromEnum f - fromEnum 'a')

scaleBy                           :: Int -> (Int, Int) -> (Int, Int)
scaleBy s (x,y)                   = (x*s, y*s)

offsetBy                          :: Coordinate -> (Int, Int) -> Coordinate
offsetBy (Coordinate f r) (df,dr) = Coordinate (toEnum $ fromEnum f + df) (r + dr)

opponent               :: Player -> Player
opponent White         = Black
opponent Black         = White

coordinateEuclideanDistance                                       :: Coordinate -> Coordinate -> Int
coordinateEuclideanDistance (Coordinate cx y) (Coordinate cx' y') = ((x' - x) ^ 2) + ((y' - y) ^ 2) where
  x' = fromEnum cx' - fromEnum 'a'
  x  = fromEnum cx - fromEnum 'a'

toFEN :: RegularGame -> String
toFEN Game { placement       = position
                  , activeColor     = ac
                  , castlingRights  = cr
                  , enPassantSquare = eps
                  , halfMoveClock   = hmc
                  , fullMoveNumber  = fmn
                  } = positionString ++ toMoveString ++ castlingRightsString cr ++ enPassantString eps ++ halfMovesString ++ fullMovesString where
  positionString = (++ " ") $ intercalate "/" $ map stringifyRank $ reverse position

  toMoveString | ac == White = "w "
               | otherwise   = "b "

  castlingRightsString (CastleRights True True True True) = "KQkq "
  castlingRightsString (CastleRights True True True False) = "KQk "
  castlingRightsString (CastleRights True True False True) = "KQq "
  castlingRightsString (CastleRights True True False False) = "KQ "
  castlingRightsString (CastleRights True False True True) = "Kkq "
  castlingRightsString (CastleRights True False True False) = "Kk "
  castlingRightsString (CastleRights True False False True) = "Kq "
  castlingRightsString (CastleRights True False False False) = "K "
  castlingRightsString (CastleRights False True True True) = "Qkq "
  castlingRightsString (CastleRights False True True False) = "Qk "
  castlingRightsString (CastleRights False True False True) = "Qq "
  castlingRightsString (CastleRights False True False False) = "Q "
  castlingRightsString (CastleRights False False True True) = "kq "
  castlingRightsString (CastleRights False False True False) = "k "
  castlingRightsString (CastleRights False False False True) = "q "
  castlingRightsString (CastleRights False False False False) = "- "

  enPassantString Nothing = "- "
  enPassantString (Just (Coordinate f r)) = return f ++ show r ++ " "
  halfMovesString = show hmc ++ " "
  fullMovesString = show fmn

  stringifyRank :: [Square] -> String
  stringifyRank = concatMap squishEmptySquares . group . foldr stringifyPiece "" . reverse

  stringifyPiece :: Square -> String -> String
  stringifyPiece (Square (Just (Piece Rook Black)) _)   acc = acc ++ "r"
  stringifyPiece (Square (Just (Piece Knight Black)) _) acc = acc ++ "n"
  stringifyPiece (Square (Just (Piece Bishop Black)) _) acc = acc ++ "b"
  stringifyPiece (Square (Just (Piece Queen Black)) _)  acc = acc ++ "q"
  stringifyPiece (Square (Just (Piece King Black)) _)   acc = acc ++ "k"
  stringifyPiece (Square (Just (Piece Pawn Black)) _)   acc = acc ++ "p"
  stringifyPiece (Square (Just (Piece Rook White)) _)   acc = acc ++ "R"
  stringifyPiece (Square (Just (Piece Knight White)) _) acc = acc ++ "N"
  stringifyPiece (Square (Just (Piece Bishop White)) _) acc = acc ++ "B"
  stringifyPiece (Square (Just (Piece Queen White)) _)  acc = acc ++ "Q"
  stringifyPiece (Square (Just (Piece King White)) _)   acc = acc ++ "K"
  stringifyPiece (Square (Just (Piece Pawn White)) _)   acc = acc ++ "P"
  stringifyPiece _ acc = acc ++ "-"

  squishEmptySquares :: String -> String
  squishEmptySquares ('-':xs) = show $ length ('-':xs)
  squishEmptySquares xs = xs
