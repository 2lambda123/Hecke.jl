abstract type AbelianExt end

mutable struct KummerExt <: AbelianExt
  zeta::nf_elem
  n::Int
  gen::Vector{FacElem{nf_elem, AnticNumberField}}

  AutG::GrpAbFinGen
  frob_cache::Dict{NfOrdIdl, GrpAbFinGenElem}
  frob_gens::Tuple{Vector{NfOrdIdl}, Vector{GrpAbFinGenElem}}
  gen_mod_nth_power::Vector{FacElem{nf_elem, AnticNumberField}}
  eval_mod_nth::Vector{nf_elem}
  
  function KummerExt()
    return new()
  end
end

function Base.show(io::IO, K::KummerExt)
  if isdefined(K.AutG, :snf)
    print(io, "KummerExt with structure $(K.AutG.snf)")
  else
    print(io, "KummerExt with structure $([K.AutG.rels[i, i] for i=1:ngens(K.AutG)])")
  end
end

@doc Markdown.doc"""
    kummer_extension(n::Int, gens::Vector{FacElem{nf_elem, AnticNumberField}}) -> KummerExt
Creates the Kummer extension of exponent $n$ generated by the elements in 'gens'.
"""
function kummer_extension(n::Int, gen::Vector{FacElem{nf_elem, AnticNumberField}})
  K = KummerExt()
  k = base_ring(gen[1])
  zeta, o = torsion_units_gen_order(k)
  @assert o % n == 0
  K.zeta = zeta^div(o, n)
  K.n = n
  K.gen = gen
  K.AutG = GrpAbFinGen(fmpz[n for i=gen])
  K.frob_cache = Dict{NfOrdIdl, GrpAbFinGenElem}()
  return K
end

function kummer_extension(exps::Array{Int, 1}, gens::Vector{FacElem{nf_elem, AnticNumberField}})
  K = KummerExt()
  k = base_ring(gens[1])
  zeta, o = torsion_units_gen_order(k)
  n = lcm(exps)
  @assert o % n == 0

  K.zeta = zeta^div(o, n)
  K.n = n
  K.gen = gens
  K.AutG = abelian_group(exps)
  K.frob_cache = Dict{NfOrdIdl, GrpAbFinGenElem}()
  return K
end

function kummer_extension(n::Int, gen::Array{nf_elem, 1})
  g = FacElem{nf_elem, AnticNumberField}[FacElem(x) for x in gen]
  return kummer_extension(n, g)
end

###############################################################################
#
#  Base Field
#
###############################################################################

function base_field(K::KummerExt)
  return base_ring(K.gen[1])
end

###############################################################################
#
#  Exponent of a Kummer extension
#
###############################################################################

function exponent(K::KummerExt)
  return Int(exponent(K.AutG))
end

###############################################################################
#
#  Degree
#
###############################################################################

function degree(K::KummerExt)
  return Int(order(K.AutG))
end

###############################################################################
#
#  IsCyclic
#
###############################################################################

function iscyclic(K::KummerExt)
  return isone(length(K.gen)) || iscyclic(K.AutG)
end

###############################################################################
#
#  From Kummer Extension to Number Field
#
###############################################################################

function number_field(K::KummerExt)
  k = base_field(K)
  kt = PolynomialRing(k, "t", cached = false)[1]
  pols = Array{elem_type(kt), 1}(undef, length(K.gen))
  for i = 1:length(pols)
    p = Vector{nf_elem}(undef, Int(order(K.AutG[i]))+1)
    p[1] = -evaluate(K.gen[i])
    for i = 2:Int(order(K.AutG[i]))
      p[i] = zero(k)
    end 
    p[end] = one(k)
    pols[i] = kt(p)
  end
  return number_field(pols, check = false, cached = false)
end

###############################################################################
#
#  Computation of Frobenius automorphisms
#
###############################################################################

function assure_gens_mod_nth_powers(K::KummerExt)
  if isdefined(K, :gen_mod_nth_power)
    return nothing
  end
  gens = Vector{FacElem{nf_elem, AnticNumberField}}(undef, length(K.gen))
  for i = 1:length(gens)
    gens[i] = RelSaturate._mod_exponents(K.gen[i], K.n)
  end
  K.gen_mod_nth_power = gens
  return nothing
end

@doc Markdown.doc"""
    canonical_frobenius(p::NfOrdIdl, K::KummerExt) -> GrpAbFinGenElem
Computes the element of the automorphism group of $K$ corresponding to the
Frobenius automorphism induced by the prime ideal $p$ of the base field of $K$.
It fails if the prime is a index divisor or if p divides the given generators
of $K$
"""
function canonical_frobenius(p::NfOrdIdl, K::KummerExt)
  @assert norm(p) % K.n == 1
  if haskey(K.frob_cache, p)
    return K.frob_cache[p]
  end
  Zk = order(p)
  if index(Zk) % minimum(p) == 0 
    #index divisors and residue class fields don't agree
    # ex: x^2-10, rcf of 29*Zk, 7. 239 is tricky...
    throw(BadPrime(p))
  end
  if !fits(Int, minimum(p, copy = false))
    return canonical_frobenius_fmpz(p, K)
  end
  assure_gens_mod_nth_powers(K)
  if degree(p) != 1
    F, mF = ResidueFieldSmall(Zk, p)
    mF1 = NfToFqNmodMor_easy(mF, number_field(Zk))
    aut = _compute_frob(K, mF1, p)
  else
    F2, mF2 = ResidueFieldSmallDegree1(Zk, p)
    mF3 = NfToGFMor_easy(mF2, number_field(Zk))
    aut = _compute_frob(K, mF3, p)
  end
  z = K.AutG(aut)
  K.frob_cache[p] = z
  return z
end

function _compute_frob(K, mF, p)
  z_p = image(mF, K.zeta)^(K.n-1)
 
  # K = k(sqrt[n_i](gen[i]) for i=1:length(gen)), an automorphism will be
  # K[i] -> zeta^divexact(n, n_i) * ? K[i]
  # Frob(sqrt[n](a), p) = sqrt[n](a)^N(p) (mod p) = zeta^r sqrt[n](a)
  # sqrt[n](a)^N(p) = a^(N(p)-1 / n) = zeta^r mod p

  aut = Array{fmpz, 1}(undef, length(K.gen))
  for j = 1:length(K.gen)
    ord_genj = Int(order(K.AutG[j]))
    ex = div(norm(p)-1, ord_genj)
    mu = image(mF, K.gen_mod_nth_power[j])^ex
    i = 0
    z_pj = z_p^divexact(K.n, ord_genj)
    while !isone(mu)
      i += 1
      @assert i <= K.n
      mu = mul!(mu, mu, z_pj)
    end
    aut[j] = fmpz(i)
  end
  return aut
end

function canonical_frobenius_fmpz(p::NfOrdIdl, K::KummerExt)
  @assert norm(p) % K.n == 1
  if haskey(K.frob_cache, p)
    return K.frob_cache[p]
  end
  Zk = order(p)
  if index(Zk) % minimum(p) == 0 
    #index divisors and residue class fields don't agree
    # ex: x^2-10, rcf of 29*Zk, 7. 239 is tricky...
    throw(BadPrime(p))
  end


  F, mF = ResidueField(Zk, p)
  #_mF = extend_easy(mF, number_field(Zk))
  mF1 = NfToFqMor_easy(mF, number_field(Zk))
  z_p = image(mF1, K.zeta)^(K.n-1)

  # K = k(sqrt[n_i](gen[i]) for i=1:length(gen)), an automorphism will be
  # K[i] -> zeta^divexact(n, n_i) * ? K[i]
  # Frob(sqrt[n](a), p) = sqrt[n](a)^N(p) (mod p) = zeta^r sqrt[n](a)
  # sqrt[n](a)^N(p) = a^(N(p)-1 / n) = zeta^r mod p

  aut = Array{fmpz, 1}(undef, length(K.gen))
  for j = 1:length(K.gen)
    ord_genj = Int(order(K.AutG[j]))
    ex = div(norm(p)-1, ord_genj)
    mu = image(mF1, K.gen[j], K.n)^ex  # can throw bad prime!
    i = 0
    z_pj = z_p^divexact(K.n, ord_genj)
    while !isone(mu)
      i += 1
      @assert i <= K.n
      mul!(mu, mu, z_pj)
    end
    aut[j] = fmpz(i)
  end
  z = K.AutG(aut)
  K.frob_cache[p] = z
  return z
end

#In this function, we are computing the image of $sqrt[n](g) under the Frobenius automorphism of p
function canonical_frobenius(p::NfOrdIdl, K::KummerExt, g::FacElem{nf_elem})
  Zk = order(p)
  if index(Zk) % minimum(p) == 0 
    throw(BadPrime(p))
  end

  if !fits(Int, minimum(p, copy = false))
    error("Oops")
  end
  
  @assert norm(p) % K.n == 1
  ex = div(norm(p)-1, K.n)
  
  #K = sqrt[n](gen), an automorphism will be
  # K[i] -> zeta^? K[i]
  # Frob(sqrt[n](a), p) = sqrt[n](a)^N(p) (mod p) = zeta^r sqrt[n](a)
  # sqrt[n](a)^N(p) = a^(N(p)-1 / n) = zeta^r mod p
  
  if degree(p) != 1
    F, mF = ResidueFieldSmall(Zk, p)
    mF1 = extend_easy(mF, nf(Zk))
    z_p = inv(mF1(K.zeta))
    mu = image(mF1, g, K.n)^ex  # can throw bad prime!
    i = 0
    while true
      if isone(mu)
        break
      end
      i += 1
      @assert i <= K.n
      mu = mul!(mu, mu, z_p)
    end
    return i
  else
    F2, mF2 = ResidueFieldSmallDegree1(Zk, p)
    mF3 = extend_easy(mF2, nf(Zk))
    z_p1 = inv(mF3(K.zeta))
    mu1 = image(mF3, g, K.n)^ex  # can throw bad prime!
    i = 0
    while true
      if isone(mu1)
        break
      end
      i += 1
      @assert i <= K.n
      mu1 = mul!(mu1, mu1, z_p1)
    end
    return i
  end
end


################################################################################
#
#  Frobenius for cft
#
################################################################################

# In this context, we are computing the Frobenius for conjugate prime ideals 
# We save the projection of the factor base, we can reuse them
#Computes a set of prime ideals of the base field of K such that the corresponding Frobenius
#automorphisms generate the automorphism group
function find_gens(K::KummerExt, S::PrimesSet, cp::fmpz=fmpz(1))
  if isdefined(K, :frob_gens)
    return K.frob_gens[1], K.frob_gens[2]
  end
  k = base_field(K)
  ZK = maximal_order(k)
  R = K.AutG 
  sR = Vector{GrpAbFinGenElem}(undef, length(K.gen))
  lp = Vector{NfOrdIdl}(undef, length(K.gen))
  
  indZK = index(ZK)
  q, mq = quo(R, GrpAbFinGenElem[], false)
  s, ms = snf(q)
  ind = 1
  threshold = max(div(degree(k), 5), 5)

  for p in S
    if cp % p == 0 || indZK % p == 0
      continue
    end
    @vprint :ClassField 2 "Computing Frobenius over $p\n"
    lP = prime_decomposition(ZK, p)
    LP = NfOrdIdl[P for (P, e) in lP if degree(P) < threshold]
    if isempty(LP)
      continue
    end
    #Compute the projections of the gens as gfp_poly.
    #I can use these projections for all the prime ideals, saving some time.
    f = R[1]
    D = Vector{Vector{gfp_poly}}(undef, length(K.gen))
    for i = 1:length(D)
      D[i] = Vector{gfp_poly}(undef, length(K.gen[i].fac))
    end
 
    first = false
    for P in LP
      try
        f = _canonical_frobenius_with_cache(P, K, first, D)
        @hassert :ClassField 1 f == canonical_frobenius(P, K)
        first = true
      catch e
        if !isa(e, BadPrime)
          rethrow(e)
        end
        continue
      end
      if iszero(mq(f))
        continue
      end
      #At least one of the coefficient of the element 
      #must be invertible in the snf form.
      el = ms\f
      to_be = false
      for w = 1:ngens(s)
        if gcd(s.snf[w], el.coeff[w]) == 1
          to_be = true
          break
        end
      end
      if !to_be
        continue
      end
      sR[ind] = f
      lp[ind] = P
      ind += 1
      q, mq = quo(R, sR[1:ind-1], false)
      s, ms = snf(q)
    end
    if order(s) == 1   
      break
    end
    @vprint :ClassField 3 "Index: $(exponent(s))^($(valuation(order(s), exponent(s))))\n"
  end
  K.frob_gens = (lp, sR)
  return lp, sR
end


function _canonical_frobenius_with_cache(p::NfOrdIdl, K::KummerExt, cached::Bool, D::Vector{Vector{gfp_poly}})
  @assert norm(p) % K.n == 1
  if haskey(K.frob_cache, p)
    return K.frob_cache[p]
  end
  Zk = order(p)

  assure_gens_mod_nth_powers(K)

  if degree(p) != 1
    F, mF = ResidueFieldSmall(Zk, p)
    mF1 = NfToFqNmodMor_easy(mF, number_field(Zk))
    aut = _compute_frob(K, mF1, p, cached, D)
  else
    F2, mF2 = ResidueFieldSmallDegree1(Zk, p)
    mF3 = NfToGFMor_easy(mF2, number_field(Zk))
    aut = _compute_frob(K, mF3, p, cached, D)
  end
  z = K.AutG(aut)
  K.frob_cache[p] = z
  return z
end

function _compute_frob(K, mF, p, cached, D)
  z_p = image(mF, K.zeta)^(K.n-1)
 
  # K = k(sqrt[n_i](gen[i]) for i=1:length(gen)), an automorphism will be
  # K[i] -> zeta^divexact(n, n_i) * ? K[i]
  # Frob(sqrt[n](a), p) = sqrt[n](a)^N(p) (mod p) = zeta^r sqrt[n](a)
  # sqrt[n](a)^N(p) = a^(N(p)-1 / n) = zeta^r mod p
  aut = Array{fmpz, 1}(undef, length(K.gen))
  for j = 1:length(K.gen)
    ord_genj = Int(order(K.AutG[j]))
    ex = div(norm(p)-1, ord_genj)
    mu = image(mF, K.gen_mod_nth_power[j], D[j], cached, K.n)^ex  # can throw bad prime!
    i = 0
    z_pj = z_p^divexact(K.n, ord_genj)
    while !isone(mu)
      i += 1
      @assert i <= K.n
      mu = mul!(mu, mu, z_pj)
    end
    aut[j] = fmpz(i)
  end
  return aut
end

################################################################################
#
#  IsSubfield
#
################################################################################

@doc Markdown.doc"""
    issubfield(K::KummerExt, L::KummerExt) -> Bool, Vector{Tuple{nf_elem, Vector{Int}}}
Given two kummer extensions of a base field $k$, returns true and and the data 
to define an injection from K to L if K is a subfield of L. Otherwise
the function returns false and a some meaningless data.
"""
function issubfield(K::KummerExt, L::KummerExt)
  @assert base_field(K) == base_field(L)  
  @assert divisible(exponent(L), exponent(K))
  #First, find prime number that might be ramified.
  norms = Vector{fmpz}(undef, length(K.gen)+length(L.gen)+1)
  for i = 1:length(K.gen)
    norms[i] = numerator(norm(K.gen[i]))
  end
  for i = 1:length(L.gen)
    norms[i+length(K.gen)] = numerator(norm(L.gen[i]))
  end
  norms[end] = fmpz(exponent(L))
  norms = coprime_base(norms)
  coprime_to = lcm(norms)
  res = Vector{Tuple{FacElem{nf_elem, AnticNumberField}, Vector{Int}}}(undef, length(K.gen))
  lP = find_gens(L, Vector{FacElem{nf_elem, AnticNumberField}}[K.gen], coprime_to)
  for i = 1:length(K.gen)
    fl, coord, rt = _find_embedding(L, K.gen[i], Int(order(K.AutG[i])), lP)
    if !fl
      return fl, res
    end
    res[i] = (rt, Int[Int(coord[j]) for j = 1:length(L.gen)])
  end
  return true, res
end


################################################################################
#
#  Kummer failure
#
################################################################################

@doc Markdown.doc"""
    kummer_failure(x::nf_elem, M::Int, N::Int) -> Int
Computes the the quotient of N and $[K(\zeta_M, \sqrt[N](x))\colon K(\zeta_M)]$, 
where $K$ is the field containing $x$ and $N$ divides $M$.  
"""
function kummer_failure(x::nf_elem, M::Int, N::Int)
  @assert divisible(M, N)
  K = parent(x)
  CE = cyclotomic_extension(K, M)
  el = CE.mp[2](x)
  lp = factor(N)
  deg = 1
  for (p, v) in lp
    e = 1
    y = x
    for i = v:-1:1
      fl, y = ispower(y, Int(p), with_roots_unity = true)
      if !fl
        e = v
        break
      end
    end
    deg *= Int(p)^e
  end
  @assert divisible(N, deg)
  return divexact(N, deg)
end

################################################################################
#
#  Reduction of Kummer generator
#
################################################################################


@doc Markdown.doc"""
    reduce_mod_powers(a::nf_elem, n::Int) -> nf_elem
    reduce_mod_powers(a::nf_elem, n::Int, primes::Array{NfOrdIdl, 1}) -> nf_elem
Given some non-zero algebraic integeri $\alpha$, try to find  $\beta$ s.th.
$\beta$ is "small" and $\alpha/\beta$ is an $n$-th power.
If the factorisation of $a$ into prime ideals is known, the ideals
should be passed in.
"""
function reduce_mod_powers(a::nf_elem, n::Int, primes::Array{NfOrdIdl, 1})
  # works quite well if a is not too large. There has to be an error
  # somewhere in the precision stuff...
  @vprint :ClassField 2 "reducing modulo $(n)-th powers\n"
  @vprint :ClassField 3 "starting with $a\n"
  return reduce_mod_powers(FacElem(a), n, primes)
end

function reduce_mod_powers(a::nf_elem, n::Int)
  return reduce_mod_powers(FacElem(a), n)
end

function reduce_mod_powers(a::FacElem{nf_elem, AnticNumberField}, n::Int, decom::Dict{NfOrdIdl, fmpz})
  a1 = RelSaturate._mod_exponents(a, n)
  c = conjugates_arb_log(a, 64)
  c1 = conjugates_arb_log(a1, 64)
  bn = maximum(fmpz[upper_bound(abs(x), fmpz) for x in c])
  bn1 = maximum(fmpz[upper_bound(abs(x), fmpz) for x in c1])
  if bn1 < root(bn, 2)
    b = compact_presentation(a1, n)
  else
    b = compact_presentation(a, n, decom = decom)
  end
  if any(!iszero(v % n) for (k, v) = b.fac)
    b1 = prod(nf_elem[k^(v % n) for (k, v) = b.fac if !iszero(v % n)])
  else
    b1 = one(base_ring(a))
  end
  d = denominator(b1, maximal_order(parent(b1)))
  k, d1 = ispower(d)
  if k > 1
    d = d1^(div(k, n) + 1)
  end
  b1 *= d^n  #non-optimal, but integral...
  return FacElem(b1)  
end

function reduce_mod_powers(a::FacElem{nf_elem, AnticNumberField}, n::Int, primes::Array{NfOrdIdl, 1})
  vals = fmpz[valuation(a, p) for p in primes]
  lp = Dict{NfOrdIdl, fmpz}(primes[i] => vals[i] for i = 1:length(primes) if !iszero(vals[i]))
  return reduce_mod_powers(a, n, lp)  
end

function reduce_mod_powers(a::FacElem{nf_elem, AnticNumberField}, n::Int)
  Zk = maximal_order(base_ring(a))
  lp = factor_coprime(a, IdealSet(Zk))
  lp1 = Dict{NfOrdIdl, fmpz}((x, fmpz(y)) for (x, y) in lp)
  return reduce_mod_powers(a, n, lp1)
end
