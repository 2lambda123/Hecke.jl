export splitting_field, issubfield, isdefining_polynomial_nice, quadratic_field, islinearly_disjoint

################################################################################
#
#  Base field
#
################################################################################

base_field(K::AnticNumberField) = FlintQQ

################################################################################
#
#  Order type
#
################################################################################

order_type(::AnticNumberField) = NfAbsOrd{AnticNumberField, nf_elem}

order_type(::Type{AnticNumberField}) = NfAbsOrd{AnticNumberField, nf_elem}

################################################################################
#
#  Predicates
#
################################################################################

issimple(::Type{AnticNumberField}) = true

issimple(::AnticNumberField) = true

################################################################################
#
#  Field constructions
#
################################################################################

@doc Markdown.doc"""
    NumberField(S::Generic.ResRing{fmpq_poly}; cached::Bool = true, check::Bool = true) -> AnticNumberField, Map

 The number field $K$ isomorphic to the ring $S$ and the map from $K\to S$.
"""
function NumberField(S::Generic.ResRing{fmpq_poly}; cached::Bool = true, check::Bool = true)
  Qx = parent(modulus(S))
  K, a = NumberField(modulus(S), "_a", cached = cached, check = check)
  mp = MapFromFunc(y -> S(Qx(y)), x -> K(lift(x)), K, S)
  return K, mp
end

@doc Markdown.doc"""
    NumberField(f::fmpq_poly; cached::Bool = true, check::Bool = true)

 The number field Q[x]/f generated by f.
"""
function NumberField(f::fmpq_poly; cached::Bool = true, check::Bool = true)
  return NumberField(f, "_a", cached = cached, check = check)
end

function NumberField(f::fmpz_poly, s::Symbol; cached::Bool = true, check::Bool = true)
  Qx = Globals.Qx
  return NumberField(Qx(f), String(s), cached = cached, check = check)
end

function NumberField(f::fmpz_poly, s::AbstractString; cached::Bool = true, check::Bool = true)
  Qx = Globals.Qx
  return NumberField(Qx(f), s, cached = cached, check = check)
end

function NumberField(f::fmpz_poly; cached::Bool = true, check::Bool = true)
  Qx = Globals.Qx
  return NumberField(Qx(f), cached = cached, check = check)
end

@doc Markdown.doc"""
    radical_extension(n::Int, gen::Integer; cached::Bool = true, check::Bool = true) -> AnticNumberField, nf_elem
    radical_extension(n::Int, gen::fmpz; cached::Bool = true, check::Bool = true) -> AnticNumberField, nf_elem

The number field with defining polynomial $x^n-gen$.
"""
function radical_extension(n::Int, gen::Integer; cached::Bool = true, check::Bool = true)
  return radical_extension(n, fmpz(gen), cached = cached, check = check)
end

function radical_extension(n::Int, gen::fmpz; cached::Bool = true, check::Bool = true)
  x = gen(Globals.Qx)
  return number_field(x^n - gen, cached = cached, check = check)
end

@doc Markdown.doc"""
    cyclotomic_field(n::Int) -> AnticNumberField, nf_elem

The $n$-th cyclotomic field defined by the $n$-the cyclotomic polynomial.
"""
function cyclotomic_field(n::Int; cached::Bool = true)
  return CyclotomicField(n, "z_$n", cached = cached)
end

# TODO: Some sort of reference?
@doc Markdown.doc"""
    wildanger_field(n::Int, B::fmpz) -> AnticNumberField, nf_elem

Returns the field with defining polynomial $x^n + \sum_{i=0}^{n-1} (-1)^{n-i}Bx^i$.
These fields tend to have non-trivial class groups.
"""
function wildanger_field(n::Int, B::fmpz; check::Bool = true, cached::Bool = true)
  x = gen(Globals.Qx)
  f = x^n
  for i=0:n-1
    f += (-1)^(n-i)*B*x^i
  end
  return NumberField(f, "_\$", cached = cached, check = check)
end

function wildanger_field(n::Int, B::Integer; cached::Bool = true, check::Bool = true)
  return wildanger_field(n, fmpz(B), cached = cached, check = check)
end

@doc Markdown.doc"""
    quadratic_field(d::Integer) -> AnticNumberField, nf_elem
    quadratic_field(d::fmpz) -> AnticNumberField, nf_elem

Returns the field with defining polynomial $x^n -d$.
"""
function quadratic_field(d::fmpz; cached::Bool = true, check::Bool = true)
  x = gen(Globals.Qx)
  if nbits(d) > 100
    a = div(d, fmpz(10)^(ndigits(d, 10) - 4))
    b = mod(abs(d), 10^4)
    s = "sqrt($a..($(nbits(d)) bits)..$b)"
  else
    s = "sqrt($d)"
  end
  q, a = number_field(x^2-d, s, cached = cached, check = check)
  set_special(q, :show => show_quad)
  return q, a
end

function show_quad(io::IO, q::AnticNumberField)
  d = trail(q.pol)
  if d < 0
    print(io, "Real quadratic field by ", q.pol)
  else
    print(io, "Imaginary quadratic field by ", q.pol)
  end
end

function quadratic_field(d::Integer; cached::Bool = true, check::Bool = true)
  return quadratic_field(fmpz(d), cached = cached, check = check)
end

function rationals_as_number_field()
  x = gen(Globals.Qx)
  return number_field(x-1)
end

################################################################################
#
#  Characteristic
#
################################################################################

characteristic(::AnticNumberField) = 0

################################################################################
#
#  Predicates
#
################################################################################

@doc Markdown.doc"""
    isdefining_polynomial_nice(K::AnticNumberField)

Tests if the defining polynomial of $K$ is integral and monic.
"""
function isdefining_polynomial_nice(K::AnticNumberField)
  return Bool(K.flag & UInt(1))
end

################################################################################
#
#  Class group
#
################################################################################

@doc Markdown.doc"""
    class_group(K::AnticNumberField) -> GrpAbFinGen, Map

Shortcut for {{{class_group(maximal_order(K))}}}: returns the class
group as an abelian group and a map from this group to the set
of ideals of the maximal order.
"""
function class_group(K::AnticNumberField)
  return class_group(maximal_order(K))
end

################################################################################
#
#  Basis
#
################################################################################

function basis(K::AnticNumberField)
  n = degree(K)
  g = gen(K);
  d = Array{typeof(g)}(undef, n)
  b = K(1)
  for i = 1:n-1
    d[i] = b
    b *= g
  end
  d[n] = b
  return d
end

################################################################################
#
#  Torsion units and related functions
#
################################################################################

@doc Markdown.doc"""
    istorsion_unit(x::nf_elem, checkisunit::Bool = false) -> Bool

Returns whether $x$ is a torsion unit, that is, whether there exists $n$ such
that $x^n = 1$.

If `checkisunit` is `true`, it is first checked whether $x$ is a unit of the
maximal order of the number field $x$ is lying in.
"""
function istorsion_unit(x::nf_elem, checkisunit::Bool = false)
  if checkisunit
    _isunit(x) ? nothing : return false
  end

  K = parent(x)
  d = degree(K)
  c = conjugate_data_arb(K)
  r, s = signature(K)

  while true
    @vprint :UnitGroup 2 "Precision is now $(c.prec) \n"
    l = 0
    @vprint :UnitGroup 2 "Computing conjugates ... \n"
    cx = conjugates_arb(x, c.prec)
    A = ArbField(c.prec, false)
    for i in 1:r
      k = abs(cx[i])
      if k > A(1)
        return false
      elseif isnonnegative(A(1) + A(1)//A(6) * log(A(d))//A(d^2) - k)
        l = l + 1
      end
    end
    for i in 1:s
      k = abs(cx[r + i])
      if k > A(1)
        return false
      elseif isnonnegative(A(1) + A(1)//A(6) * log(A(d))//A(d^2) - k)
        l = l + 1
      end
    end

    if l == r + s
      return true
    end
    refine(c)
  end
end

@doc Markdown.doc"""
    torsion_unit_order(x::nf_elem, n::Int)

Given a torsion unit $x$ together with a multiple $n$ of its order, compute
the order of $x$, that is, the smallest $k \in \mathbb Z_{\geq 1}$ such
that $x^`k` = 1$.

It is not checked whether $x$ is a torsion unit.
"""
function torsion_unit_order(x::nf_elem, n::Int)
  ord = 1
  fac = factor(n)
  for (p, v) in fac
    p1 = Int(p)
    s = x^divexact(n, p1^v)
    if isone(s)
      continue
    end
    cnt = 0
    while !isone(s) && cnt < v+1
      s = s^p1
      ord *= p1
      cnt += 1
    end
    if cnt > v+1
      error("The element is not a torsion unit")
    end
  end
  return ord
end

#################################################################################################
#
#  Normal Basis
#
#################################################################################################

@doc Markdown.doc"""
    normal_basis(K::Nemo.AnticNumberField) -> nf_elem

Given a number field K which is normal over Q, return 
an element generating a normal basis of K over Q.
"""
function normal_basis(K::Nemo.AnticNumberField)
  
  O = EquationOrder(K)
  Qx = parent(K.pol)
  d = discriminant(O)
  p = 1
  for q in PrimesSet(degree(K), -1)
    if divisible(d, q)
      continue
    end
    #Now, I check if p is totally split
    R = GF(q, cached = false)
    Rt, t = PolynomialRing(R, "t", cached = false)
    ft = Rt(K.pol)
    pt = powmod(t, q, ft)
    if degree(gcd(ft, pt-t)) == degree(ft)
      p = q
      break
    end
  end
  #Now, I only need to lift an idempotent of O/pO
  R = GF(p, cached = false)
  Rx, x = PolynomialRing(R, "x", cached = false)
  f = Rx(K.pol)
  fac = factor(f)
  g = divexact(f, first(keys(fac.fac)))
  Zy, y = PolynomialRing(FlintZZ, "y", cached = false)
  g1 = lift(Zy, g)
  return K(g1)
  
end

################################################################################
#
#  Subfield check
#
################################################################################

function _issubfield(K::AnticNumberField, L::AnticNumberField)
  f = K.pol
  R = roots(f, L, max_roots = 1)
  if isempty(R)
    return false, L()
  else
    h = parent(L.pol)(R[1])
    return true, h(gen(L))
  end 
end

function _issubfield_first_checks(K::AnticNumberField, L::AnticNumberField)
  f = K.pol
  g = L.pol
  if mod(degree(g), degree(f)) != 0
    return false
  end
  t = divexact(degree(g), degree(f))
  try
    OK = _get_maximal_order_of_nf(K)
    OL = _get_maximal_order_of_nf(L)
    if mod(discriminant(OL), discriminant(OK)^t) != 0
      return false
    end
  catch e
    if !isa(e, AccessorNotSetError)
      rethrow(e)
    end
    # We could factorize the discriminant of f, but we only test small primes.
    p = 3
    df = discriminant(f)
    dg = discriminant(g)
    while p < 10000
      if p > df || p > dg
        break
      end
      if mod(valuation(df, p), 2) == 0
        p = next_prime(p)
        continue
      end
      if mod(dg, p^t) != 0
        return false
      end
      p = next_prime(p)
    end
  end
  return true
end

@doc Markdown.doc"""
      issubfield(K::AnticNumberField, L::AnticNumberField) -> Bool, NfToNfMor

Returns "true" and an injection from $K$ to $L$ if $K$ is a subfield of $L$.
Otherwise the function returns "false" and a morphism mapping everything to 0.
"""
function issubfield(K::AnticNumberField, L::AnticNumberField)
  fl = _issubfield_first_checks(K, L)
  if !fl
    return false, hom(K, L, zero(L), check = false)
  end
  b, prim_img = _issubfield(K, L)
  return b, hom(K, L, prim_img, check = false)
end


function _issubfield_normal(K::AnticNumberField, L::AnticNumberField)
  f = K.pol
  f1 = change_base_ring(L, f)
  r = roots(f1, max_roots = 1, isnormal = true)
  if length(r) > 0
    h = parent(L.pol)(r[1])
    return true, h(gen(L))
  else
    return false, L()
  end 
end

@doc Markdown.doc"""
      issubfield_normal(K::AnticNumberField, L::AnticNumberField) -> Bool, NfToNfMor

Returns `true` and an injection from $K$ to $L$ if $K$ is a subfield of $L$.
Otherwise the function returns "false" and a morphism mapping everything to 0.
>
This function assumes that K is normal.
"""
function issubfield_normal(K::AnticNumberField, L::AnticNumberField)
  fl = _issubfield_first_checks(K, L)
  if !fl
    return false, hom(K, L, zero(L), check = false)
  end
  b, prim_img = _issubfield_normal(K, L)
  return b, hom(K, L, prim_img, check = false)

end

################################################################################
#
#  Isomorphism
#
################################################################################

@doc Markdown.doc"""
    isisomorphic(K::AnticNumberField, L::AnticNumberField) -> Bool, NfToNfMor

Returns "true" and an isomorphism from $K$ to $L$ if $K$ and $L$ are isomorphic.
Otherwise the function returns "false" and a morphism mapping everything to 0.
"""
function isisomorphic(K::AnticNumberField, L::AnticNumberField)
  f = K.pol
  g = L.pol
  if degree(f) != degree(g)
    return false, hom(K, L, zero(L), check = false)
  end
  if signature(K) != signature(L)
    return false, hom(K, L, zero(L), check = false)
  end
  try
    OK = _get_maximal_order_of_nf(K)
    OL = _get_maximal_order_of_nf(L)
    if discriminant(OK) != discriminant(OL)
      return false, hom(K, L, zero(L), check = false)
    end
  catch e
    if !isa(e, AccessorNotSetError)
      rethrow(e)
    end
    t = discriminant(f)//discriminant(g)
    if !issquare(numerator(t)) || !issquare(denominator(t))
      return false, hom(K, L, zero(L), check = false)
    end
  end
  b, prim_img = _issubfield(K, L)
  if !b
    return b, hom(K, L, zero(L), check = false)
  else
    return b, hom(K, L, prim_img, check = false, compute_inverse = true)
  end
end

################################################################################
#
#  Compositum
#
################################################################################

@doc Markdown.doc"""
    compositum(K::AnticNumberField, L::AnticNumberField) -> AnticNumberField, Map, Map

Assuming $L$ is normal (which is not checked), compute the compositum $C$ of the
2 fields together with the embedding of $K \to C$ and $L \to C$.
"""
function compositum(K::AnticNumberField, L::AnticNumberField)
  lf = factor(K.pol, L)
  d = degree(first(lf.fac)[1])
  if any(x->degree(x) != d, keys(lf.fac))
    error("2nd field cannot be normal")
  end
  KK = NumberField(first(lf.fac)[1])[1]
  Ka, m1, m2 = absolute_field(KK)
  return Ka, hom(K, Ka, preimage(m1, gen(KK))), m2
end

################################################################################
#
#  Serialization
#
################################################################################

# This function can be improved by directly accessing the numerator
# of the fmpq_poly representing the nf_elem
@doc Markdown.doc"""
    write(io::IO, A::Array{nf_elem, 1}) -> Nothing

Writes the elements of `A` to `io`. The first line are the coefficients of
the defining polynomial of the ambient number field. The following lines
contain the coefficients of the elements of `A` with respect to the power
basis of the ambient number field.
"""
function write(io::IO, A::Array{nf_elem, 1})
  if length(A) == 0
    return
  else
    # print some useful(?) information
    print(io, "# File created by Hecke $VERSION_NUMBER, $(Base.Dates.now()), by function 'write'\n")
    K = parent(A[1])
    polring = parent(K.pol)

    # print the defining polynomial
    g = K.pol
    d = denominator(g)

    for j in 0:degree(g)
      print(io, coeff(g, j)*d)
      print(io, " ")
    end
    print(io, d)
    print(io, "\n")

    # print the elements
    for i in 1:length(A)

      f = polring(A[i])
      d = denominator(f)

      for j in 0:degree(K)-1
        print(io, coeff(f, j)*d)
        print(io, " ")
      end

      print(io, d)

      print(io, "\n")
    end
  end
end

@doc Markdown.doc"""
    write(file::String, A::Array{nf_elem, 1}, flag::ASCIString = "w") -> Nothing

Writes the elements of `A` to the file `file`. The first line are the coefficients of
the defining polynomial of the ambient number field. The following lines
contain the coefficients of the elements of `A` with respect to the power
basis of the ambient number field.
>
Unless otherwise specified by the parameter `flag`, the content of `file` will be
overwritten.
"""
function write(file::String, A::Array{nf_elem, 1}, flag::String = "w")
  f = open(file, flag)
  write(f, A)
  close(f)
end

# This function has a bad memory footprint
@doc Markdown.doc"""
    read(io::IO, K::AnticNumberField, ::Type{nf_elem}) -> Array{nf_elem, 1}

Given a file with content adhering the format of the `write` procedure,
this functions returns the corresponding object of type `Array{nf_elem, 1}` such that
all elements have parent $K$.

**Example**

    julia> Qx, x = FlintQQ["x"]
    julia> K, a = NumberField(x^3 + 2, "a")
    julia> write("interesting_elements", [1, a, a^2])
    julia> A = read("interesting_elements", K, Hecke.nf_elem)
"""
function read(io::IO, K::AnticNumberField, ::Type{Hecke.nf_elem})
  Qx = parent(K.pol)

  A = Array{nf_elem, 1}()

  i = 1

  for ln in eachline(io)
    if ln[1] == '#'
      continue
    elseif i == 1
      # the first line read should contain the number field and will be ignored
      i = i + 1
    else
      coe = map(Hecke.fmpz, split(ln, " "))
      t = fmpz_poly(Array(slice(coe, 1:(length(coe) - 1))))
      t = Qx(t)
      t = divexact(t, coe[end])
      push!(A, K(t))
      i = i + 1
    end
  end

  return A
end

@doc Markdown.doc"""
    read(file::String, K::AnticNumberField, ::Type{nf_elem}) -> Array{nf_elem, 1}

Given a file with content adhering the format of the `write` procedure,
this functions returns the corresponding object of type `Array{nf_elem, 1}` such that
all elements have parent $K$.

**Example**

    julia> Qx, x = FlintQQ["x"]
    julia> K, a = NumberField(x^3 + 2, "a")
    julia> write("interesting_elements", [1, a, a^2])
    julia> A = read("interesting_elements", K, Hecke.nf_elem)
"""
function read(file::String, K::AnticNumberField, ::Type{Hecke.nf_elem})
  f = open(file, "r")
  A = read(f, K, Hecke.nf_elem)
  close(f)
  return A
end

#TODO: get a more intelligent implementation!!!
@doc Markdown.doc"""
    splitting_field(f::fmpz_poly) -> AnticNumberField
    splitting_field(f::fmpq_poly) -> AnticNumberField

Computes the splitting field of $f$ as an absolute field.
"""
function splitting_field(f::fmpz_poly; do_roots::Bool = false)
  Qx = PolynomialRing(FlintQQ, parent(f).S, cached = false)[1]
  return splitting_field(Qx(f), do_roots = do_roots)
end

function splitting_field(f::fmpq_poly; do_roots::Bool = false)
  return splitting_field([f], do_roots = do_roots)
end

function splitting_field(fl::Array{fmpz_poly, 1}; coprime::Bool = false, do_roots::Bool = false)
  Qx = PolynomialRing(FlintQQ, parent(fl[1]).S, cached = false)[1]
  return splitting_field([Qx(x) for x = fl], coprime = coprime, do_roots = do_roots)
end

function splitting_field(fl::Array{fmpq_poly, 1}; coprime::Bool = false, do_roots::Bool = false)
  if !coprime
    fl = coprime_base(fl)
  end
  ffl = fmpq_poly[]
  for x = fl
    append!(ffl, collect(keys(factor(x).fac)))
  end
  fl = ffl
  r = []
  if do_roots
    r = [roots(x)[1] for x = fl if degree(x) == 1]
  end
  fl = fl[findall(x->degree(x) > 1, fl)]
  if length(fl) == 0
    if do_roots
      return FlintQQ, r
    else
      return FlintQQ
    end
  end
  K, a = number_field(fl[1])#, check = false, cached = false)

  @assert fl[1](a) == 0
  gl = [change_base_ring(fl[1], K)]
  gl[1] = divexact(gl[1], gen(parent(gl[1])) - a)
  for i=2:length(fl)
    push!(gl, change_base_ring(fl[i], K))
  end

  if do_roots
    K, R = splitting_field(gl, coprime = true, do_roots = true)
    return K, vcat(r, [a], R)
  else
    return splitting_field(gl, coprime = true, do_roots = false)
  end
end


copy(f::fmpq_poly) = parent(f)(f)
gcd_into!(a::fmpq_poly, b::fmpq_poly, c::fmpq_poly) = gcd(b, c)

@doc Markdown.doc"""
    splitting_field(f::PolyElem{nf_elem}) -> AnticNumberField

Computes the splitting field of $f$ as an absolute field.
"""
splitting_field(f::PolyElem{nf_elem}; do_roots::Bool = false) = splitting_field([f], do_roots = do_roots)


function splitting_field(fl::Array{<:PolyElem{nf_elem}, 1}; do_roots::Bool = false, coprime::Bool = false)
  if !coprime
    fl = coprime_base(fl)
  end
  ffl = []
  for x = fl
    append!(ffl, collect(keys(factor(x).fac)))
  end
  fl = ffl
  r = []
  if do_roots
    r = [roots(x)[1] for x = fl if degree(x) == 1]
  end
  lg = [k for k = fl if degree(k) > 1]
  if length(lg) == 0
    if do_roots
      return base_ring(fl[1]), r
    else
      return base_ring(fl[1])
    end
  end

  K, a = number_field(lg[1])#, check = false)
  Ks, nk, mk = absolute_field(K)
  
  ggl = [change_base_ring(lg[1], mk)]
  ggl[1] = divexact(ggl[1], gen(parent(ggl[1])) - preimage(nk, a))

  for i = 2:length(lg)
    push!(ggl, change_base_ring(lg[i], mk))
  end
  if do_roots
    R = [mk(x) for x = r] 
    push!(R, preimage(nk, a))
    Kst, t = PolynomialRing(Ks, cached = false)
    return splitting_field(vcat(ggl, [t-y for y in R]), coprime = true, do_roots = true)
  else
    return splitting_field(ggl, coprime = true, do_roots = false)
  end
end

function Base.:(^)(a::nf_elem, e::UInt)
  b = parent(a)()
  ccall((:nf_elem_pow, :libantic), Nothing,
        (Ref{nf_elem}, Ref{nf_elem}, UInt, Ref{AnticNumberField}),
        b, a, e, parent(a))
  return b
end


@doc Markdown.doc"""
    normal_closure(K::AnticNumberField) -> AnticNumberField, NfToNfMor
The normal closure of $K$ together with the embedding map.
"""
function normal_closure(K::AnticNumberField)
  s = splitting_field(K.pol)
  r = roots(K.pol, s)[1]
  return s, hom(K, s, r, check = false)
end

function show_name(io::IO, K::AnticNumberField)
  if get(io, :compact, false)
    n = Nemo.get_special(K, :name)
    print(io, n)
  else
    print(io, "Number field over Rational Field")
    print(io, " with defining polynomial ", K.pol)
  end
end

function set_name!(K::AnticNumberField, s::String)
  Nemo.set_special(K, :name => s, :show => show_name)
end

function set_name!(K::AnticNumberField)
  s = find_name(K)
  s === nothing || set_name!(K, string(s))
end

################################################################################
#
#  Is linearly disjoint
#
################################################################################

function islinearly_disjoint(K1::AnticNumberField, K2::AnticNumberField)
  if gcd(degree(K1), degree(K2)) == 1
    return true
  end
  d1 = numerator(discriminant(K1.pol))
  d2 = numerator(discriminant(K2.pol))
  if gcd(d1, d2) == 1
    return true
  end
  try
    OK1 = _get_maximal_order(K1)
    OK2 = _get_maximal_order(K2)
    if iscoprime(discriminant(K1), discriminant(K2))
      return true
    end
  catch e
    if !isa(e, AccessorNotSetError)
      rethrow(e)
    end
  end
  f = change_base_ring(K2, K1.pol)
  return isirreducible(f)
end
