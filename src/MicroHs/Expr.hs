module MicroHs.Expr(
  IdentModule,
  EModule(..),
  ExportItem(..),
  ImportSpec(..),
  ImportItem(..),
  EDef(..), showEDefs,
  Expr(..), eLam, showExpr,
  Listish(..),
  Lit(..), showLit, eqLit,
  EBind(..), showEBind,
  Eqn(..),
  EStmt(..),
  EAlts(..),
  EAlt,
  ECaseArm,
  EType, showEType,
  EPat, patVars, isPVar, isPConApp,
  EKind, kType,
  IdKind(..), idKindIdent,
  LHS,
  Constr(..), ConstrField,
  ConTyInfo,
  Con(..), conIdent, conArity, eqCon, getSLocCon,
  tupleConstr, untupleConstr, isTupleConstr,
  subst,
  allVarsExpr, allVarsBind,
  getSLocExpr, setSLocExpr,
  errorMessage,
  Assoc(..), eqAssoc, Fixity
  ) where
import Prelude --Xhiding (Monad(..), Applicative(..), MonadFail(..), Functor(..), (<$>), showString, showChar, showList, (<>))
import Data.Maybe
import MicroHs.Ident
import qualified Data.Double as D
--Ximport Compat
--Ximport GHC.Stack
--Ximport Control.DeepSeq
--Yimport Primitives(NFData(..))
import MicroHs.Pretty

type IdentModule = Ident

----------------------

data EModule = EModule IdentModule [ExportItem] [EDef]
  --Xderiving (Show, Eq)

data ExportItem
  = ExpModule IdentModule
  | ExpTypeCon Ident
  | ExpType Ident
  | ExpValue Ident
  --Xderiving (Show, Eq)

data EDef
  = Data LHS [Constr]
  | Newtype LHS Constr
  | Type LHS EType
  | Fcn Ident [Eqn]
  | Sign Ident EType
  | Import ImportSpec
  | ForImp String Ident EType
  | Infix Fixity [Ident]
  --Xderiving (Show, Eq)

data ImportSpec = ImportSpec Bool Ident (Maybe Ident) (Maybe (Bool, [ImportItem]))  -- first Bool indicates 'qualified', second 'hiding'
  --Xderiving (Show, Eq)

data ImportItem
  = ImpTypeCon Ident
  | ImpType Ident
  | ImpValue Ident
  --Xderiving (Show, Eq)

data Expr
  = EVar Ident
  | EApp Expr Expr
  | EOper Expr [(Ident, Expr)]
  | ELam [Eqn]
  | ELit SLoc Lit
  | ECase Expr [ECaseArm]
  | ELet [EBind] Expr
  | ETuple [Expr]
  | EListish Listish
  | EDo (Maybe Ident) [EStmt]
  | ESectL Expr Ident
  | ESectR Ident Expr
  | EIf Expr Expr Expr
  | ESign Expr EType
  | EAt Ident Expr  -- only in patterns
  -- Only while type checking
  | EUVar Int
  -- Constructors after type checking
  | ECon Con
  | EForall [IdKind] Expr -- only in types
  --Xderiving (Show, Eq)

eLam :: [EPat] -> Expr -> Expr
eLam ps e = ELam [Eqn ps (EAlts [([], e)] [])]

data Con
  = ConData ConTyInfo Ident
  | ConNew Ident
  | ConLit Lit
--  | ConTup Int
  --Xderiving(Show, Eq)

data Listish
  = LList [Expr]
  | LCompr Expr [EStmt]
  | LFrom Expr
  | LFromTo Expr Expr
  | LFromThen Expr Expr
  | LFromThenTo Expr Expr Expr
  --Xderiving(Show, Eq)

conIdent :: --XHasCallStack =>
            Con -> Ident
conIdent (ConData _ i) = i
conIdent (ConNew i) = i
conIdent _ = error "conIdent"

conArity :: Con -> Int
conArity (ConData cs i) = fromMaybe (error "conArity") $ lookupBy eqIdent i cs
conArity (ConNew _) = 1
conArity (ConLit _) = 0

eqCon :: Con -> Con -> Bool
eqCon (ConData _ i) (ConData _ j) = eqIdent i j
eqCon (ConNew    i) (ConNew    j) = eqIdent i j
eqCon (ConLit    l) (ConLit    k) = eqLit   l k
eqCon _             _             = False

data Lit
  = LInt Int
  | LDouble D.Double
  | LChar Char
  | LStr String
  | LPrim String
  | LForImp String
  --Xderiving (Show, Eq)
--Winstance NFData Lit where rnf (LInt i) = rnf i; rnf (LDouble d) = rnf d; rnf (LChar c) = rnf c; rnf (LStr s) = rnf s; rnf (LPrim s) = rnf s; rnf (LForImp s) = rnf s

eqLit :: Lit -> Lit -> Bool
eqLit (LInt x)  (LInt  y) = x == y
eqLit (LChar x) (LChar y) = eqChar x y
eqLit (LStr  x) (LStr  y) = eqString x y
eqLit (LPrim x) (LPrim y) = eqString x y
eqLit (LForImp x) (LForImp y) = eqString x y
eqLit _         _         = False

type ECaseArm = (EPat, EAlts)

data EStmt = SBind EPat Expr | SThen Expr | SLet [EBind]
  --Xderiving (Show, Eq)

data EBind = BFcn Ident [Eqn] | BPat EPat Expr | BSign Ident EType
  --Xderiving (Show, Eq)

-- A single equation for a function
data Eqn = Eqn [EPat] EAlts
  --Xderiving (Show, Eq)

data EAlts = EAlts [EAlt] [EBind]
  --Xderiving (Show, Eq)

type EAlt = ([EStmt], Expr)

type ConTyInfo = [(Ident, Int)]    -- All constructors with their arities

type EPat = Expr

isPVar :: EPat -> Bool
isPVar (EVar i) = not (isConIdent i)
isPVar _ = False    

isPConApp :: EPat -> Bool
isPConApp (EVar i) = isConIdent i
isPConApp (EApp f _) = isPConApp f
isPConApp _ = True

patVars :: EPat -> [Ident]
patVars = filter isVar . allVarsExpr
  where isVar v = not (isConIdent v) && not (isDummyIdent v)

type LHS = (Ident, [IdKind])

data Constr = Constr Ident (Either [EType] [ConstrField])
  --Xderiving(Show, Eq)

type ConstrField = (Ident, EType)              -- record label and type

-- Expr restricted to
--  * after desugaring: EApp and EVar
--  * before desugaring: EApp, EVar, ETuple, EList
type EType = Expr

data IdKind = IdKind Ident EKind
  --Xderiving (Show, Eq)

idKindIdent :: IdKind -> Ident
idKindIdent (IdKind i _) = i

type EKind = EType

kType :: EKind
kType = EVar (Ident noSLoc "Primitives.Type")

tupleConstr :: SLoc -> Int -> Ident
tupleConstr loc n = mkIdentSLoc loc (replicate (n - 1) ',')

untupleConstr :: Ident -> Int
untupleConstr i = length (unIdent i) + 1

isTupleConstr :: Int -> Ident -> Bool
isTupleConstr n i = eqChar (head (unIdent i)) ',' && untupleConstr i == n

---------------------------------

data Assoc = AssocLeft | AssocRight | AssocNone
  --Xderiving (Eq, Show)

eqAssoc :: Assoc -> Assoc -> Bool
eqAssoc AssocLeft AssocLeft = True
eqAssoc AssocRight AssocRight = True
eqAssoc AssocNone AssocNone = True
eqAssoc _ _ = False

type Fixity = (Assoc, Int)

---------------------------------

-- Enough to handle subsitution in types
subst :: [(Ident, Expr)] -> Expr -> Expr
subst s =
  let
    sub ae =
      case ae of
        EVar i -> fromMaybe ae $ lookupBy eqIdent i s
        EApp f a -> EApp (sub f) (sub a)
        ESign e t -> ESign (sub e) t
        EUVar _ -> ae
        _ -> error "subst unimplemented"
  in sub

---------------------------------

allVarsBind :: EBind -> [Ident]
allVarsBind abind =
  case abind of
    BFcn i eqns -> i : concatMap allVarsEqn eqns
    BPat p e -> allVarsPat p ++ allVarsExpr e
    BSign i _ -> [i]

allVarsEqn :: Eqn -> [Ident]
allVarsEqn eqn =
  case eqn of
    Eqn ps alts -> concatMap allVarsPat ps ++ allVarsAlts alts

allVarsAlts :: EAlts -> [Ident]
allVarsAlts (EAlts alts bs) = concatMap allVarsAlt alts ++ concatMap allVarsBind bs

allVarsAlt :: EAlt -> [Ident]
allVarsAlt (ss, e) = concatMap allVarsStmt ss ++ allVarsExpr e

allVarsPat :: EPat -> [Ident]
allVarsPat = allVarsExpr

allVarsExpr :: Expr -> [Ident]
allVarsExpr aexpr =
  case aexpr of
    EVar i -> [i]
    EApp e1 e2 -> allVarsExpr e1 ++ allVarsExpr e2
    EOper e1 ies -> allVarsExpr e1 ++ concatMap (\ (i,e2) -> i : allVarsExpr e2) ies
    ELam qs -> concatMap allVarsEqn qs
    ELit _ _ -> []
    ECase e as -> allVarsExpr e ++ concatMap allVarsCaseArm as
    ELet bs e -> concatMap allVarsBind bs ++ allVarsExpr e
    ETuple es -> concatMap allVarsExpr es
    EListish (LList es) -> concatMap allVarsExpr es
    EDo mi ss -> maybe [] (:[]) mi ++ concatMap allVarsStmt ss
    ESectL e i -> i : allVarsExpr e
    ESectR i e -> i : allVarsExpr e
    EIf e1 e2 e3 -> allVarsExpr e1 ++ allVarsExpr e2 ++ allVarsExpr e3
    EListish l -> allVarsListish l
    ESign e _ -> allVarsExpr e
    EAt i e -> i : allVarsExpr e
    EUVar _ -> []
    ECon c -> [conIdent c]
    EForall iks e -> map (\ (IdKind i _) -> i) iks ++ allVarsExpr e

allVarsListish :: Listish -> [Ident]
allVarsListish (LList es) = concatMap allVarsExpr es
allVarsListish (LCompr e ss) = allVarsExpr e ++ concatMap allVarsStmt ss
allVarsListish (LFrom e) = allVarsExpr e
allVarsListish (LFromTo e1 e2) = allVarsExpr e1 ++ allVarsExpr e2
allVarsListish (LFromThen e1 e2) = allVarsExpr e1 ++ allVarsExpr e2
allVarsListish (LFromThenTo e1 e2 e3) = allVarsExpr e1 ++ allVarsExpr e2 ++ allVarsExpr e3

allVarsCaseArm :: ECaseArm -> [Ident]
allVarsCaseArm (p, alts) = allVarsPat p ++ allVarsAlts alts

allVarsStmt :: EStmt -> [Ident]
allVarsStmt astmt =
  case astmt of
    SBind p e -> allVarsPat p ++ allVarsExpr e
    SThen e -> allVarsExpr e
    SLet bs -> concatMap allVarsBind bs

-----------------------------

-- XXX Should use locations in ELit
getSLocExpr :: Expr -> SLoc
getSLocExpr e = head $ filter (not . isNoSLoc) (map getSLocIdent (allVarsExpr e)) ++ [noSLoc]

getSLocCon :: Con -> SLoc
getSLocCon (ConData _ i) = getSLocIdent i
getSLocCon (ConNew i) = getSLocIdent i
getSLocCon _ = noSLoc

setSLocExpr :: SLoc -> Expr -> Expr
setSLocExpr l (EVar i) = EVar (setSLocIdent l i)
setSLocExpr l (ECon c) = ECon (setSLocCon l c)
setSLocExpr l (ELit _ k) = ELit l k
setSLocExpr _ _ = error "setSLocExpr"  -- what other cases do we need?

setSLocCon :: SLoc -> Con -> Con
setSLocCon l (ConData ti i) = ConData ti (setSLocIdent l i)
setSLocCon l (ConNew i) = ConNew (setSLocIdent l i)
setSLocCon _ c = c

errorMessage :: --XHasCallStack =>
                forall a . SLoc -> String -> a
errorMessage loc msg = error $ showSLoc loc ++ ": " ++ msg

----------------

{-
showEModule :: EModule -> String
showEModule am =
  case am of
    EModule i es ds -> "module " ++ i ++ "(\n" ++
      unlines (intersperse "," (map showExportItem es)) ++
      "\n) where\n" ++
      showEDefs ds

showExportItem :: ExportItem -> String
showExportItem ae =
  case ae of
    ExpModule i -> "module " ++ i
    ExpTypeCon i -> i ++ "(..)"
    ExpType i -> i
    ExpValue i -> i
-}

showExpr :: Expr -> String
showExpr = render . ppExpr

showEDefs :: [EDef] -> String
showEDefs = render . ppEDefs

showEBind :: EBind -> String
showEBind = render . ppEBind

showEType :: EType -> String
showEType = render . ppEType

ppImportItem :: ImportItem -> Doc
ppImportItem ae =
  case ae of
    ImpTypeCon i -> ppIdent i <> text "(..)"
    ImpType i -> ppIdent i
    ImpValue i -> ppIdent i

ppEDef :: EDef -> Doc
ppEDef def =
  case def of
    Data lhs [] -> text "data" <+> ppLHS lhs
    Data lhs cs -> text "data" <+> ppLHS lhs <+> text "=" <+> hsep (punctuate (text " |") (map ppConstr cs))
    Newtype lhs c -> text "newtype" <+> ppLHS lhs <+> text "=" <+> ppConstr c
    Type lhs t -> text "type" <+> ppLHS lhs <+> text "=" <+> ppEType t
    Fcn i eqns -> ppEqns (ppIdent i) (text "=") eqns
    Sign i t -> ppIdent i <+> text "::" <+> ppEType t
    Import (ImportSpec q m mm mis) -> text "import" <+> (if q then text "qualified" else empty) <+> ppIdent m <> text (maybe "" ((" as " ++) . unIdent) mm) <>
      case mis of
        Nothing -> empty
        Just (h, is) -> text (if h then " hiding" else "") <> parens (hsep $ punctuate (text ", ") (map ppImportItem is))
    ForImp ie i t -> text ("foreign import ccall " ++ showString ie) <+> ppIdent i <+> text "::" <+> ppEType t
    Infix (a, p) is -> text ("infix" ++ f a) <+> text (showInt p) <+> hsep (punctuate (text ", ") (map ppIdent is))
      where f AssocLeft = "l"; f AssocRight = "r"; f AssocNone = ""

ppEqns :: Doc -> Doc -> [Eqn] -> Doc
ppEqns name sepr = vcat . map (\ (Eqn ps alts) -> sep [name <+> hsep (map ppEPat ps), ppAlts sepr alts])

ppConstr :: Constr -> Doc
ppConstr (Constr c (Left  ts)) = hsep (ppIdent c : map ppEType ts)
ppConstr (Constr c (Right fs)) = ppIdent c <> braces (hsep $ map f fs)
  where f (i, t) = ppIdent i <+> text "::" <+> ppEType t <> text ","

ppLHS :: LHS -> Doc
ppLHS (f, vs) = hsep (ppIdent f : map ppIdKind vs)

ppIdKind :: IdKind -> Doc
ppIdKind (IdKind i k) = parens $ ppIdent i <> text "::" <> ppEKind k

ppEDefs :: [EDef] -> Doc
ppEDefs ds = vcat (map ppEDef ds)

ppAlts :: Doc -> EAlts -> Doc
ppAlts asep (EAlts alts bs) = ppAltsL asep alts <> ppWhere bs

ppWhere :: [EBind] -> Doc
ppWhere [] = empty
ppWhere bs = text "where" $+$ nest 2 (vcat (map ppEBind bs))

ppAltsL :: Doc -> [EAlt] -> Doc
ppAltsL asep [([], e)] = text "" <+> asep <+> ppExpr e
ppAltsL asep alts = vcat (map (ppAlt asep) alts)

ppAlt :: Doc -> EAlt -> Doc
ppAlt asep (ss, e) = text " |" <+> hsep (punctuate (text ",") (map ppEStmt ss)) <+> asep <+> ppExpr e

ppExpr :: Expr -> Doc
ppExpr ae =
  case ae of
    EVar v -> ppIdent v
    EApp _ _ -> ppApp [] ae
    EOper e ies -> ppExpr (foldl (\ e1 (i, e2) -> EApp (EApp (EVar i) e1) e2) e ies)
    ELam qs -> parens $ text "\\" <> ppEqns empty (text "->") qs
    ELit _ i -> text (showLit i)
    ECase e as -> text "case" <+> ppExpr e <+> text "of" $$ nest 2 (vcat (map ppCaseArm as))
    ELet bs e -> text "let" $$ nest 2 (vcat (map ppEBind bs)) $$ text "in" <+> ppExpr e
    ETuple es -> parens $ hsep $ punctuate (text ",") (map ppExpr es)
    EListish (LList es) -> ppList ppExpr es
    EDo mn ss -> maybe (text "do") (\ n -> ppIdent n <> text ".do") mn $$ nest 2 (vcat (map ppEStmt ss))
    ESectL e i -> parens $ ppExpr e <+> ppIdent i
    ESectR i e -> parens $ ppIdent i <+> ppExpr e
    EIf e1 e2 e3 -> parens $ sep [text "if" <+> ppExpr e1, text "then" <+> ppExpr e2, text "else" <+> ppExpr e3]
    EListish l -> ppListish l
    ESign e t -> ppExpr e <+> text "::" <+> ppEType t
    EAt i e -> ppIdent i <> text "@" <> ppExpr e
    EUVar i -> text ("a" ++ showInt i)
    ECon c -> ppCon c
    EForall iks e -> text "forall" <+> hsep (map ppIdKind iks) <+> text "." <+> ppEType e
  where
    ppApp as (EApp f a) = ppApp (a:as) f
    ppApp as (EVar i) | eqString op "->", [a, b] <- as = parens $ ppExpr a <+> text "->" <+> ppExpr b
                      | eqChar (head op) ',' = ppExpr (ETuple as)
                      | eqString op "[]", length as == 1 = ppExpr (EListish (LList as))
                        where op = unQualString (unIdent i)
    ppApp as f = parens $ hsep (map ppExpr (f:as))

ppListish :: Listish -> Doc
ppListish _ = text "<<Listish>>"

ppCon :: Con -> Doc
ppCon (ConData _ s) = ppIdent s
ppCon (ConNew s) = ppIdent s
ppCon (ConLit l) = text (showLit l)

-- Literals are tagged the way they appear in the combinator file:
--  #   Int
--  %   Double
--  '   Char    (not in file)
--  "   String
--  ^   FFI function
--      primitive
showLit :: Lit -> String
showLit l =
  case l of
    LInt i    -> '#' : showInt i
    LDouble d -> '%' : D.showDouble d
    LChar c   -> showChar c
    LStr s    -> showString s
    LPrim s   -> s
    LForImp s -> '^' : s

ppEStmt :: EStmt -> Doc
ppEStmt as =
  case as of
    SBind p e -> ppEPat p <+> text "<-" <+> ppExpr e
    SThen e -> ppExpr e
    SLet bs -> text "let" $$ nest 2 (vcat (map ppEBind bs))

ppEBind :: EBind -> Doc
ppEBind ab =
  case ab of
    BFcn i eqns -> ppEDef (Fcn i eqns)
    BPat p e -> ppEPat p <+> text "=" <+> ppExpr e
    BSign i t -> ppIdent i <+> text "::" <+> ppEType t

ppCaseArm :: ECaseArm -> Doc
ppCaseArm arm =
  case arm of
    (p, alts) -> ppEPat p <> ppAlts (text "->") alts

ppEPat :: EPat -> Doc
ppEPat = ppExpr

ppEType :: EType -> Doc
ppEType = ppExpr

ppEKind :: EKind -> Doc
ppEKind = ppEType

ppList :: forall a . (a -> Doc) -> [a] -> Doc
ppList pp xs = brackets $ hsep $ punctuate (text ",") (map pp xs)
