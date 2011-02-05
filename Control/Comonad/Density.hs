{-# LANGUAGE MultiParamTypeClasses, GADTs #-}
-----------------------------------------------------------------------------
-- |
-- Module      :  Control.Comonad.Density
-- Copyright   :  (C) 2008-2011 Edward Kmett
-- License     :  BSD-style (see the file LICENSE)
--
-- Maintainer  :  Edward Kmett <ekmett@gmail.com>
-- Stability   :  experimental
-- Portability :  non-portable (GADTs, MPTCs)
--
-- The density comonad for a functor. aka the comonad generated by a functor
-- The ''density'' term dates back to Dubuc''s 1974 thesis. The term 
-- ''monad genererated by a functor'' dates back to 1972 in Street''s 
-- ''Formal Theory of Monads''.
----------------------------------------------------------------------------
module Control.Comonad.Density
  ( DensityT(..)
  , liftDensityT
  , densityTToAdjunction, adjunctionToDensityT
  ) where

import Control.Comonad
import Control.Comonad.Trans.Class
import Data.Functor.Adjunction

data DensityT k a where
  DensityT :: (k b -> a) -> k b -> DensityT k a

instance Functor (DensityT f) where
  fmap f (DensityT g h) = DensityT (f . g) h

instance Extend (DensityT f) where
  duplicate (DensityT f ws) = DensityT (DensityT f) ws

instance Comonad (DensityT f) where
  extract (DensityT f a) = f a

instance ComonadTrans DensityT where
  lower (DensityT f c) = extend f c
  
-- | The natural isomorphism between a comonad w and the comonad generated by w (forwards).
liftDensityT :: Comonad w => w a -> DensityT w a
liftDensityT = DensityT extract 

densityTToAdjunction :: Adjunction f g => DensityT f a -> f (g a)
densityTToAdjunction (DensityT f v) = fmap (leftAdjunct f) v

adjunctionToDensityT :: Adjunction f g => f (g a) -> DensityT f a
adjunctionToDensityT = DensityT counit
