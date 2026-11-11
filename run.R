# Run the unchanged offline numerical driver from a saved script.
# Rscript run.R check outputs/check
# Rscript run.R full outputs/full
args <- commandArgs(trailingOnly=TRUE)
file_arg <- grep('^--file=',commandArgs(),value=TRUE)
if (!length(file_arg)) stop('Save this file and execute it with Rscript.')
root <- dirname(normalizePath(sub('^--file=','',file_arg[1]),mustWork=TRUE))
mode <- if(length(args)) args[1] else 'check'
if (!(mode %in% c('check','full'))) stop('Mode must be check or full.')
out <- if(length(args)>1) args[2] else file.path(root,'outputs',mode)
Sys.setenv(JOEF_MCPB_MODE=mode,JOEF_MCPB_OUTDIR=out,JOEF_MCPB_NO_AUTO='false')
source(file.path(root,'code','JOEF_MCPB_2024_REPLICATION.R'),encoding='UTF-8')
