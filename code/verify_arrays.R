# Independently recompute targets, losses and shape diagnostics from a full R run.
# Does not source the forecasting implementation or repeat model fitting.
# Rscript code/verify_arrays.R outputs/full outputs/array-audit
args <- commandArgs(trailingOnly=TRUE)
stopifnot(length(args)>=1L)
script <- sub('^--file=','',grep('^--file=',commandArgs(),value=TRUE)[1])
root <- dirname(dirname(normalizePath(script,mustWork=TRUE)))
run <- normalizePath(args[1],mustWork=TRUE)
out <- if(length(args)>1L) args[2] else file.path(run,'array-audit')
dir.create(out,recursive=TRUE,showWarnings=FALSE)
stopifnot(readLines(file.path(run,'RUN_STATUS.txt'),n=1)=='COMPLETE')
files <- list.files(file.path(run,'cases'),pattern='^forecast_arrays.rds$',recursive=TRUE,full.names=TRUE)
stopifnot(length(files)==120L)
allacc <- read.csv(file.path(run,'SUMMARY_accuracy.csv'))
rows <- list(); shapes <- list(); cells <- 0; targets <- 0
near <- function(a,b,rtol=1e-9,atol=1e-13) {
  stopifnot(identical(dim(a),dim(b)),length(a)==length(b),all(is.finite(a)),all(is.finite(b)))
  stopifnot(all(abs(a-b)<=atol+rtol*abs(b)))
  max(abs(a-b))
}
for(f in files) {
  x <- readRDS(f); n <- length(x$origin); H <- x$H
  p <- read.csv(file.path(root,'evidence','prices',paste0('RAW_',gsub('-','_',x$asset),'.csv')))
  p <- p[p$Date>='2019-01-01' & p$Date<='2024-12-31',]; p <- p[order(p$Date),]
  col <- intersect(c('Adjusted','Adj.Close','Close'),names(p))[1]
  q <- diff(log(p[[col]]))^2
  Y <- t(vapply(x$origin,function(t) cumsum(q[t+seq_len(H)]),numeric(H)))
  dy <- near(Y,x$Y)
  targets <- targets+length(Y);cells <- cells+length(Y)*length(x$pred)
  floor <- 1e-6*mean(q[seq_len(min(x$origin))])
  L <- read.csv(file.path(dirname(f),'origin_losses.csv'))
  acc <- allacc[allacc$asset==x$asset & allacc$protocol==x$protocol & allacc$H==H,]
  # Base-R isotonic regression is independent of the custom PAV implementation.
  projected <- t(apply(x$pred$Ridge,1,function(z) pmax(0,isoreg(seq_len(H),z)$yf)))
  dp <- near(projected,x$pred$Ridge_PAV)
  for(m in names(x$pred)) {
    P <- x$pred[[m]]; e <- (P-Y)^2
    loss <- cbind(PathMSE=rowMeans(e),H1_MSE=e[,1],H1_5_MSE=rowMeans(e[,seq_len(min(5,H)),drop=FALSE]),
                  PathQLIKE=rowMeans(log(pmax(P,floor))+Y/pmax(P,floor)))
    z <- L[L$method==m,];z <- z[match(x$origin,z$origin),]
    dl <- near(loss,as.matrix(z[,colnames(loss)]))
    a <- acc[acc$method==m,];stopifnot(nrow(a)==1L,a$n==n)
    da <- near(as.numeric(colMeans(loss)),as.numeric(a[1,colnames(loss)]))
    inc <- cbind(P[,1],P[,-1,drop=FALSE]-P[,-H,drop=FALSE])
    rate <- mean(rowSums(inc< -1e-12)>0)
    near(rate,a$path_violation_rate,rtol=0,atol=1e-14)
    dc <- 0
    if(paste0('betaR_',m)%in%names(x$choices)) {
      combined <- x$pred$Ridge_PAV*x$choices[[paste0('betaR_',m)]]+x$pred$EWMA*x$choices[[paste0('betaE_',m)]]
      dc <- near(combined,P)
    }
    rows[[length(rows)+1L]] <- data.frame(asset=x$asset,protocol=x$protocol,H=H,method=m,n=n,
      target_max_error=dy,projection_max_error=dp,combination_max_error=dc,origin_loss_max_error=dl,
      summary_loss_max_error=da,violation_rate=rate)
    if(H==30L && x$protocol=='expanding' && m%in%c('Ridge','Ridge_PAV','MCPB')) {
      shapes[[length(shapes)+1L]] <- data.frame(asset=x$asset,method=m,n=n,violation_rate=rate,
        zero_increment_rate=mean(abs(inc)<=1e-12),minimum_increment=min(inc),
        maximum_projection_change=max(abs(x$pred$Ridge_PAV-x$pred$Ridge)))
    }
  }
}
stopifnot(targets==918800,cells==11025600,length(rows)==1440L)
write.csv(do.call(rbind,rows),file.path(out,'ARRAY_AUDIT.csv'),row.names=FALSE)
write.csv(do.call(rbind,shapes),file.path(out,'PRINCIPAL_SHAPE.csv'),row.names=FALSE)
writeLines(c('PASS',paste('Cases:',length(files)),paste('Method-case comparisons:',length(rows)),
  paste('Origin-horizon targets:',targets),paste('Forecast values:',cells),
  'Independent recomputation of targets, projection, coefficient combinations, four losses, and shape diagnostics.',
  'This audit reads fresh fitted arrays; it is not an additional model fit or an unseen-data evaluation.'),file.path(out,'STATUS.txt'))
cat(paste('PASS:',length(files),'cases;',cells,'forecast values\n'))
