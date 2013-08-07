{-# LANGUAGE CPP #-}
{-# LANGUAGE Rank2Types #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
#if defined(__GLASGOW_HASKELL__) && __GLASGOW_HASKELL__ >= 702
{-# LANGUAGE Trustworthy #-}
#endif

#ifndef MIN_VERSION_speculation
#define MIN_VERSION_speculation(x,y,z) 1
#endif
-----------------------------------------------------------------------------
-- |
-- Module      :  Control.Monad.Codensity
-- Copyright   :  (C) 2008-2011 Edward Kmett
-- License     :  BSD-style (see the file LICENSE)
--
-- Maintainer  :  Edward Kmett <ekmett@gmail.com>
-- Stability   :  provisional
-- Portability :  non-portable (rank-2 polymorphism)
--
----------------------------------------------------------------------------
module Control.Monad.Codensity
  ( Codensity(..)
  , lowerCodensity
  , codensityToAdjunction
  , adjunctionToCodensity
  , improve
  ) where

import Control.Applicative
import Control.Concurrent.Speculation
import Control.Concurrent.Speculation.Class
import Control.Monad (ap, MonadPlus(..))
import Control.Monad.Free
import Control.Monad.IO.Class
import Control.Monad.Reader.Class
import Control.Monad.State.Class
import Control.Monad.Trans.Class
import Data.Functor.Adjunction
import Data.Functor.Apply
import Data.Functor.Plus

-- @'Codensity' f@ is the Monad generated by taking the right Kan extension
-- of any 'Functor' @f@ along itself (@Ran f f@).
newtype Codensity m a = Codensity
  { runCodensity :: forall b. (a -> m b) -> m b
  }

instance MonadSpec (Codensity m) where
  specByM f g a = Codensity $ \k -> specBy f g k a
  {-# INLINE specByM #-}
#if !(MIN_VERSION_speculation(1,5,0))
  specByM' f g a = Codensity $ \k -> specBy' f g k a
  {-# INLINE specByM' #-}
#endif

instance Functor (Codensity k) where
  fmap f (Codensity m) = Codensity (\k -> m (k . f))
  {-# INLINE fmap #-}

instance Apply (Codensity f) where
  (<.>) = ap
  {-# INLINE (<.>) #-}

instance Applicative (Codensity f) where
  pure x = Codensity (\k -> k x)
  {-# INLINE pure #-}
  (<*>) = ap
  {-# INLINE (<*>) #-}

instance Monad (Codensity f) where
  return x = Codensity (\k -> k x)
  {-# INLINE return #-}
  m >>= k = Codensity (\c -> runCodensity m (\a -> runCodensity (k a) c))
  {-# INLINE (>>=) #-}

instance MonadIO m => MonadIO (Codensity m) where
  liftIO = lift . liftIO
  {-# INLINE liftIO #-}

instance MonadTrans Codensity where
  lift m = Codensity (m >>=)
  {-# INLINE lift #-}

instance Alt v => Alt (Codensity v) where
  Codensity m <!> Codensity n = Codensity (\k -> m k <!> n k)
  {-# INLINE (<!>) #-}

instance Plus v => Plus (Codensity v) where
  zero = Codensity (const zero)
  {-# INLINE zero #-}

{-
instance Plus v => Alternative (Codensity v) where
  empty = zero
  (<|>) = (<!>)

instance Plus v => MonadPlus (Codensity v) where
  mzero = zero
  mplus = (<!>)
-}

instance Alternative v => Alternative (Codensity v) where
  empty = Codensity (\_ -> empty)
  {-# INLINE empty #-}
  Codensity m <|> Codensity n = Codensity (\k -> m k <|> n k)
  {-# INLINE (<|>) #-}

instance MonadPlus v => MonadPlus (Codensity v) where
  mzero = Codensity (\_ -> mzero)
  {-# INLINE mzero #-}
  Codensity m `mplus` Codensity n = Codensity (\k -> m k `mplus` n k)
  {-# INLINE mplus #-}

lowerCodensity :: Monad m => Codensity m a -> m a
lowerCodensity a = runCodensity a return
{-# INLINE lowerCodensity #-}

codensityToAdjunction :: Adjunction f g => Codensity g a -> g (f a)
codensityToAdjunction r = runCodensity r unit
{-# INLINE codensityToAdjunction #-}

adjunctionToCodensity :: Adjunction f g => g (f a) -> Codensity g a
adjunctionToCodensity f = Codensity (\a -> fmap (rightAdjunct a) f)
{-# INLINE adjunctionToCodensity #-}

instance (Functor f, MonadFree f m) => MonadFree f (Codensity m) where
  wrap t = Codensity (\h -> wrap (fmap (\p -> runCodensity p h) t))
  {-# INLINE wrap #-}

instance MonadReader r m => MonadState r (Codensity m) where
  get = Codensity (ask >>=)
  {-# INLINE get #-}
  put s = Codensity (\k -> local (const s) (k ()))
  {-# INLINE put #-}

-- | Right associate all binds in a computation that generates a free monad
--
-- This can improve the asymptotic efficiency of the result, while preserving
-- semantics.
--
-- See \"Asymptotic Improvement of Computations over Free Monads\" by Janis
-- Voightländer for more information about this combinator.
--
-- <http://www.iai.uni-bonn.de/~jv/mpc08.pdf>
improve :: Functor f => (forall m. MonadFree f m => m a) -> Free f a
improve m = lowerCodensity m
{-# INLINE improve #-}
