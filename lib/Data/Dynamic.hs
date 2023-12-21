module Data.Dynamic(
  Typeable(..),
  Dynamic,
  toDyn,
  fromDyn, fromDynamic,
  dynApply, dynApp,
  ) where
import Prelude
import Data.Proxy
import Data.Typeable
import Unsafe.Coerce

data Dynamic = D TypeRep Any

toDyn :: forall a . Typeable a => a -> Dynamic
toDyn a = D (typeOf a) (unsafeCoerce a)

fromDyn :: forall a . Typeable a => Dynamic -> a -> a
fromDyn d a = fromMaybe a $ fromDynamic d

fromDynamic :: forall a . Typeable a => Dynamic -> Maybe a
fromDynamic (D tr a) | tr == typeRep (Proxy :: Proxy a) = Just (unsafeCoerce a)
                     | otherwise = Nothing

dynApp :: Dynamic -> Dynamic -> Dynamic
dynApp f a = fromMaybe (error "Dynamic.dynApp") $ dynApply f a

dynApply :: Dynamic -> Dynamic -> Maybe Dynamic
dynApply (D ftr f) (D atr a) = fmap f $ funResultTy ftr atr
  where f rtr = D rtr ((unsafeCoerce f) a)
