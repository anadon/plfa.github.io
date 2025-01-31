---
title     : "Raw: Raw, Scoped, Typed"
permalink : /Raw
---

This version uses raw terms.

The substitution algorithm is based on one by McBride.

## Imports

\begin{code}
module Raw where
\end{code}

\begin{code}
import Relation.Binary.PropositionalEquality as Eq
open Eq using (_≡_; refl; sym; trans; cong; cong₂; _≢_)
open import Data.Empty using (⊥; ⊥-elim)
open import Data.List using (List; []; _∷_; _++_; map; foldr; filter; length)
open import Data.Nat using (ℕ; zero; suc; _+_)
import Data.String as String
open import Data.String using (String; _≟_)
open import Data.Product using (_×_; proj₁; proj₂; ∃; ∃-syntax) renaming (_,_ to ⟨_,_⟩)
-- open import Data.Sum using (_⊎_; inj₁; inj₂)
-- open import Function using (_∘_)
open import Relation.Nullary using (¬_; Dec; yes; no)
open import Relation.Nullary.Negation using (¬?)
import Collections

pattern [_]       w        =  w ∷ []
pattern [_,_]     w x      =  w ∷ x ∷ []
pattern [_,_,_]   w x y    =  w ∷ x ∷ y ∷ []
pattern [_,_,_,_] w x y z  =  w ∷ x ∷ y ∷ z ∷ []
\end{code}


## First development: Raw

\begin{code}
module Raw where
\end{code}

### Syntax

\begin{code}
  infix   6  `λ_`→_
  infixl  9  _·_

  Id : Set
  Id = String

  data Type : Set where
    `ℕ   : Type
    _`→_ : Type → Type → Type

  data Ctx : Set where
    ε      : Ctx
    _,_`:_ : Ctx → Id → Type → Ctx

  data Term : Set where
    ⌊_⌋              : Id → Term
    `λ_`→_          : Id → Term → Term
    _·_             : Term → Term → Term
    `zero           : Term
    `suc            : Term → Term
\end{code}

### Example terms

\begin{code}
  two : Term
  two = `λ "s" `→ `λ "z" `→ ⌊ "s" ⌋ · (⌊ "s" ⌋ · ⌊ "z" ⌋)

  plus : Term
  plus = `λ "m" `→ `λ "n" `→ `λ "s" `→ `λ "z" `→
           ⌊ "m" ⌋ · ⌊ "s" ⌋ · (⌊ "n" ⌋ · ⌊ "s" ⌋ · ⌊ "z" ⌋)

  norm : Term
  norm = `λ "m" `→ ⌊ "m" ⌋ · (`λ "x" `→ `suc ⌊ "x" ⌋) · `zero
\end{code}

### Lists of identifiers

\begin{code}
  open Collections (Id) (_≟_)
\end{code}

### Free variables

\begin{code}
  free : Term → List Id
  free (⌊ x ⌋)                 =  [ x ]
  free (`λ x `→ N)             =  free N \\ x
  free (L · M)                 =  free L ++ free M
  free (`zero)                 =  []
  free (`suc M)                =  free M
\end{code}

### Identifier maps

\begin{code}
  ∅ : Id → Term
  ∅ x = ⌊ x ⌋

  infixl 5 _,_↦_

  _,_↦_ : (Id → Term) → Id → Term → (Id → Term)
  (ρ , x ↦ M) w with w ≟ x
  ...               | yes _   =  M
  ...               | no  _   =  ρ w
\end{code}

### Fresh variables

\begin{code}
  fresh : List Id → Id → Id
  fresh xs₀ y = helper xs₀ (length xs₀) y
    where

    prime : Id → Id
    prime x = x String.++ "′"

    helper : List Id → ℕ → Id → Id
    helper []       _       w                =  w
    helper (x ∷ xs) n       w with w ≟ x
    helper (x ∷ xs) n       w    | no  _     =  helper xs n w
    helper (x ∷ xs) (suc n) w    | yes refl  =  helper xs₀ n (prime w)
    helper (x ∷ xs) zero    w    | yes refl  =  ⊥-elim impossible
      where postulate impossible : ⊥

\end{code}

### Substitution

\begin{code}
  subst : List Id → (Id → Term) → Term → Term
  subst ys ρ ⌊ x ⌋        =  ρ x
  subst ys ρ (`λ x `→ N)  =  `λ y `→ subst (y ∷ ys) (ρ , x ↦ ⌊ y ⌋) N
    where
    y = fresh ys x
  subst ys ρ (L · M)      =  subst ys ρ L · subst ys ρ M
  subst ys ρ (`zero)      =  `zero
  subst ys ρ (`suc M)     =  `suc (subst ys ρ M)
                       
  _[_:=_] : Term → Id → Term → Term
  N [ x := M ]  =  subst (free M ++ (free N \\ x))  (∅ , x ↦ M) N
\end{code}

### Testing substitution

\begin{code}
  _ : fresh [ "y" ] "y" ≡ "y′"
  _ = refl

  _ : fresh [ "z" ] "y" ≡ "y"
  _ = refl

  _ : (⌊ "s" ⌋ · ⌊ "s" ⌋ · ⌊ "z" ⌋) [ "z" := `zero ] ≡ (⌊ "s" ⌋ · ⌊ "s" ⌋ · `zero)
  _ = refl

  _ : (`λ "y" `→ ⌊ "x" ⌋) [ "x" := ⌊ "z" ⌋ ] ≡ (`λ "y" `→ ⌊ "z" ⌋)
  _ = refl

  _ : (`λ "y" `→ ⌊ "x" ⌋) [ "x" := ⌊ "y" ⌋ ] ≡ (`λ "y′" `→ ⌊ "y" ⌋)
  _ = refl

  _ : (⌊ "s" ⌋ · ⌊ "s" ⌋ · ⌊ "z" ⌋) [ "s" := (`λ "m" `→ `suc ⌊ "m" ⌋) ]
                                   [ "z" := `zero ] 
        ≡ (`λ "m" `→ `suc ⌊ "m" ⌋) · (`λ "m" `→ `suc ⌊ "m" ⌋) · `zero
  _ = refl

  _ : subst [] (∅ , "m" ↦ two , "n" ↦ `zero) (⌊ "m" ⌋ · ⌊ "n" ⌋)  ≡ (two · `zero)
  _ = refl
\end{code}

### Values

\begin{code}
  data Natural : Term → Set where

    Zero :
        --------------
        Natural `zero

    Suc : ∀ {V}
      → Natural V
        -----------------
      → Natural (`suc V)

  data Value : Term → Set where

    Nat : ∀ {V}
      → Natural V
        ----------
      → Value V

    Fun : ∀ {x N}
        -----------------
      → Value (`λ x `→ N)
\end{code}

### Decide whether a term is a value

Not needed, and no longer correct.

\begin{code}
{-
  value : ∀ (M : Term) → Dec (Value M)
  value ⌊ x ⌋                  = no (λ())
  value (`λ x `→ N)            =  yes Fun
  value (L · M)                =  no (λ())
  value `zero                  =  yes Zero
  value (`suc M) with value M
  ...              | yes VM    = yes (Suc VM)
  ...              | no  ¬VM   = no (λ{(Suc VM) → (¬VM VM)})
-}
\end{code}

### Reduction

\begin{code}
  infix 4 _⟶_

  data _⟶_ : Term → Term → Set where

    ξ-·₁ : ∀ {L L′ M}
      → L ⟶ L′
        ----------------
      → L · M ⟶ L′ · M

    ξ-·₂ : ∀ {V M M′}
      → Value V
      → M ⟶ M′
        ----------------
      → V · M ⟶ V · M′

    β-→ : ∀ {x N V}
      → Value V
        --------------------------------
      → (`λ x `→ N) · V ⟶ N [ x := V ]

    ξ-suc : ∀ {M M′}
      → M ⟶ M′
        ------------------
      → `suc M ⟶ `suc M′
\end{code}

### Reflexive and transitive closure

\begin{code}
  infix  2 _⟶*_
  infix 1 begin_
  infixr 2 _⟶⟨_⟩_
  infix 3 _∎

  data _⟶*_ : Term → Term → Set where

    _∎ : ∀ (M : Term)
        -------------
      → M ⟶* M

    _⟶⟨_⟩_ : ∀ (L : Term) {M N}
      → L ⟶ M
      → M ⟶* N
        ---------
      → L ⟶* N

  begin_ : ∀ {M N} → (M ⟶* N) → (M ⟶* N)
  begin M⟶*N = M⟶*N
\end{code}

### Decide whether a term reduces

\begin{code}
{-
  data Step (M : Term) : Set where
    step : ∀ {N}
      →  M ⟶ N
         -------
      →  Step M

  reduce : ∀ (M : Term) → Dec (Step M)
  reduce ⌊ x ⌋ =  no (λ{(step ())})
  reduce (`λ x `→ N) =  no (λ{(step ())})
  reduce (L · M) with reduce L
  ...    | yes (step L⟶L′)    =  yes (step (ξ-·₁ L⟶L′))
  ...    | no  ¬L⟶L′ with value L
  ...       | no ¬VL            =  no (λ{ (step (β-→ _)) → (¬VL Fun)
                                        ; (step (ξ-·₁ L⟶L′)) → (¬L⟶L′ (step L⟶L′))
                                        ; (step (ξ-·₂ VL _)) → (¬VL VL) })
  ...        | yes VL with reduce M
  ...            | yes (step M⟶M′)     = yes (step (ξ-·₂ VL M⟶M′))
  ...            | no ¬M⟶M′     = {!!}
  reduce `zero = {!!}
  reduce (`suc M) = {!!}
-}
\end{code}

### Stuck terms

\begin{code}
  data Stuck : Term → Set where

    st-·₁ : ∀ {L M}
      → Stuck L
        --------------
      → Stuck (L · M)

    st-·₂ : ∀ {V M}
      → Value V
      → Stuck M
        --------------
      → Stuck (V · M)

    st-·-nat : ∀ {V M}
      → Natural V 
        --------------
      → Stuck (V · M)
      
    st-suc-λ : ∀ {x N}
        -------------------------
      → Stuck (`suc (`λ x `→ N)) 

    st-suc : ∀ {M}
      → Stuck M
        --------------
      → Stuck (`suc M)
\end{code}

### Closed terms

\begin{code}
  Closed : Term → Set
  Closed M = free M ≡ []

  Ax-lemma : ∀ {x} → ¬ (Closed ⌊ x ⌋)
  Ax-lemma ()

  closed-·₁ : ∀ {L M} → Closed (L · M) → Closed L
  closed-·₁ r = lemma r
    where
    lemma : ∀ {A : Set} {xs ys : List A} → xs ++ ys ≡ [] → xs ≡ []
    lemma {xs = []}     _   =  refl
    lemma {xs = x ∷ xs} ()

  closed-·₂ : ∀ {L M} → Closed (L · M) → Closed M
  closed-·₂ r = lemma r
    where
    lemma : ∀ {A : Set} {xs ys : List A} → xs ++ ys ≡ [] → ys ≡ []
    lemma {xs = []}     refl  =  refl
    lemma {xs = x ∷ xs} ()

  ·-closed : ∀ {L M} → Closed L → Closed M → Closed (L · M)
  ·-closed r s = lemma r s
     where
     lemma : ∀ {A : Set} {xs ys : List A} → xs ≡ [] → ys ≡ [] → xs ++ ys ≡ []
     lemma refl refl = refl

  closed-suc : ∀ {M} → Closed (`suc M) → Closed M
  closed-suc r  =  r

  suc-closed : ∀ {M} → Closed M → Closed (`suc M)
  suc-closed r  =  r
\end{code}

### Progress

\begin{code}
  data Progress (M : Term) : Set where

    step : ∀ {N}
      → M ⟶ N
        -----------
      → Progress M

    stuck : 
        Stuck M
        -----------
      → Progress M

    done : 
        Value M
        -----------
      → Progress M
\end{code}

### Progress

\begin{code}
  progress : ∀ (M : Term) → Closed M → Progress M
  progress ⌊ x ⌋ Cx                          =  ⊥-elim (Ax-lemma Cx)
  progress (L · M) CLM with progress L (closed-·₁ {L} {M} CLM)
  ...    | step L⟶L′                      =  step (ξ-·₁ L⟶L′)
  ...    | stuck SL                         =  stuck (st-·₁ SL)
  ...    | done VL with progress M (closed-·₂ {L} {M} CLM)
  ...        | step M⟶M′                  =  step (ξ-·₂ VL M⟶M′)
  ...        | stuck SM                     =  stuck (st-·₂ VL SM)
  ...        | done VM  with VL
  ...            | Nat NL                   =  stuck (st-·-nat NL)
  ...            | Fun                      =  step (β-→ VM)
  progress (`λ x `→ N) CxN                  =  done Fun
  progress `zero Cz                         =  done (Nat Zero)
  progress (`suc M) CsM with progress M (closed-suc {M} CsM)
  ...    | step M⟶M′                      = step (ξ-suc M⟶M′)
  ...    | stuck SM                         =  stuck (st-suc SM)
  ...    | done (Nat NL)                    =  done (Nat (Suc NL))
  ...    | done Fun                         =  stuck st-suc-λ
\end{code}

### Preservation

Preservation of closed terms is not so easy. 

\begin{code}
  preservation : ∀ {M N : Term} → Closed M → M ⟶ N → Closed N
  preservation = {!!}
{-
  preservation CLM (ξ-·₁ L⟶L′)
    = ·-closed (preservation (closed-·₁ CLM) L⟶L′) (closed-·₂ CLM)
  preservation CLM (ξ-·₂ _ M⟶M′)
    = ·-closed (closed-·₁ CLM) (preservation (closed-·₂ CLM) M⟶M′)
  preservation CM (β-→ VM) = {!!}  -- requires closure under substitution!
  preservation CM (ξ-suc M⟶M′)
    = suc-closed (preservation (closed-suc CM) M⟶M′)
-}
\end{code}

### Evaluation

\begin{code}
  Gas : Set
  Gas = ℕ

  data Eval (M : Term) : Set where
    out-of-gas : ∀ {N} → M ⟶* N → Eval M
    stuck      : ∀ {N} → M ⟶* N → Stuck N → Eval M
    done       : ∀ {V} → M ⟶* V → Value V → Eval M

  eval : Gas → (L : Term) → Closed L → Eval L
  eval zero L CL                        =  out-of-gas (L ∎)
  eval (suc n) L CL with progress L CL
  ...  | stuck SL                       =  stuck      (L ∎) SL
  ...  | done VL                        =  done       (L ∎) VL
  ...  | step {M} L⟶M with eval n M (preservation CL L⟶M)
  ...          | out-of-gas M⟶*N      =  out-of-gas (L ⟶⟨ L⟶M ⟩ M⟶*N)
  ...          | stuck      M⟶*N SN   =  stuck      (L ⟶⟨ L⟶M ⟩ M⟶*N) SN
  ...          | done       M⟶*V VV   =  done       (L ⟶⟨ L⟶M ⟩ M⟶*V) VV
\end{code}


## Second development: Scoped

\begin{code}
module Scoped where
\end{code}

### Syntax

\begin{code}
  infix  4 _⊢*
  infix  4 _∋*
  infixl 5 _,*
  infix  5 `λ_`→_
  infixl 6 _·_
  infix  7 S_

  Id : Set
  Id = String

  data Ctx : Set where
    ε   : Ctx
    _,* : Ctx → Ctx

  data _∋* : Ctx → Set where

    Z : ∀ {Γ}
        ------------
      → Γ ,* ∋*

    S_ : ∀ {Γ}
      → Γ ∋*
        --------
      → Γ ,* ∋* 

  data _⊢* : Ctx → Set where

    ⌊_⌋ : ∀ {Γ}
      → Γ ∋*
        -----
      → Γ ⊢*
      
    `λ_`→_  : ∀ {Γ} (x : Id)
      → Γ ,* ⊢*
        --------
      → Γ ⊢*

    _·_  : ∀ {Γ}
      → Γ ⊢*
      → Γ ⊢*
        -----
      → Γ ⊢*

    `zero : ∀ {Γ}
        -----
      → Γ ⊢*

    `suc : ∀ {Γ}
      → Γ ⊢*
        -----
      → Γ ⊢* 
\end{code}

## Conversion: Raw to Scoped

\begin{code}
  infix 4 _∈_

  data _∈_ : Id → List Id → Set where

    here : ∀ {x xs} →
      ----------
      x ∈ x ∷ xs
      
    there : ∀ {w x xs} →
      w ∈ xs →
      ----------
      w ∈ x ∷ xs

  _?∈_ : ∀ (x : Id) (xs : List Id) → Dec (x ∈ xs)
  x ?∈ []  =  no (λ())
  x ?∈ (y ∷ ys) with x ≟ y
  ...              | yes refl              =  yes here
  ...              | no x≢  with x ?∈ ys
  ...                          | yes x∈    =  yes (there x∈)
  ...                          | no x∉     =  no  (λ{ here → x≢ refl
                                                    ; (there x∈) → x∉ x∈
                                                    })

  distinct : List Id → List Id
  distinct []  =  []
  distinct (x ∷ xs) with x ?∈ distinct xs
  ... | yes x∈  =  distinct xs
  ... | no  x∉  =  x ∷ distinct xs

  context : Raw.Term → Ctx
  context M  =  helper (distinct (Raw.free M))
    where
    helper : List Id → Ctx
    helper []        =  ε
    helper (x ∷ xs)  =  helper xs ,*

  raw→scoped : (M : Raw.Term) → (context M ⊢*)
  raw→scoped M = {!!}
    where

    xs₀ = distinct (Raw.free M)

{-
    The following does not work because `context M` should shrink on recursive calls.

    lookup : Id → (context M ⊢*)
    lookup w = helper w xs₀
      where
      helper : Id → List Id → (context M ⊢*)
      helper w []                    =  ⊥-elim impossible
        where postulate impossible : ⊥
      helper w (x ∷ xs) with w ≟ x
      ...                  | yes _   =  Z
      ...                  | no  _   =  S (helper xs)
-}    
\end{code}



## Third development: Typed

\begin{code}
module Typed where
\end{code}
  infix  4 _⊢_
  infix  4 _∋_
  infixl 5 _,_
  infixr 5 _`→_
  infix  5 ƛ_`→_
  infixl 6 _·_
  infix  7 S_

  data Type : Set where
    `ℕ   : Type
    _`→_ : Type → Type → Type

  data _∋_ : Ctx → Type → Set where

    Z : ∀ {Γ A}
        ----------
      → Γ , A ∋ A

    S_ : ∀ {Γ A B}
      → Γ ∋ B
        ---------
      → Γ , A ∋ B

  data _⊢_ : Ctx → Type → Set where

    ⌊_⌋ : ∀ {Γ} {A}
      → Γ ∋ A
        ------
      → Γ ⊢ A

    `λ_`→_  :  ∀ {Γ A B} (x : Id)
      → Γ , A ⊢ B
        -----------
      → Γ ⊢ A `→ B

    _·_ : ∀ {Γ} {A B}
      → Γ ⊢ A `→ B
      → Γ ⊢ A
        -----------
      → Γ ⊢ B

    `zero : ∀ {Γ}
        ----------
      → Γ ⊢ `ℕ

    `suc : ∀ {Γ}
      → Γ ⊢ `ℕ
        -------
      → Γ ⊢ `ℕ
\end{code}
