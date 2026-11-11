# Reproduction instructions

Run commands from the repository root. Use a writable local directory and keep the supplied source files intact. No model packages beyond base R are required. Python dependencies are pinned in `requirements.txt`.

1. `Rscript run.R check outputs/check` validates the packaged inputs and exercises the R self-tests without the complete experiment.
2. `Rscript run.R full outputs/full` runs all 120 specified cases. The standalone driver recreates its support files beside itself; those generated directories are ignored by Git. A successful result has a `RUN_STATUS.txt` whose first line is `COMPLETE` and whose subsequent lines describe the run. Preserve the whole file.
3. `python code/verify_full_run.py outputs/full` compares the new accuracy, inference, coefficients and monthly fit timing with the archived study. It also checks the core checksum, case counts, 14 functional checks and 2,400 parent parity checks.
4. `Rscript code/verify_arrays.R outputs/full outputs/array-audit` independently calculates targets from the price snapshots, isotonic projection using base R, coefficient combinations, four losses, and numerical shape rates from the fitted arrays. It checks 918,800 origin–horizon targets and 11,025,600 forecast values. It does not source the model implementation.
5. `python build_outputs.py --results-dir outputs/full` regenerates the 13 complete publication tables and five figures. `--output-dir PATH` changes the destination. The numerical core and the publication exporter are separate: an export does not fit a model.

For RStudio, open the project folder and use its Terminal for these commands. Alternatively, the standalone driver in `code/` can be sourced as a saved file. Pasting a trailing `main()` invocation alone does not supply the source file needed for provenance.

The driver records session information, source hashes and input manifests. Its source capture is intentional. Do not bypass input or provenance checks to make a changed dataset look like this study.

The coefficient summary is stored in 31 ordered CSV parts. Each includes the same header. Reassembling the first header followed by every part's data rows exactly restores the original file, verified against `evidence/CHOICES_PARTITIONS.json`. Python scripts read the parts automatically.

`tests/check_publication.py` tests frozen export and the multiline completion-record interface; its synthetic directory fixture is an export regression test, not a model fit. The separately recorded full R run establishes fitting reproducibility.

The full current-study rerun uses no cached expert bank. It repeats historical ridge selection and coefficient estimation, then resamples the resulting paired loss sequences. It does not re-estimate models inside bootstrap draws. The current dataset is unchanged, so this is not new external validation.

Additional benchmark rows in A3 and historical TV rows in A4–A6 are rebuilt from their archived aggregates. They are not estimators rerun by `run.R`. The full-path positive control, daily combinations, and MCPB sensitivities are part of the freshly fitted current study.
