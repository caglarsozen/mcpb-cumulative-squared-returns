"""Regenerate the manuscript's tables and vector figures from frozen results.

This export does not fit models, retune settings, or change the asset universe.
Run: python build_outputs.py (Python 3; numpy, pandas, matplotlib).
"""
from pathlib import Path
import argparse
import hashlib
import json
import shutil
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.colors import TwoSlopeNorm

ROOT = Path(__file__).resolve().parent
E = ROOT / 'evidence'
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--results-dir',type=Path,help='Optional COMPLETE numerical rerun; default is the supplied frozen summaries.')
parser.add_argument('--output-dir',type=Path,help='Destination for regenerated publication outputs.')
args=parser.parse_args()
NUM=args.results_dir.resolve() if args.results_dir else E
if args.results_dir:
    status=NUM/'RUN_STATUS.txt'
    assert status.exists() and status.read_text().splitlines()[0].strip()=='COMPLETE', 'A COMPLETE numerical run is required.'
OUT=args.output_dir.resolve() if args.output_dir else ((NUM/'publication') if args.results_dir else ROOT/'outputs/frozen')
OUT.mkdir(parents=True,exist_ok=True)
T = OUT / 'tables'
F = OUT / 'figures'
for p in [T, F]:
    p.mkdir(exist_ok=True)
A = pd.read_csv(NUM / 'SUMMARY_accuracy.csv',float_precision='round_trip')
I = pd.read_csv(NUM / 'SUMMARY_inference.csv',float_precision='round_trip')
choice_path=NUM/'SUMMARY_choices.csv'
C = pd.read_csv(choice_path,float_precision='round_trip') if choice_path.exists() else pd.concat([pd.read_csv(p,float_precision='round_trip') for p in sorted((NUM/'choices').glob('part-*.csv'))],ignore_index=True)
ASSETS = ['BTC-USD','ETH-USD','SPY','GLD','TLT','QQQ','IWM','EFA','EEM','XLF','XLE','XLU','SLV','LQD','VNQ']
SHORT = [a.replace('-USD','') for a in ASSETS]
H30 = A[A.H.eq(30)]
BASE = H30[H30.protocol.eq('expanding')].pivot(index='asset',columns='method',values='PathMSE').loc[ASSETS]
ROLL = H30[H30.protocol.eq('rolling')].pivot(index='asset',columns='method',values='PathMSE').loc[ASSETS]
PRIMARY = I[I.H.eq(30)&I.protocol.eq('expanding')&I.block.eq(30)&I.metric.eq('PathMSE')&I.family.eq('primary')].copy()
plt.rcParams.update({'font.family':'DejaVu Sans','font.size':11,'axes.spines.top':False,'axes.spines.right':False,
    'pdf.fonttype':42,'ps.fonttype':42,'axes.labelsize':11,'xtick.labelsize':10,'ytick.labelsize':10,
    'savefig.facecolor':'white'})

def table(name, caption, label, columns, rows, align, note):
    text = ['\\begin{table}[tbp]','\\centering\\small',r'\setlength{\tabcolsep}{4pt}',
        r'\renewcommand{\arraystretch}{1.12}', '\\caption{'+caption+'}', '\\label{'+label+'}',
        '\\begin{tabular}{'+align+'}',r'\toprule',' & '.join(columns)+r' \\',r'\midrule']
    text += [' & '.join(str(x) for x in row)+r' \\' for row in rows]
    text += [r'\bottomrule',r'\end{tabular}',r'\par\smallskip',r'\begin{minipage}{0.98\linewidth}\footnotesize',
        r'\textit{Notes:} '+note,r'\end{minipage}',r'\end{table}','']
    (T/name).write_text('\n'.join(text),encoding='utf-8')

def sci(x):
    exponent = int(np.floor(np.log10(x)))
    return '$'+f'{x/10**exponent:.3f}'+r'\times10^{'+str(exponent)+'}$'

def signed(x):
    return f'{x:+.2f}'

def pre(frame,control):
    return 100*(1-frame.MCPB/frame[control])

def save(fig,stem):
    fig.savefig(F/(stem+'.pdf'),bbox_inches='tight',pad_inches=.06)
    fig.savefig(F/(stem+'.png'),dpi=300,bbox_inches='tight',pad_inches=.06)
    plt.close(fig)

# Effective price samples: the 1 January 2025 boundary quote is excluded.
types = ['Crypto','Crypto','US equity','Gold','Treasury','US equity','US equity','Developed equity','Emerging equity',
         'Financial equity','Energy equity','Utility equity','Silver','Corporate bond','Real estate']
sample_rows=[]
sample_data=[]
for asset,short,kind in zip(ASSETS,SHORT,types):
    p=pd.read_csv(E/'prices'/('RAW_'+asset.replace('-','_')+'.csv'))
    p['Date']=pd.to_datetime(p.Date)
    p=p[p.Date.between('2019-01-01','2024-12-31')].sort_values('Date')
    price_col=next(c for c in ['Adjusted','Adj.Close','Close'] if c in p.columns)
    r=np.diff(np.log(p[price_col].to_numpy(float)))
    n=int(A[(A.asset.eq(asset))&A.H.eq(30)&A.protocol.eq('expanding')&A.method.eq('MCPB')].n.iloc[0])
    sample_rows.append([short,kind,len(p),len(r),f'{np.std(r,ddof=1)*100:.2f}',n])
    sample_data.append(dict(asset=asset,prices=len(p),returns=len(r),return_sd_pct=np.std(r,ddof=1)*100,n_test=n,last_price=p.Date.max().date().isoformat()))
pd.DataFrame(sample_data).to_csv(T/'T1_effective_samples.csv',index=False)
table('T1_sample.tex','Effective samples and evaluation sizes.','tab:sample',
    ['Asset','Exposure','Prices','Returns','SD (\\%)','Test $N$'],sample_rows,'llrrrr',
    'Prices span 1 January 2019--31 December 2024 for crypto and 2 January 2019--31 December 2024 for ETFs. '
    'The crypto test origins are 24 September 2023--21 November 2024; ETF test origins are '
    '13 September 2023--1 November 2024. All four horizons use these same origins within an asset. '
    'SD is the sample standard deviation of daily log returns in percent. A raw crypto quote dated 1 January 2025 is excluded.')

table('T2_controls.tex','Forecast combinations and identifying controls.','tab:controls',
    ['Combination','Updates','Available labels','Coefficient constraint'],[
    ['Ridge--EWMA','Monthly','Complete 40-step paths','$\\beta_R+\\beta_E=1$'],
    ['Daily 40','Daily','Complete 40-step paths','$\\beta_R+\\beta_E=1$'],
    ['Daily $H$','Daily','Complete $H$-step paths','$\\beta_R+\\beta_E=1$'],
    ['Maturity simplex','Daily','Horizon-specific maturity','$\\beta_R+\\beta_E=1$'],
    ['Calibrated EWMA','Daily','Horizon-specific maturity','$\\beta_R=0$'],
    ['Full-path positive','Daily','Complete $H$-step paths','No unit-sum restriction'],
    ['MCPB','Daily','Horizon-specific maturity','No unit-sum restriction'],
    ],'llll','All coefficients are nonnegative. The final three rows use the same quadratic penalty centered at EWMA; '
    'in the EWMA-only case the ridge coefficient is fixed at zero. Full-path positive regression uses the same '
    'penalty rule as MCPB, rather than an unregularized fit. The monthly base ridge forecasts are identical across these controls.')

rows=[]
for asset,short in zip(ASSETS,SHORT):
    rows.append([short,sci(BASE.loc[asset,'MCPB']),signed(pre(BASE,'EWMA')[asset]),signed(pre(BASE,'RidgeEWMA')[asset]),
        signed(pre(BASE,'NNLS_FullH')[asset]),signed(pre(ROLL,'RidgeEWMA')[asset])])
table('T3_asset_accuracy.tex','Path MSE and percentage MSE reductions (PRE, \\%) at $H=30$.','tab:asset_accuracy',
    ['Asset','MCPB MSE','vs. EWMA','vs. R--E','vs. Full-path','Roll. vs. R--E'],rows,'lrrrrr',
    'The MSE column and first three PRE columns use expanding estimation. The final column uses rolling estimation. '
    'PRE $=100(1-\\mathrm{MSE}_{\\rm MCPB}/\\mathrm{MSE}_{\\rm control})$; positive values favor MCPB. '
    'R--E denotes Ridge--EWMA; Full-path denotes the positive complete-path control. Percentages are descriptive point estimates.')

rows=[]
for method,label in [('Ridge','Ridge'),('EWMA','EWMA'),('RidgeEWMA','Ridge--EWMA'),('DailyMix40','Daily 40'),('DailyMixH','Daily $H$'),
    ('MaturityMix','Maturity simplex'),('CalEWMA','Calibrated EWMA'),('NNLS_FullH','Full-path positive')]:
    p1=pre(BASE,method);p2=pre(ROLL,method)
    rows.append([label,f'{(p1>0).sum()}/15',signed(np.median(p1)),f'{(p2>0).sum()}/15',signed(np.median(p2))])
table('T4_comparison_summary.tex','Comparative accuracy at $H=30$.','tab:summary',
    ['Control',r'\shortstack{Expanding\\lower MSE}',r'\shortstack{Expanding\\median PRE (\%)}',r'\shortstack{Rolling\\lower MSE}',r'\shortstack{Rolling\\median PRE (\%)}'],rows,'lrrrr',
    'A win means a lower observed path MSE, without a significance requirement. Medians are across the 15 asset-level PRE values, '
    'rather than a ratio of pooled panel losses. In the declared primary family only the expanding XLU--EWMA contrast is favorable '
    'and significant after Holm correction. No favorable Ridge--EWMA contrast and no contrast in the separate 60-test component family '
    'survives adjustment at 5\\%.')

rows=[]
for h in [10,20,30,40]:
    for protocol,label in [('expanding','Expanding'),('rolling','Rolling')]:
        m=A[A.H.eq(h)&A.protocol.eq(protocol)].pivot(index='asset',columns='method',values='PathMSE').loc[ASSETS]
        q=A[A.H.eq(h)&A.protocol.eq(protocol)].pivot(index='asset',columns='method',values='PathQLIKE').loc[ASSETS]
        p1=pre(m,'EWMA');p2=pre(m,'RidgeEWMA')
        rows.append([h,label,f'{(p1>0).sum()}/15',signed(np.median(p1)),f'{(p2>0).sum()}/15',signed(np.median(p2)),f'{(q.MCPB<q.RidgeEWMA).sum()}/15'])
table('T5_robustness.tex','Horizon, window, and loss sensitivity.','tab:robustness',
    ['$H$','Window','Wins/E','Median/E','Wins/R--E','Median/R--E','QLIKE/R--E'],rows,'rlrrrrr',
    'E denotes EWMA. MSE win counts and median PRE values occupy the four central columns. The final column counts lower QLIKE '
    'losses against Ridge--EWMA; no QLIKE ratio PRE is used. Horizons count observed returns, including weekends for crypto. '
    'These 120 related cases are descriptive sensitivities, not 120 independent replications.')

rows=[]
for asset,short in zip(ASSETS,SHORT):
    values=[short]
    for benchmark in ['EWMA','RidgeEWMA']:
        z=PRIMARY[PRIMARY.asset.eq(asset)&PRIMARY.benchmark.eq(benchmark)].iloc[0]
        values.extend([signed(z.PRE),f'[{z.PRE_low:.2f}, {z.PRE_high:.2f}]',f'{z.p_holm_primary:.4f}'])
    rows.append(values)
table('B1_primary_intervals.tex','Primary paired comparisons: expanding estimation, $H=30$.','tab:primary',
    ['Asset','PRE/E','95\\% interval','$p_{\\rm Holm}$','PRE/R--E','95\\% interval','$p_{\\rm Holm}$'],rows,'lrrrrrr',
    'The 30 tests form one joint Holm family. Intervals are pointwise 95\\% percentile moving-block bootstrap intervals '
    '(4,999 draws; block length 30), not simultaneous intervals. Centered two-sided tests and percentile intervals are different constructions; '
    'adjusted $p$ values determine significance. Positive PRE favors MCPB.')

rows=[]
for method,kappa in [('MCPB_kappa1e6',r'$10^{-6}$'),('MCPB',r'$10^{-4}$'),('MCPB_kappa1e2',r'$10^{-2}$')]:
    for protocol,label in [('expanding','Expanding'),('rolling','Rolling')]:
        m=A[A.H.eq(30)&A.protocol.eq(protocol)].pivot(index='asset',columns='method',values='PathMSE').loc[ASSETS]
        pr=100*(1-m[method]/m.RidgeEWMA); pe=100*(1-m[method]/m.EWMA)
        rows.append([kappa,label,f'{(pr>0).sum()}/15',signed(np.median(pr)),f'{(pe>0).sum()}/15'])
table('B2_regularization.tex','Fixed regularization sensitivity at $H=30$.','tab:regularization',
    ['$\\kappa$','Window','Wins/R--E','Median PRE/R--E','Wins/EWMA'],rows,'rlrrr',
    'The main value is $10^{-4}$. The other values are retained as sensitivities and do not replace the main setting after inspection. '
    'Counts and medians describe realized path MSE.')

parent=pd.read_csv(E/'parent_accuracy.csv')
rows=[]
for method,label in [('Ridge','Ridge'),('HAR_OLS','Direct HAR--OLS'),('Persistence','Persistence'),('Mean22','22-observation mean'),('RF_direct','Direct random forest'),('RF_PAV','RF with isotonic projection'),('HAR_iter_pos','Positive iterative HAR'),
    ('GARCH_t','GARCH-$t$'),('Stack_Global','Global stack'),('IncrementStack','Increment stack')]:
    rr=[]
    for protocol in ['expanding','rolling']:
        mm=H30[H30.protocol.eq(protocol)&H30.method.eq('MCPB')].set_index('asset').PathMSE.loc[ASSETS]
        ref=parent[parent.H.eq(30)&parent.protocol.eq(protocol)&parent.method.eq(method)].set_index('asset').PathMSE.loc[ASSETS]
        pp=100*(1-mm/ref);rr.extend([f'{(pp>0).sum()}/15',signed(np.median(pp))])
    rows.append([label]+rr)
table('B3_archival_benchmarks.tex','Matched archival benchmark comparisons at $H=30$.','tab:archival',
    ['Benchmark','Exp. wins','Exp. PRE (\\%)','Roll. wins','Roll. PRE (\\%)'],rows,'lrrrr',
    'PRE columns are asset-level medians. Ridge is reproduced in the current run. The additional HAR, persistence, moving-mean, RF, GARCH, and stack rows use matched parent-run summaries '
    'with the same inputs and evaluation origins. They were not refitted in the MCPB run. Their unavailable raw paths preclude '
    'new paired tests and detailed re-auditing of those forecasts; these points provide context, not additional significance evidence.')

# Separate historical TV study: never pool its forecasts with MCPB forecasts.
legacy=pd.read_csv(E/'S2_Original_TV_H30_Expanding.csv')
shape=pd.read_csv(E/'S4_Original_TV_Shape_Diagnostics.csv')
legacy=legacy[(legacy.H==30)&(legacy.protocol=='expanding')]
shape=shape[(shape.H==30)&(shape.protocol=='expanding')]
lp=legacy.pivot(index='asset',columns='method',values='PathMSE').loc[ASSETS]
variants=[('Ridge','Ridge'),('Ridge_NN','Nonnegative increments'),('Ridge_TV','TV increments'),
    ('Ridge_NN_TV','Nonnegative TV'),('Ridge_P','Ridge + persistence'),('Ridge_NN_P','Nonnegative + persistence'),
    ('Ridge_TV_P','TV + persistence'),('MTF_FR','Full TV + persistence'),('Persistence','Persistence')]
rows=[];legacy_export=[]
for method,label in variants:
    pp=100*(1-lp[method]/lp.Ridge)
    ss=shape[shape.method.eq(method)].set_index('asset').loc[ASSETS]
    rows.append([label,f'{(pp>0).sum()}/15',signed(np.median(pp)),f'{ss.mean_fused_edges.median():.2f}'])
    legacy_export.append(dict(method=method,label=label,wins=int((pp>0).sum()),median_PRE=float(np.median(pp)),median_asset_mean_fused=float(ss.mean_fused_edges.median())))
table('D1_legacy_ablation.tex','Separate historical TV--persistence study: descriptive component results.','tab:legacy_ablation',
    ['Variant','Lower MSE',r'\shortstack{Median\\PRE (\%)}',r'\shortstack{Median mean\\fused adjacencies}'],rows,'lrrr',
    'These archived $H=30$ expanding results concern the earlier TV procedure and its own ridge reference. They are not MCPB ablations. '
    'The underlying historical forecasts differ from the MCPB experts, so no cross-study paired comparison is made. Counts are out of 15 assets. '
    'The last column is the median across assets of the recorded mean number of equal neighboring increments (at most 29). '
    'The archive retains original tuning choices; no method is selected anew for this revision.')
pd.DataFrame(legacy_export).to_csv(T/'D1_legacy_ablation.csv',index=False)
rows=[]
for asset in ['BTC-USD','ETH-USD']:
    for method,label in [('Ridge','Ridge'),('Ridge_NN_TV','Nonnegative TV'),('MTF_FR','Full TV + persistence'),('Persistence','Persistence')]:
        v=shape[shape.asset.eq(asset)&shape.method.eq(method)].iloc[0]
        rows.append([asset.replace('-USD',''),label,f'{v.mean_segments:.2f}',f'{v.median_segments:.0f}',f'{v.p90_segments:.0f}',f'{v.mean_fused_edges:.2f}'])
table('D2_legacy_shape.tex','Recorded segment diagnostics for the historical TV study.','tab:legacy_shape',
    ['Asset','Variant',r'\shortstack{Mean\\segments}',r'\shortstack{Median\\segments}',r'\shortstack{90th pct.\\segments}',r'\shortstack{Mean\\fused adjacencies}'],rows,'llrrrr',
    'Each $H=30$ path has at most 30 segments and 29 adjacent increment differences. The summaries use the original archive\'s numerical tolerances. '
    'These are recorded moments and quantiles, not recovered per-origin histograms. They describe the historical procedure, whose forecasts differ from MCPB\'s. '
    'Few segments, where observed, do not by themselves establish lower forecast loss.')

rows=[];short_export=[]
for protocol,label in [('expanding','Expanding'),('rolling','Rolling')]:
    for metric,scope in [('H1_MSE','First observation'),('H1_5_MSE','First five'),('PathMSE','Complete path')]:
        mm=H30[H30.protocol.eq(protocol)].pivot(index='asset',columns='method',values=metric).loc[ASSETS]
        pe=100*(1-mm.MCPB/mm.EWMA);pr=100*(1-mm.MCPB/mm.RidgeEWMA)
        rows.append([label,scope,f'{(pe>0).sum()}/15',signed(np.median(pe)),f'{(pr>0).sum()}/15',signed(np.median(pr))])
        short_export.append(dict(protocol=protocol,metric=metric,wins_EWMA=int((pe>0).sum()),median_PRE_EWMA=float(np.median(pe)),wins_RidgeEWMA=int((pr>0).sum()),median_PRE_RidgeEWMA=float(np.median(pr))))
table('B4_short_horizons.tex','Near-term and complete-path MSE comparisons within $H=30$.','tab:short_horizons',
    ['Window','Scored coordinates','Wins/E','PRE/E (\\%)','Wins/R--E','PRE/R--E (\\%)'],rows,'llrrrr',
    'The first-observation loss scores $h=1$, the first-five loss averages $h=1,\\ldots,5$, and the complete-path loss averages $h=1,\\ldots,30$. '
    'These are restrictions of the same fitted $H=30$ forecasts, not separately fitted short-horizon methods. PRE columns show medians across assets; '
    'E denotes EWMA and R--E Ridge--EWMA. Counts and percentages are descriptive, without additional primary significance claims.')
pd.DataFrame(short_export).to_csv(T/'B4_short_horizons.csv',index=False)

# Figure 1: primary intervals. Tests and intervals retain their distinct meanings.
fig,axes=plt.subplots(1,2,figsize=(7.2,5.65),sharey=True)
y=np.arange(15)
for ax,b,label,color in zip(axes,['EWMA','RidgeEWMA'],['(a) Against EWMA','(b) Against Ridge–EWMA'],['#17648b','#a35b23']):
    z=PRIMARY[PRIMARY.benchmark.eq(b)].set_index('asset').loc[ASSETS]
    ax.hlines(y,z.PRE_low,z.PRE_high,color=color,lw=1.4)
    ax.scatter(z.PRE,y,s=20,c=color,zorder=3)
    sig=(z.p_holm_primary<.05)&(z.PRE>0)
    ax.scatter(z.loc[sig,'PRE'],y[sig],s=80,c='#111111',marker='*',zorder=4)
    ax.axvline(0,c='#555555',lw=.8)
    ax.set_title(label,fontsize=11,loc='left',pad=10)
    ax.set_xlabel('MSE reduction (%)')
    ax.grid(axis='x',alpha=.15)
    ax.set_xlim(-97,71)
axes[0].set_yticks(y,SHORT);axes[0].invert_yaxis()
fig.tight_layout(w_pad=1.8);save(fig,'F1_primary_intervals')

# Figure 2: complete scope. Values are not treated as independent trials.
grid=[]
for protocol in ['expanding','rolling']:
    for h in [10,20,30,40]:
        m=A[A.H.eq(h)&A.protocol.eq(protocol)].pivot(index='asset',columns='method',values='PathMSE').loc[ASSETS]
        grid.append(pre(m,'RidgeEWMA').to_numpy())
grid=np.array(grid).T
fig,ax=plt.subplots(figsize=(7.2,5.65))
im=ax.imshow(grid,cmap='RdBu',norm=TwoSlopeNorm(vmin=-40,vcenter=0,vmax=40),aspect='auto')
for row in range(15):
    for col in range(8):
        ax.text(col,row,f'{grid[row,col]:+.1f}',ha='center',va='center',fontsize=10,color='white' if abs(grid[row,col])>24 else '#111111')
ax.set_yticks(y,SHORT);ax.set_xticks(range(8),['E10','E20','E30','E40','R10','R20','R30','R40'])
ax.axvline(3.5,c='white',lw=3);ax.tick_params(length=0)
ax.set_xlabel('Expanding (E) and rolling (R), maximum horizon')
cb=fig.colorbar(im,ax=ax,pad=.025,fraction=.045,extend='both');cb.set_label('MSE reduction vs. Ridge–EWMA (%)')
fig.tight_layout();save(fig,'F2_all_cases')
pd.DataFrame(grid,index=ASSETS,columns=['E10','E20','E30','E40','R10','R20','R30','R40']).to_csv(T/'F2_plot_data.csv')

# Figure 3: fitted coefficient distributions, not confidence intervals.
z=C[C.H.eq(30)&C.protocol.eq('expanding')].copy()
z['level']=z.betaR_MCPB+z.betaE_MCPB
z['share']=np.where(z.level>0,z.betaE_MCPB/z.level,np.nan)
fig,axes=plt.subplots(1,2,figsize=(7.2,5.65),sharey=True)
for ax,col,title,ref in [(axes[0],'level','(a) Coefficient sum',1),(axes[1],'share','(b) EWMA share',None)]:
    vectors=[z[z.asset.eq(a)][col].dropna().to_numpy() for a in ASSETS]
    bp=ax.boxplot(vectors,positions=y,vert=False,widths=.55,whis=(5,95),showfliers=False,patch_artist=True,
        medianprops={'color':'#111111','linewidth':1},boxprops={'facecolor':'#cedfe8','edgecolor':'#17648b'},
        whiskerprops={'color':'#17648b'},capprops={'color':'#17648b'})
    if ref is not None: ax.axvline(ref,color='#666666',lw=.8,ls='--')
    ax.set_title(title,fontsize=11,loc='left',pad=10)
    ax.grid(axis='x',alpha=.15)
axes[0].set_yticks(y,SHORT);axes[0].invert_yaxis();axes[1].set_xlim(-.04,1.04)
fig.tight_layout(w_pad=2);save(fig,'F3_level_composition')
z.groupby('asset')[['level','share']].quantile([.05,.25,.5,.75,.95]).to_csv(T/'F3_plot_quantiles.csv')

# Figure 4: QLIKE is compared with differences, not percentages.
fig,axes=plt.subplots(1,2,figsize=(7.2,5.65),sharey=True)
qrows=[]
for ax,protocol,label in zip(axes,['expanding','rolling'],['(a) Expanding','(b) Rolling']):
    q=H30[H30.protocol.eq(protocol)].pivot(index='asset',columns='method',values='PathQLIKE').loc[ASSETS]
    for offset,b,color in [(-.12,'EWMA','#17648b'),(.12,'RidgeEWMA','#a35b23')]:
        delta=q[b]-q.MCPB
        ax.scatter(delta,y+offset,s=24,c=color,marker='o' if b=='EWMA' else 's',label='EWMA' if b=='EWMA' else 'Ridge–EWMA',zorder=3)
        for a,val in delta.items(): qrows.append(dict(asset=a,protocol=protocol,benchmark=b,loss_improvement=val))
    ax.axvline(0,c='#555555',lw=.8);ax.grid(axis='x',alpha=.15)
    ax.set_title(label,fontsize=11,loc='left',pad=10);ax.set_xlabel('Control QLIKE − MCPB QLIKE')
axes[0].set_yticks(y,SHORT);axes[0].invert_yaxis()
handles,labels=axes[1].get_legend_handles_labels()
fig.legend(handles,labels,loc='upper center',bbox_to_anchor=(.53,1.035),ncol=2,fontsize=10,frameon=False)
fig.tight_layout(w_pad=2,rect=[0,0,1,.97]);save(fig,'F4_qlike')
pd.DataFrame(qrows).to_csv(T/'F4_plot_data.csv',index=False)

# Appendix figure: points relative to the same monthly simplex reference.
methods=['MaturityMix','NNLS_FullH','CalEWMA','MCPB']
g=np.column_stack([100*(1-BASE[m]/BASE.RidgeEWMA) for m in methods])
fig,ax=plt.subplots(figsize=(7.2,5.65))
im=ax.imshow(g,cmap='RdBu',norm=TwoSlopeNorm(vmin=-40,vcenter=0,vmax=40),aspect='auto')
for row in range(15):
    for col in range(4):
        ax.text(col,row,f'{g[row,col]:+.1f}',ha='center',va='center',fontsize=10,color='white' if abs(g[row,col])>24 else '#111111')
ax.set_yticks(y,SHORT);ax.set_xticks(range(4),['Maturity\nsimplex','Full-path\npositive','Calibrated\nEWMA','MCPB']);ax.tick_params(length=0)
cb=fig.colorbar(im,ax=ax,pad=.025,fraction=.045,extend='both');cb.set_label('MSE reduction vs. Ridge–EWMA (%)')
fig.tight_layout();save(fig,'FB1_close_controls')

# Scope and reported-number checks, independent of the original R exporter.
checks={
 'accuracy_rows_1440':len(A)==1440,
 'inference_rows_6480':len(I)==6480,
 'choices_rows_36752':len(C)==36752,
 'fixed_universe_all_15':set(A.asset)==set(ASSETS),
 'complete_120_cases':len(A[['asset','protocol','H']].drop_duplicates())==120,
 'unique_accuracy_keys':not A.duplicated(['asset','protocol','H','method']).any(),
 'primary_30':len(PRIMARY)==30,
 'effective_crypto_prices_2192':all(s['prices']==2192 for s in sample_data[:2]),
 'all_effective_prices_end_2024':all(s['last_price']=='2024-12-31' for s in sample_data),
 'expanding_ridge_pav_equal_H30':bool(np.all(BASE.Ridge==BASE.Ridge_PAV)),
 'rw_expanding_11_wins':int((pre(BASE,'RidgeEWMA')>0).sum())==11,
 'rw_rolling_11_wins':int((pre(ROLL,'RidgeEWMA')>0).sum())==11,
 'rw_expanding_median_15_60':round(float(np.median(pre(BASE,'RidgeEWMA'))),2)==15.60,
 'rw_rolling_median_9_15':round(float(np.median(pre(ROLL,'RidgeEWMA'))),2)==9.15,
 'adverse_gld_slv_retained':bool((pre(BASE,'RidgeEWMA').loc[['GLD','SLV']]<0).all()),
}
manifest=pd.read_csv(E/'INPUT_MANIFEST.csv').set_index('asset')
checks['all_15_input_hashes_match']=all(
    hashlib.md5((E/'prices'/('RAW_'+a.replace('-','_')+'.csv')).read_bytes()).hexdigest()==manifest.loc[a,'md5']
    for a in ASSETS)
for family,col,n in [('primary','p_holm_primary',30),('component','p_holm_component',60)]:
    z=I[I.H.eq(30)&I.protocol.eq('expanding')&I.block.eq(30)&I.metric.eq('PathMSE')&I.family.eq(family)]
    p=z.bootstrap_p.to_numpy();order=np.argsort(p);adjust=np.minimum(1,np.maximum.accumulate(p[order]*np.arange(len(p),0,-1)))
    calculated=np.empty(len(p));calculated[order]=adjust
    checks[family+'_Holm_matches']=len(z)==n and bool(np.allclose(calculated,z[col].to_numpy(),rtol=0,atol=1e-12))
checks={k:bool(v) for k,v in checks.items()}
(OUT/'validation').mkdir(exist_ok=True)
(OUT/'validation'/'EXPORT_CHECKS.json').write_text(json.dumps(checks,indent=2)+'\n')
if not all(checks.values()):
    raise AssertionError({k:v for k,v in checks.items() if not v})
print(json.dumps({'tables':11,'figures':5,'checks_passed':sum(checks.values()),'checks_total':len(checks)},indent=2))
