"""Generate all 13 publication tables and five figures from numerical records.

The numerical model is not refitted by this command. Run run.R for estimation.
"""
from pathlib import Path
import runpy, re, json
import numpy as np

ROOT = Path(__file__).resolve().parent
g = runpy.run_path(str(ROOT / 'build_outputs_numerical.py'), run_name='__main__')
T, F, OUT = g['T'], g['F'], g['OUT']
A, E = g['A'], g['E']

mapping = {'T1':'T1_sample.tex','T2':'T2_controls.tex','T3':'T3_asset_accuracy.tex',
           'T4':'T4_comparison_summary.tex','T5':'T5_robustness.tex',
           'A1':'B1_primary_intervals.tex','A2':'B2_regularization.tex',
           'A3':'B3_archival_benchmarks.tex','A4':'D1_legacy_ablation.tex',
           'A5':'D2_legacy_shape.tex','A7':'B4_short_horizons.tex'}

def body(text):
    return text.split(r'\midrule',1)[1].split(r'\bottomrule',1)[0]

def rows(text):
    return [[c.strip() for c in line.strip().removesuffix(r'\\').split('&')]
            for line in text.splitlines() if '&' in line]

def numeric(cell):
    return bool(re.match(r'^[+\-\d\[]',cell) or r'\times10' in cell)

for key in [*(f'T{i}' for i in range(1,6)),*(f'A{i}' for i in range(1,9))]:
    template = (ROOT/'publication_tables'/f'{key}.tex').read_text()
    expected_rows = rows(body(template))
    if key == 'T2':
        actual_rows = expected_rows  # Fixed design, not an estimated result.
    elif key == 'A6':
        variants = g['pd'].read_csv(E/'TV_VARIANT_MAP.csv')
        actual_rows = []
        for _,v in variants.iterrows():
            values=100*(1-g['lp'][v['method']]/g['lp']['Ridge'])
            actual_rows.append([v['variant'],f'{(values>0).sum()}/15',f'{np.median(values):+.2f}'])
    elif key == 'A8':
        x=A[A.H.eq(30)&A.protocol.eq('expanding')]
        actual_rows=[]
        for asset,short in zip(g['ASSETS'],g['SHORT']):
            z=x[x.asset.eq(asset)].set_index('method')
            actual_rows.append([short,str(int(z.loc['MCPB','n'])),
                f"{100*z.loc['Ridge','path_violation_rate']:.2f}",
                f"{100*z.loc['MCPB','path_violation_rate']:.2f}",
                f"{100*(1-z.loc['Ridge_PAV','PathMSE']/z.loc['Ridge','PathMSE']):+.2f}"])
    else:
        actual_rows=rows(body((T/mapping[key]).read_text()))
    assert len(actual_rows)==len(expected_rows),(key,len(actual_rows),len(expected_rows))
    combined=[]
    for old,new in zip(expected_rows,actual_rows):
        assert len(old)==len(new),(key,old,new)
        # Keep readable category labels and update every numerical cell.
        cells=[b if numeric(b) else a for a,b in zip(old,new)]
        combined.append(' & '.join(cells)+r' \\')
    data='\n'+'\n'.join(combined)+'\n'
    (T/f'{key}.tex').write_text(template.replace(body(template),data,1))

for path in mapping.values():
    (T/path).unlink()
figure_names={'F1_primary_intervals':'Fig1','F2_all_cases':'Fig2',
              'F4_qlike':'Fig3','F3_level_composition':'Fig4','FB1_close_controls':'FigA1'}
for old,new in figure_names.items():
    for extension in ['.pdf','.png']:
        (F/(old+extension)).replace(F/(new+extension))
report={'publication_tables':13,'figures':5,'input_directory':str(g['NUM']),
        'output_directory':str(OUT),'model_refitted':False,
        'historical_context':'A3 additional benchmarks and A4-A6 TV comparisons retain their separate archived records.',
        'article_modified':False}
(OUT/'validation/PUBLICATION_EXPORT.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
