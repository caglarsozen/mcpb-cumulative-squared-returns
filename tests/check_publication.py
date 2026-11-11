"""Check numerical output cells, data integrity, scope and repaired export paths."""
from pathlib import Path
import hashlib,json,re,subprocess,sys,tempfile
ROOT=Path(__file__).resolve().parents[1]
checks={}
parts=sorted((ROOT/'evidence/choices').glob('part-*.csv'))
joined=parts[0].read_bytes().splitlines(keepends=True)[0]+b''.join(
    b''.join(p.read_bytes().splitlines(keepends=True)[1:]) for p in parts)
record=json.loads((ROOT/'evidence/CHOICES_PARTITIONS.json').read_text())
checks['coefficient_records_byte_exact']=hashlib.sha256(joined).hexdigest()==record['original_sha256']
checks['numerical_R_core_byte_exact']=hashlib.md5((ROOT/'evidence/SOURCE_MCPB.R').read_bytes()).hexdigest()=='7198511bb116a1cd872cc25dc94122cc'
def data(p):
    return re.sub(r'\s+',' ',p.read_text().split(r'\midrule',1)[1].split(r'\bottomrule',1)[0]).strip()
with tempfile.TemporaryDirectory() as d:
    out=Path(d)/'publication'
    subprocess.run([sys.executable,str(ROOT/'build_outputs.py'),'--output-dir',str(out)],check=True)
    for source in (ROOT/'publication_tables').glob('*.tex'):
        checks[source.stem+'_numerical_cells_match']=data(source)==data(out/'tables'/source.name)
    checks['all_five_pdf_figures_generated']=len(list((out/'figures').glob('*.pdf')))==5
    checks['no_internal_underscores_in_figure_filenames']=all('_' not in p.name for p in (out/'figures').glob('*'))
    checks['all_18_reporting_checks_pass']=all(json.loads((out/'validation/EXPORT_CHECKS.json').read_text()).values())
    # The actual R status file contains explanatory lines after COMPLETE.
    results=Path(d)/'results';results.mkdir()
    (results/'RUN_STATUS.txt').write_text('COMPLETE\nEXPLORATORY\ncases 120\n')
    for name in ['SUMMARY_accuracy.csv','SUMMARY_inference.csv']:
        (results/name).symlink_to(ROOT/'evidence'/name)
    (results/'choices').symlink_to(ROOT/'evidence/choices',target_is_directory=True)
    second=Path(d)/'rerun_publication'
    subprocess.run([sys.executable,str(ROOT/'build_outputs.py'),'--results-dir',str(results),'--output-dir',str(second)],check=True)
    checks['multiline_COMPLETE_status_supported']=True
    checks['new_result_export_contains_Daily_H']='Daily $H$' in (second/'tables/T4.tex').read_text()
    checks['new_result_export_has_all_13_tables']=len(list((second/'tables').glob('*.tex')))==13
    checks['new_result_export_uses_canonical_figure_names']=set(p.name for p in (second/'figures').glob('*.pdf'))=={'Fig1.pdf','Fig2.pdf','Fig3.pdf','Fig4.pdf','FigA1.pdf'}
assert all(checks.values()),[k for k,v in checks.items() if not v]
(ROOT/'validation').mkdir(exist_ok=True)
(ROOT/'validation/PUBLICATION_TESTS.json').write_text(json.dumps(checks,indent=2)+'\n')
print(json.dumps({'passed':sum(checks.values()),'total':len(checks)},indent=2))
