"""Exact rational error budgets plus numerical sweeps of the integer implementation.

Sweeps check the bit-accurate reference; separate cycle tests check actual RTL.
"""
from pathlib import Path
from fractions import Fraction as Q
from math import exp as real_exp,erf,sqrt,factorial
import json,re
from fixed_reference import exp,gelu_wide
root=Path(__file__).resolve().parents[2]
target=Q(1,100000)
exp_remainder=32*Q(1,2**8*factorial(8))
exp_rounding=Q(100,1<<48)+Q(1,1<<23)
gelu_remainder=Q(2,5)*Q(6**118,2**58*factorial(58)*117)
gelu_rounding=Q(47*(1<<27),1<<64)+Q(1,1<<23)
# Phi(6)<0.4*exp(-18)<0.4/2^25; exp(18)>2^25 follows from its positive series.
assert sum(Q(18**k,factorial(k)) for k in range(50))>(1<<25)
gelu_tail=Q(2,5*(1<<25))
assert exp_remainder+exp_rounding<target
assert gelu_remainder+gelu_rounding<target and gelu_tail<target
# Certify nearest-even PHI_ZERO_Q64 using rational Machin arctangent intervals.
def atan_interval(q):
    terms=40;s=sum(Q((-1)**k,(2*k+1)*q**(2*k+1)) for k in range(terms))
    next_term=Q((-1)**terms,(2*terms+1)*q**(2*terms+1))
    return min(s,s+next_term),max(s,s+next_term)
a,b=atan_interval(5);c,d=atan_interval(239)
pi_lower,pi_upper=16*a-4*d,16*b-4*c
coefficient=7359186146747302452
assert 2*pi_upper*(2*coefficient-1)**2<(1<<130)
assert 2*pi_lower*(2*coefficient+1)**2>(1<<130)
literal_coefficients=[int(x) for x in re.findall(r"64'sd(\d+)",(root/'rtl/arithmetic/exp_unit.sv').read_text())]
assert literal_coefficients==[round(Q(1<<48,factorial(k))) for k in range(8)]
assert f"64'd{coefficient}" in (root/'rtl/arithmetic/gelu_unit.sv').read_text()
max_gelu=(0.0,0);max_exp=(0.0,0)
for raw in range(-32768,32768):
    x=raw/1024;observed=gelu_wide(raw)/(1<<22)
    exact=x*0.5*(1+erf(x/sqrt(2)))
    error=abs(observed-exact)
    if error>max_gelu[0]:max_gelu=(error,raw)
    assert error<1e-5,(raw,observed,exact)
samples=set(range(-4096,1))|{-i*2048 for i in range(8193)}|{-(16<<20)-1,-(16<<20)+1}
for raw in samples:
    observed=exp(raw)/(1<<22);exact=real_exp(raw/(1<<20));error=abs(observed-exact)
    if error>max_exp[0]:max_exp=(error,raw)
    assert error<1e-5,(raw,observed,exact)
report={'status':'PASS','date':'2026-10-17','absolute_error_target':float(target),
 'exp':{'degree':7,'range_reduction':32,'squarings':5,'internal_fractional_bits':48,
   'lagrange_after_squaring_bound':float(exp_remainder),'total_output_error_bound':float(exp_remainder+exp_rounding),
   'sampled_inputs':len(samples),'maximum_sampled_error':max_exp[0],'worst_sample_raw_Q20':max_exp[1]},
 'gelu':{'last_series_index':57,'degree':116,'internal_fractional_bits':64,'output_fractional_bits':22,
   'lagrange_bound':float(gelu_remainder),'total_output_error_bound':float(gelu_remainder+gelu_rounding),
   'tail_bound':float(gelu_tail),'exhaustive_Q10_inputs':65536,'maximum_swept_error':max_gelu[0],
   'worst_input_raw_Q10':max_gelu[1],'phi_zero_coefficient_rounding_certified':True},
 'scope':'function outputs and identical signed32/F22 FFN hidden storage, relative to the exact function of represented input; later linear output conversions are separate',
 'sources':['https://dlmf.nist.gov/7.6.E1','https://dlmf.nist.gov/4.2']}
(root/'rtl/tests/taylor-accuracy-results.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
