"""Compare a COMPLETE independent rerun against the frozen study summaries."""
from pathlib import Path
import sys,json,hashlib
import numpy as np
import pandas as pd
ROOT=Path(__file__).resolve().parents[1]
RUN=Path(sys.argv[1]).resolve()
assert (RUN/'RUN_STATUS.txt').read_text().splitlines()[0]=='COMPLETE'
keys={
 'SUMMARY_accuracy.csv':['asset','protocol','H','method'],
 'SUMMARY_inference.csv':['asset','protocol','H','method','benchmark','metric','block'],
 'SUMMARY_choices.csv':['asset','protocol','H','origin'],
 'Native_Timing.csv':['asset','protocol','native_cut']}
checks={};reports={}
for name,key in keys.items():
    old=pd.concat([pd.read_csv(p,float_precision='round_trip') for p in sorted((ROOT/'evidence/choices').glob('part-*.csv'))],ignore_index=True) if 'choices' in name else pd.read_csv(ROOT/'evidence'/name,float_precision='round_trip')
    new=pd.read_csv(RUN/name,float_precision='round_trip')
    old=old.set_index(key).sort_index();new=new.set_index(key).sort_index()
    assert old.index.is_unique and new.index.is_unique
    checks[name+'_keys']=old.index.equals(new.index)
    assert checks[name+'_keys'],name
    cols=old.select_dtypes(include='number').columns.intersection(new.columns)
    detail={}
    for col in cols:
        x=old[col].to_numpy();y=new[col].to_numpy()
        # Strict relative agreement, with a small rounding allowance near zero.
        ok=np.allclose(x,y,rtol=1e-8,atol=1e-13,equal_nan=True)
        checks[name+':'+col]=bool(ok)
        detail[col]={'max_absolute_difference':float(np.nanmax(np.abs(x-y))) if np.any(np.isfinite(x-y)) else 0.0,'passed':bool(ok)}
    reports[name]={'rows':len(old),'columns':detail}
parity=pd.read_csv(RUN/'REFERENCE_PARITY_CHECKS.csv')
checks['all_2400_parent_parity_checks']=len(parity)==2400 and bool(parity.passed.all())
functional=pd.read_csv(RUN/'SELFTESTS.csv')
checks['all_14_R_functional_checks']=len(functional)==14 and bool(functional.passed.all())
cases=list((RUN/'cases').glob('*/forecast_arrays.rds'))
checks['120_fresh_fitted_arrays']=len(cases)==120
checks['120_origin_loss_files']=len(list((RUN/'cases').glob('*/origin_losses.csv')))==120
checks['unchanged_core']=hashlib.md5((RUN/'SOURCE_MCPB.R').read_bytes()).hexdigest()=='7198511bb116a1cd872cc25dc94122cc'
checks={k:bool(v) for k,v in checks.items()}
report={'date':'2026-11-11','passed':sum(checks.values()),'total':len(checks),'checks':checks,'comparisons':reports,
 'scope':'Fresh fitting and ridge selection for all 120 MCPB designs, daily calibration, and 4999 moving-block bootstrap draws per block setting. Additional parent benchmarks and historical TV estimators are not refitted.',
 'bootstrap_refits_models_inside_draws':False,'untouched_new_test_period':False}
(ROOT/'validation/FULL_RERUN_COMPARISON_20261111.json').write_text(json.dumps(report,indent=2)+'\n')
assert all(checks.values()),[k for k,v in checks.items() if not v]
print(json.dumps({'passed':report['passed'],'total':report['total'],'rows':{k:v['rows'] for k,v in reports.items()}},indent=2))
