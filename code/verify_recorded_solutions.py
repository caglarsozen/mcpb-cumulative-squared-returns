"""Audit recorded sufficient statistics; this does not refit forecasting models."""
from pathlib import Path
import json
import numpy as np
import pandas as pd
from scipy.optimize import nnls

ROOT=Path(__file__).resolve().parents[1]
parts=sorted((ROOT/'evidence/choices').glob('part-*.csv'))
frame=pd.concat([pd.read_csv(p,float_precision='round_trip') for p in parts],ignore_index=True)
(ROOT/'validation').mkdir(exist_ok=True)
worst=0.0
for _,r in frame.iterrows():
    A=np.array([[r.q11+r['lambda'],r.q12],[r.q12,r.q22+r['lambda']]])
    B=np.array([r.b1,r.b2+r['lambda']])
    beta=np.array([r.betaR_MCPB,r.betaE_MCPB])
    assert np.all(beta>=0)
    g=A@beta-B
    scale=max(np.max(np.abs(B)),np.max(np.abs(A@beta)),1e-30)
    dual=max(0.,-np.min(g))/scale
    comp=np.max(np.abs(beta*g))/(scale*max(1.,np.max(beta)))
    active=beta>1e-12
    stat=np.max(np.abs(g[active]))/scale if np.any(active) else 0.
    worst=max(worst,dual,comp,stat)
assert worst<2e-7
assert (frame.max_partial_target<=frame.origin).all()
assert (frame.native_fit_cut<=frame.origin).all()
rows=[]
for _,g in frame.groupby(['asset','protocol','H'],sort=False):
    for ix in [0,len(g)//2,len(g)-1]:
        r=g.iloc[ix]
        A=np.array([[r.q11+r['lambda'],r.q12],[r.q12,r.q22+r['lambda']]])
        B=np.array([r.b1,r.b2+r['lambda']])
        L=np.linalg.cholesky(A)
        independent,_=nnls(L.T,np.linalg.solve(L,B))
        recorded=np.array([r.betaR_MCPB,r.betaE_MCPB])
        rows.append(dict(asset=r.asset,protocol=r.protocol,H=int(r.H),origin=int(r.origin),
           max_abs_beta_difference=float(np.max(np.abs(independent-recorded)))))
checks=pd.DataFrame(rows)
assert len(checks)==360 and checks.max_abs_beta_difference.max()<1e-8
checks.to_csv(ROOT/'validation/RECORDED_QB_NNLS_360.csv',index=False)
report={'recorded_origins':len(frame),'independent_nnls_checks':len(checks),
 'max_scaled_KKT_residual':worst,'max_absolute_coefficient_difference':float(checks.max_abs_beta_difference.max()),
 'all_recorded_partial_targets_mature':True,'all_recorded_base_fits_available':True,
 'scope':'Recorded Q,b and coefficients only; separate full-run and array audits cover fitting, targets and origin losses.'}
(ROOT/'validation/RECORDED_OPTIMIZATION_AUDIT.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
