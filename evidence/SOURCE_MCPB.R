# JOEF MCPB v0.2 RESEARCH. Same frozen kernel reconstructed after workspace maintenance.
# JOEF guarded simple-combination research study v0.1 | 25 October 2026
# EXPLORATORY: uses previously inspected 2019-2024 data; not a confirmed improvement.
# Base-R only. The imported numerical/data functions are copied verbatim from
# the submitted v1.3.1 runtime source; no RF/GARCH fitting is used in this study.
# Primary candidate and inference scope are fixed in DECLARED_GUARD_STUDY.md.
j_bool <- function(x) tolower(x) %in% c("1", "true", "yes")

j_int <- function(key, default) {
    z <- suppressWarnings(as.integer(Sys.getenv(key, as.character(default))))
    if (!is.finite(z) || z < 1L) 
        stop("Invalid positive integer: ", key)
    z
}

j_int <- function(key, default) {
    z <- suppressWarnings(as.integer(Sys.getenv(key, as.character(default))))
    if (!is.finite(z) || z < 1L) 
        stop("Invalid positive integer: ", key)
    z
}

j_slug <- function(x) gsub("[^A-Za-z0-9]+", "_", x)

j_assert <- function(ok, msg) {
    if (!isTRUE(all(ok))) 
        stop(msg, call. = FALSE)
    invisible(TRUE)
}

j_assert <- function(ok, msg) {
    if (!isTRUE(all(ok))) 
        stop(msg, call. = FALSE)
    invisible(TRUE)
}

j_log <- function(...) {
    cat(format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "|", ..., "\n")
    flush.console()
}

j_bind <- function(x) {
    x <- Filter(function(z) !is.null(z) && nrow(z) > 0L, x)
    if (!length(x)) 
        return(data.frame())
    cols <- unique(unlist(lapply(x, names)))
    x <- lapply(x, function(z) {
        for (nm in setdiff(cols, names(z))) z[[nm]] <- NA
        z[, cols, drop = FALSE]
    })
    rownames_out <- do.call(rbind, x)
    rownames(rownames_out) <- NULL
    rownames_out
}

j_hash <- function(obj) {
    f <- tempfile(fileext = ".rds")
    on.exit(unlink(f), add = TRUE)
    saveRDS(obj, f, version = 2)
    unname(tools::md5sum(f))
}

j_write <- function(x, path) {
    dir.create(dirname(path), showWarnings = FALSE, recursive = TRUE)
    utils::write.csv(x, path, row.names = FALSE, na = "")
}

j_asset_universe <- function() {
    data.frame(asset = c("BTC-USD", "ETH-USD", "SPY", "GLD", "TLT", "QQQ", "IWM", "EFA", "EEM", "XLF", "XLE", "XLU", "SLV", "LQD", "VNQ"), group = c("crypto", "crypto", "US_equity", "gold", "Treasury_bonds", "US_growth_equity", "US_small_cap", "developed_ex_US", "emerging_equity", "financials", "energy", "utilities", "silver", "corporate_bonds", "real_estate"), cohort = c(rep("original_five_retained", 5L), rep("extension_ten", 10L)), inclusion_rule = "coverage_by_asset_class_not_test_performance", 
        stringsAsFactors = FALSE)
}

j_synthetic_prices <- function(symbol, n, seed) {
    set.seed(seed)
    h <- rep(0.00015, n)
    r <- numeric(n)
    for (t in 2:n) {
        regime <- if (t > n * 0.45 && t < n * 0.65) 
            2.5
        else 1
        h[t] <- 8e-06 * regime + 0.08 * r[t - 1]^2 + 0.88 * h[t - 1]
        r[t] <- sqrt(h[t]) * stats::rt(1, 8) * sqrt(6/8)
    }
    dates <- seq(as.Date("2019-01-01"), by = "day", length.out = n)
    data.frame(Date = dates, Adjusted = 100 * exp(cumsum(r)), Symbol = symbol)
}

j_fetch_yahoo <- function(symbol, cfg, path) {
    p1 <- as.numeric(as.POSIXct(cfg$start, tz = "UTC"))
    p2 <- as.numeric(as.POSIXct(cfg$end + 1, tz = "UTC"))
    base <- paste0("https://query1.finance.yahoo.com/v8/finance/chart/", utils::URLencode(symbol, reserved = TRUE), "?period1=", format(p1, scientific = FALSE), "&period2=", format(p2, scientific = FALSE), "&interval=1d&events=history&includeAdjustedClose=true")
    raw_path <- sub("\\.csv$", ".json", path)
    ok <- FALSE
    last <- ""
    for (attempt in 1:3) {
        z <- tryCatch({
            utils::download.file(base, raw_path, method = "libcurl", quiet = TRUE, mode = "wb")
            jsonlite::fromJSON(raw_path, simplifyVector = FALSE)
        }, error = function(e) {
            last <<- conditionMessage(e)
            NULL
        })
        if (!is.null(z$chart$result) && length(z$chart$result)) {
            ok <- TRUE
            break
        }
        Sys.sleep(attempt)
    }
    if (!ok) 
        stop("Yahoo download failed for ", symbol, ". Supply the original Date/Adjusted CSV instead. ", last)
    z <- z$chart$result[[1L]]
    ts <- as.numeric(unlist(z$timestamp))
    cl <- as.numeric(unlist(z$indicators$quote[[1L]]$close))
    ad <- as.numeric(unlist(z$indicators$adjclose[[1L]]$adjclose))
    crypto <- grepl("-USD$", symbol)
    if (length(ad) != length(ts) && !crypto) 
        stop("Adjusted-close series missing for ", symbol, ".")
    if (length(ad) != length(ts)) 
        ad <- cl
    ans <- data.frame(Date = as.Date(as.POSIXct(ts, origin = "1970-01-01", tz = "UTC")), Adjusted = ad)
    j_write(ans, path)
    writeLines(c(paste("symbol", symbol), paste("url", base), paste("downloaded_utc", format(Sys.time(), tz = "UTC", usetz = TRUE)), paste("exchange_timezone", z$meta$exchangeTimezoneName)), sub("\\.csv$", "_source.txt", path))
    ans
}

j_read_prices <- function(symbol, cfg) {
    dir.create(cfg$data_dir, recursive = TRUE, showWarnings = FALSE)
    if (cfg$data_source == "synthetic") {
        z <- j_synthetic_prices(symbol, cfg$synthetic_n, cfg$seed + sum(utf8ToInt(symbol)))
        path <- file.path(cfg$out_dir, "synthetic_inputs", paste0("RAW_", j_slug(symbol), ".csv"))
        j_write(z, path)
    }
    else {
        path <- file.path(cfg$data_dir, paste0("RAW_", j_slug(symbol), ".csv"))
        if (cfg$data_source == "yahoo" && (!file.exists(path) || cfg$refresh_data)) 
            j_fetch_yahoo(symbol, cfg, path)
        if (!file.exists(path)) 
            stop("Missing local input: ", path)
        z <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
    }
    nn <- tolower(gsub("[^a-z]", "", tolower(names(z))))
    date_col <- which(nn == "date")[1L]
    price_col <- which(nn %in% c("adjusted", "adjclose", "adjustedclose"))[1L]
    if (is.na(price_col) && grepl("-USD$", symbol)) 
        price_col <- which(nn == "close")[1L]
    j_assert(!is.na(date_col) && !is.na(price_col), "Input needs Date and Adjusted.")
    ans <- data.frame(date = as.Date(z[[date_col]]), price = as.numeric(z[[price_col]]))
    j_assert(!anyNA(ans$date), "Invalid dates in input.")
    ans <- ans[ans$date >= cfg$start & ans$date <= cfg$end, , drop = FALSE]
    ans <- ans[order(ans$date), , drop = FALSE]
    j_assert(!anyDuplicated(ans$date), "Duplicate price dates.")
    j_assert(all(is.finite(ans$price) & ans$price > 0), paste("Missing/nonpositive price in", symbol, "; no filling allowed."))
    j_assert(nrow(ans) > cfg$min_train + cfg$min_cal + 2 * max(cfg$horizons), paste("Too few observations for", symbol))
    if (grepl("-USD$", symbol)) 
        j_assert(all(diff(ans$date) == 1), "Missing calendar day in crypto prices.")
    ans$symbol <- symbol
    attr(ans, "source_file") <- normalizePath(path, winslash = "/", mustWork = TRUE)
    attr(ans, "source_md5") <- unname(tools::md5sum(path))
    ans
}

j_rollmean <- function(x, k) {
    cs <- c(0, cumsum(x))
    out <- rep(NA_real_, length(x))
    if (length(x) >= k) 
        out[k:length(x)] <- (cs[(k:length(x)) + 1L] - cs[(k:length(x)) - k + 1L])/k
    out
}

j_build <- function(prices, Hmax, har = c(5L, 22L)) {
    r <- diff(log(prices$price))
    dates <- prices$date[-1L]
    rv <- r * r
    first <- max(30L, har)
    origins <- seq.int(first, length(r) - Hmax)
    X <- cbind(rv = rv, weekly = j_rollmean(rv, har[1L]), monthly = j_rollmean(rv, har[2L]))
    cs <- c(0, cumsum(rv))
    idx <- outer(origins, seq_len(Hmax), "+")
    Y <- matrix(cs[as.vector(idx) + 1L], nrow = length(origins)) - cs[origins + 1L]
    j_assert(all(is.finite(X[origins, , drop = FALSE])), "Nonfinite HAR features.")
    j_assert(all(Y >= -1e-12), "Negative cumulative target.")
    list(symbol = prices$symbol[1L], r = r, rv = rv, date = dates, origins = origins, X = X, Y = Y, Hmax = Hmax, har = har, source_md5 = attr(prices, "source_md5"), source_file = attr(prices, "source_file"))
}

j_hac <- function(x, lag) {
    x <- as.numeric(x)
    j_assert(all(is.finite(x)), "Nonfinite loss in HAC.")
    n <- length(x)
    lag <- min(as.integer(lag), n - 2L)
    if (n < 4L) 
        return(list(se = NA_real_, lag = lag, lrv = NA_real_))
    z <- x - mean(x)
    v <- sum(z * z)/n
    if (lag > 0L) 
        for (k in seq_len(lag)) v <- v + 2 * (1 - k/(lag + 1)) * sum(z[(k + 1):n] * z[1:(n - k)])/n
    list(se = sqrt(max(v, 0)/n), lag = lag, lrv = max(v, 0))
}

j_increments <- function(Y) {
    Y <- as.matrix(Y)
    cbind(Y[, 1L], if (ncol(Y) > 1L) 
        Y[, -1L, drop = FALSE] - Y[, -ncol(Y), drop = FALSE]
    else NULL)
}

j_cumulate <- function(X) {
    X <- as.matrix(X)
    if (ncol(X) > 1L) 
        for (h in 2:ncol(X)) X[, h] <- X[, h] + X[, h - 1L]
    X
}

j_linear <- function(X, Y, lambda = 0) {
    X <- as.matrix(X)
    Y <- as.matrix(Y)
    xm <- colMeans(X)
    xs <- apply(X, 2L, stats::sd)
    xs[!is.finite(xs) | xs < 1e-14] <- 1
    Z <- sweep(sweep(X, 2L, xm, "-"), 2L, xs, "/")
    ym <- colMeans(Y)
    yc <- sweep(Y, 2L, ym, "-")
    z <- svd(Z, nu = ncol(Z), nv = ncol(Z))
    tol <- max(z$d) * 1e-10
    mult <- ifelse(z$d > tol, z$d/(z$d^2 + nrow(X) * lambda), 0)
    B <- z$v %*% (mult * crossprod(z$u, yc))
    list(xm = xm, xs = xs, ym = ym, B = B, lambda = lambda, rank = sum(z$d > tol))
}

j_predict_linear <- function(fit, X) {
    Z <- sweep(sweep(as.matrix(X), 2L, fit$xm, "-"), 2L, fit$xs, "/")
    sweep(Z %*% fit$B, 2L, fit$ym, "+")
}

j_pav <- function(Y) {
    Y <- as.matrix(Y)
    ans <- t(vapply(seq_len(nrow(Y)), function(i) pmax(as.numeric(stats::isoreg(seq_len(ncol(Y)), Y[i, ])$yf), 0), numeric(ncol(Y))))
    dimnames(ans) <- dimnames(Y)
    ans
}

p_layout <- function(d, cfg) {
    o <- d$origins
    n <- length(o)
    k1 <- floor(cfg$fractions[1L] * n)
    k2 <- floor(sum(cfg$fractions[1:2]) * n)
    j_assert(k1 > 0 && k2 < n, "Invalid chronological fractions.")
    ca0 <- o[o >= o[k1 + 1L] & o + cfg$Hmax <= o[k2 + 1L]]
    te <- o[(k2 + 1L):n]
    if (cfg$mode == "pilot") 
        te <- head(te, cfg$pilot_test_n)
    native <- o[o >= o[k1 + 1L] & o <= max(te)]
    list(first_cal = o[k1 + 1L], first_test = o[k2 + 1L], test = te, cal_count = length(ca0), native = native, groups = unname(split(native, format(d$date[native], "%Y-%m"))))
}

p_training <- function(d, cut, protocol, cfg) {
    tr <- d$origins[d$origins + cfg$Hmax <= cut]
    if (protocol == "rolling") 
        tr <- tr[d$date[tr] >= d$date[cut] - round(365.25 * cfg$train_years)]
    j_assert(length(tr) >= cfg$min_train, "Too few mature training labels.")
    j_assert(max(tr + cfg$Hmax) <= cut, "Unmatured training label.")
    list(train = tr, cut = cut, raw_start = min(tr), a = mean(d$rv[seq.int(min(tr), cut)]))
}

p_choose_ridge <- function(d, tr, cfg, a, metric = "PathMSE") {
    val <- tail(tr, max(40L, floor(0.2 * length(tr))))
    inn <- tr[tr + cfg$Hmax <= min(val)]
    j_assert(length(inn) >= 60L && max(inn + cfg$Hmax) <= min(val), "Invalid purged ridge split.")
    Y <- d$Y[match(inn, d$origins), , drop = FALSE]/a
    V <- d$Y[match(val, d$origins), , drop = FALSE]/a
    h <- seq_len(min(cfg$main_h, ncol(Y)))
    loss <- vapply(cfg$ridge_grid, function(lam) {
        fit <- j_linear(d$X[inn, , drop = FALSE], Y, lam)
        er <- j_predict_linear(fit, d$X[val, , drop = FALSE])[, h, drop = FALSE] - V[, h, drop = FALSE]
        if (metric == "PerDayMSE") 
            er <- sweep(er, 2, h, "/")
        mean(er^2)
    }, numeric(1))
    best <- which.min(loss)
    list(lambda = cfg$ridge_grid[best], surface = data.frame(lambda = cfg$ridge_grid, inner_loss = loss, metric = metric, selected = seq_along(loss) == best), inner_train_last_target = max(inn + cfg$Hmax), inner_validation_first = min(val))
}

p_ewma <- function(rv, lambda = 0.94) {
    state <- numeric(length(rv))
    v <- mean(head(rv, 30L))
    for (t in seq_along(rv)) {
        v <- lambda * v + (1 - lambda) * rv[t]
        state[t] <- v
    }
    state
}

p_boot_weights <- function(n, L, B, seed) {
    j_assert(n >= L && L >= 1 && B >= 19, "Invalid bootstrap design.")
    set.seed(seed)
    W <- matrix(0, B, n)
    nb <- ceiling(n/L)
    for (b in seq_len(B)) {
        st <- sample.int(n - L + 1L, nb, replace = TRUE)
        ix <- head(rep(st, each = L) + rep(0:(L - 1L), nb), n)
        W[b, ] <- tabulate(ix, nbins = n)/n
    }
    W
}

p_loss <- function(case, d, cfg) {
    Y <- case$Y
    H <- case$H
    n <- nrow(Y)
    a <- mean(d$rv[seq_len(min(case$origin))])
    floor0 <- cfg$qlike_floor_fraction * a
    mats <- lapply(c("PathMSE", "H1_MSE", "H1_5_MSE", "PathQLIKE"), function(x) matrix(NA_real_, n, length(case$pred), dimnames = list(NULL, names(case$pred))))
    names(mats) <- c("PathMSE", "H1_MSE", "H1_5_MSE", "PathQLIKE")
    for (m in names(case$pred)) {
        P <- case$pred[[m]]
        e <- (P - Y)^2
        Q <- pmax(P, floor0)
        mats$PathMSE[, m] <- rowMeans(e)
        mats$H1_MSE[, m] <- e[, 1L]
        mats$H1_5_MSE[, m] <- rowMeans(e[, seq_len(min(5L, H)), drop = FALSE])
        mats$PathQLIKE[, m] <- rowMeans(log(Q) + Y/Q)
    }
    mats
}


gr_alpha <- function(R,E,Y) {
  delta<-E-R;den<-sum(delta^2)
  if(den<=1e-30) return(0)
  min(1,max(0,sum((Y-R)*delta)/den))
}

gr_native_block <- function(d,ev,protocol,cfg) {
  cut<-min(ev);trn<-p_training(d,cut,protocol,cfg)
  Y<-d$Y[match(trn$train,d$origins),,drop=FALSE]/trn$a
  choice<-p_choose_ridge(d,trn$train,cfg,trn$a,"PathMSE")
  fit<-j_linear(d$X[trn$train,,drop=FALSE],Y,choice$lambda)
  R<-j_predict_linear(fit,d$X[ev,,drop=FALSE])*trn$a
  E<-outer(p_ewma(d$rv,cfg$ewma_lambda)[ev],seq_len(cfg$Hmax),"*")
  list(origin=ev,R=R,E=E,cut=rep(cut,length(ev)),a=rep(trn$a,length(ev)),
    timing=data.frame(native_cut=cut,last_training_target=max(trn$train+cfg$Hmax),n_train=length(trn$train),ridge_lambda=choice$lambda))
}

gr_bank <- function(d,layout,protocol,cfg) {
  parts<-lapply(layout$groups,function(ev) gr_native_block(d,ev,protocol,cfg))
  list(origin=unlist(lapply(parts,`[[`,"origin")),R=do.call(rbind,lapply(parts,`[[`,"R")),
    E=do.call(rbind,lapply(parts,`[[`,"E")),cut=unlist(lapply(parts,`[[`,"cut")),
    a=unlist(lapply(parts,`[[`,"a")),timing=j_bind(lapply(parts,`[[`,"timing")))
}

gr_accuracy <- function(case,d,cfg) {
  losses<-p_loss(case,d,cfg);ans<-list()
  for(m in names(case$pred)) {
    q<-losses$PathMSE[,m]
    ans[[m]]<-data.frame(asset=case$asset,protocol=case$protocol,H=case$H,method=m,n=nrow(case$Y),
      PathMSE=mean(q),PathRMSE=sqrt(mean(q)),H1_MSE=mean(losses$H1_MSE[,m]),H1_5_MSE=mean(losses$H1_5_MSE[,m]),
      PathQLIKE=mean(losses$PathQLIKE[,m]),PRE_vs_EWMA=100*(1-mean(q)/mean(losses$PathMSE[,"EWMA"])),
      PRE_vs_RidgeEWMA=100*(1-mean(q)/mean(losses$PathMSE[,"RidgeEWMA"])),
      path_violation_rate=mean(rowSums(j_increments(case$pred[[m]])< -1e-12)>0))
  }
  j_bind(ans)
}


mc_config <- function() {
  cmd<-commandArgs();paths<-grep('^--file=',cmd,value=TRUE)
  if(!length(paths)) {at<-which(cmd %in% c('-f','--file'));if(length(at)) paths<-paste0('--file=',cmd[at[1]+1L])}
  ff<-vapply(sys.frames(),function(f) if(is.character(f$ofile)&&length(f$ofile)==1L) f$ofile else NA_character_,character(1));ff<-ff[!is.na(ff)]
  script<-if(length(ff)) tail(ff,1L) else if(length(paths)) sub('^--file=','',paths[1L]) else NA_character_
  root<-if(!is.na(script)) dirname(normalizePath(script,winslash='/',mustWork=TRUE)) else getwd()
  cfg<-readRDS(file.path(root,'reference','reference_CONFIGURATION.rds'))
  cfg$parent_version<-cfg$version;cfg$version<-'MCPB-0.2-RESEARCH';cfg$mode<-'full';cfg$horizons<-c(10L,20L,30L,40L);cfg$data_source<-'csv'
  cfg$data_dir<-file.path(root,'data_snapshot');cfg$out_dir<-Sys.getenv('JOEF_MCPB_OUTDIR',file.path(root,'results'));cfg$cache_dir<-Sys.getenv('JOEF_MCPB_NATIVE_CACHE','')
  cfg$kappa<-1e-4;cfg$bootstrap_reps<-4999L;cfg$bootstrap_multipliers<-1:3;cfg$seed<-20261025L
  cfg$reference_accuracy<-file.path(root,'reference','reference_v131_accuracy.csv');cfg$reference_manifest<-file.path(root,'reference','reference_v131_DATA_MANIFEST.csv')
  capture<-mc_source_capture(script)
  cfg$reference_provenance<-list(version=cfg$parent_version,code_md5=cfg$code_md5,runtime=cfg$runtime,fingerprint=cfg$fingerprint)
  cfg$code_md5<-capture$md5;cfg$source_capture<-capture$mode;cfg$source_file<-capture$file
  cfg$runtime<-list(R_version=R.version.string,platform=R.version$platform,system=Sys.info(),BLAS=extSoftVersion()[['BLAS']],matprod=getOption('matprod'))
  cfg$fingerprint<-NULL
  cfg$script<-capture$file;cfg$root<-root;cfg$metadata_patch<-'0.2.1-source-and-environment'
  cfg$plan_md5<-unname(tools::md5sum(file.path(root,'DECLARED_MCPB_STUDY.md')))
  cfg$evidence_status<-'EXPLORATORY_POST_V131_ON_PREVIOUSLY_SEEN_2019_2024_DATA'
  j_assert(length(cfg$symbols)==15L && cfg$Hmax==40L && cfg$meta_window==252L,'Unexpected reference configuration.');cfg
}
mc_prefix <- function(R,E,Y) {
  delta<-E-R;z<-list(q11=R*R,q12=R*E,q22=E*E,b1=R*Y,b2=E*Y,dd=delta^2,db=delta*(Y-R))
  lapply(z,function(a) rbind(rep(0,ncol(a)),apply(a,2,cumsum)))
}
mc_stats <- function(prefix,origins,cut,H,window,mode='partial') {
  lag<-switch(mode,partial=seq_len(H),fullH=rep(H,H),full40=rep(40L,H),stop('Unknown maturity mode.'))
  end<-findInterval(cut-lag,origins);start<-pmax(1L,end-window+1L);n<-end-start+1L;j_assert(all(n>=100L),'Insufficient mature calibration cells.')
  idx1<-cbind(end+1L,seq_len(H));idx0<-cbind(start,seq_len(H));v<-vapply(prefix,function(a) mean((a[idx1]-a[idx0])/n),numeric(1))
  Q<-matrix(c(v['q11'],v['q12'],v['q12'],v['q22']),2,2)
  list(Q=Q,b=unname(v[c('b1','b2')]),dd=unname(v['dd']),db=unname(v['db']),n_min=min(n),n_max=max(n),newest_origin=max(origins[end]),max_target=max(origins[end]+seq_len(H)),end=end,start=start)
}
mc_simplex <- function(s) {alpha<-if(s$dd<=1e-30) 0 else min(1,max(0,s$db/s$dd));c(1-alpha,alpha)}
mc_positive <- function(Q,b,kappa=1e-4) {
  lambda<-kappa*sum(diag(Q))/2;j_assert(is.finite(lambda)&&lambda>0,'Degenerate expert design.')
  A<-Q+diag(lambda,2);B<-b+lambda*c(0,1);u<-as.numeric(solve(A,B))
  cand<-list(c(0,0),c(max(0,B[1]/A[1,1]),0),c(0,max(0,B[2]/A[2,2])));if(all(u>=0)) cand[[4L]]<-u
  obj<-vapply(cand,function(w) sum(w*(A%*%w))-2*sum(B*w),numeric(1));beta<-cand[[which.min(obj)]];g<-as.numeric(A%*%beta-B)
  scale<-max(abs(B),abs(A%*%beta),1e-30);dual<-max(0,-g)/scale;comp<-max(abs(beta*g))/(scale*max(1,max(beta)));active<-beta>1e-12
  stat<-if(any(active)) max(abs(g[active]))/scale else 0;j_assert(max(dual,comp,stat)<2e-7,'Positive-combination KKT failed.')
  list(beta=beta,lambda=lambda,dual_scaled=dual,complementarity_scaled=comp,stationarity_scaled=stat,axis_E=c(0,max(0,B[2]/A[2,2])))
}
mc_pairs <- function() data.frame(method=c(rep('MCPB',6),'MaturityMix','DailyMixH','DailyMix40'),benchmark=c('EWMA','RidgeEWMA','MaturityMix','NNLS_FullH','CalEWMA','DailyMix40','DailyMixH','DailyMix40','RidgeEWMA'),family=c(rep('primary',2),rep('component',4),rep('secondary',3)),stringsAsFactors=FALSE)
mc_selftests <- function(cfg) {
  ans<-list();add<-function(name,condition) {j_assert(condition,paste('Selftest failed:',name));ans[[length(ans)+1L]]<<-data.frame(check=name,passed=TRUE)}
  Q<-diag(c(2,3));b<-c(1,6);k<-1e-4;x<-mc_positive(Q,b,k);lam<-k*2.5
  add('positive_interior_matches_closed_form',max(abs(x$beta-c(1/(2+lam),(6+lam)/(3+lam))))<1e-12)
  x<-mc_positive(diag(2),c(-2,3),k);add('nonnegative_boundary_is_exact',x$beta[1]==0 && x$beta[2]>0)
  x<-mc_positive(matrix(1,2,2),c(2,2),k);add('collinear_experts_have_finite_unique_regularized_solution',all(is.finite(x$beta))&&all(x$beta>=0))
  x1<-mc_positive(Q,b,k);x2<-mc_positive(Q*1e6,b*1e6,k);add('common_scale_invariance',max(abs(x1$beta-x2$beta))<1e-12)
  add('simplex_known_solution',max(abs(mc_simplex(list(dd=2,db=1))-c(.5,.5)))==0);add('simplex_left_boundary',all(mc_simplex(list(dd=2,db=-1))==c(1,0)));add('simplex_right_boundary',all(mc_simplex(list(dd=2,db=4))==c(0,1)))
  set.seed(1909);o<-1:350;R<-matrix(rexp(350*4),350,4);E<-R+.3;Y<-R+.1;pr<-mc_prefix(R,E,Y);s<-mc_stats(pr,o,300,4,252)
  direct<-matrix(0,2,2);bb<-c(0,0)
  for(h in 1:4) {ii<-tail(which(o+h<=300),252);X<-cbind(R[ii,h],E[ii,h]);direct<-direct+crossprod(X)/length(ii)/4;bb<-bb+as.numeric(crossprod(X,Y[ii,h]))/length(ii)/4}
  add('prefix_criterion_matches_direct_mature_cells',max(abs(s$Q-direct))<1e-12 && max(abs(s$b-bb))<1e-12)
  YY<-Y;for(h in 1:4) YY[o+h>300,h]<-1e6;ss<-mc_stats(mc_prefix(R,E,YY),o,300,4,252)
  add('future_labels_cannot_change_current_weights',max(abs(s$b-ss$b))==0);add('maturity_cells_end_no_later_than_cut',s$max_target<=300)
  full<-mc_stats(pr,o,300,4,252,'full40');add('partial_feedback_is_more_recent_than_full40',s$newest_origin>full$newest_origin)
  P<-cumsum(c(1,0,2,1));U<-cumsum(c(.1,.4,.5,1));V<-2*P+.7*U;add('positive_non_simplex_sum_preserves_shape',V[1]>=0 && all(diff(V)>=0))
  add('unconstrained_scale_can_differ_from_one',sum(mc_positive(Q,b,k)$beta)>1);pairs<-mc_pairs();add('declared_primary_and_component_contrasts',sum(pairs$family=='primary')==2 && sum(pairs$family=='component')==4);j_bind(ans)
}
mc_case <- function(d,bank,layout,protocol,H,cfg) {
  R<-bank$R[,seq_len(H),drop=FALSE];P<-j_pav(R);E<-bank$E[,seq_len(H),drop=FALSE];Y<-d$Y[match(bank$origin,d$origins),seq_len(H),drop=FALSE];prefix<-mc_prefix(P,E,Y)
  te<-layout$test;it<-match(te,bank$origin);n<-length(te);methods<-c('Ridge','Ridge_PAV','EWMA','RidgeEWMA','DailyMix40','DailyMixH','MaturityMix','CalEWMA','NNLS_FullH','MCPB','MCPB_kappa1e6','MCPB_kappa1e2')
  pred<-setNames(lapply(methods,function(m) matrix(NA_real_,n,H)),methods);pred$Ridge<-R[it,,drop=FALSE];pred$Ridge_PAV<-P[it,,drop=FALSE];pred$EWMA<-E[it,,drop=FALSE]
  monthly<-unname(split(seq_along(te),format(d$date[te],'%Y-%m')));monthly_beta<-matrix(NA_real_,n,2)
  for(jj in monthly) {cut<-min(te[jj]);ca<-tail(which(bank$origin+cfg$Hmax<=cut),cfg$meta_window);a<-gr_alpha(P[ca,,drop=FALSE],E[ca,,drop=FALSE],Y[ca,,drop=FALSE]);monthly_beta[jj,]<-rep(c(1-a,a),each=length(jj))}
  choices<-vector('list',n);cert<-matrix(0,4,3,dimnames=list(c('NNLS_FullH','MCPB','MCPB_kappa1e6','MCPB_kappa1e2'),c('dual_scaled','complementarity_scaled','stationarity_scaled')))
  for(i in seq_along(te)) {
    cut<-te[i];idx<-it[i];a40<-mc_stats(prefix,bank$origin,cut,H,cfg$meta_window,'full40');aH<-mc_stats(prefix,bank$origin,cut,H,cfg$meta_window,'fullH');ap<-mc_stats(prefix,bank$origin,cut,H,cfg$meta_window,'partial')
    j_assert(max(a40$max_target,aH$max_target,ap$max_target)<=cut,'Unmatured label used.')
    pos<-list(NNLS_FullH=mc_positive(aH$Q,aH$b,cfg$kappa),MCPB=mc_positive(ap$Q,ap$b,cfg$kappa),MCPB_kappa1e6=mc_positive(ap$Q,ap$b,1e-6),MCPB_kappa1e2=mc_positive(ap$Q,ap$b,1e-2))
    beta<-list(RidgeEWMA=monthly_beta[i,],DailyMix40=mc_simplex(a40),DailyMixH=mc_simplex(aH),MaturityMix=mc_simplex(ap),CalEWMA=pos$MCPB$axis_E)
    for(m in names(pos)) {beta[[m]]<-pos[[m]]$beta;cert[m,]<-pmax(cert[m,],unlist(pos[[m]][colnames(cert)]))}
    row<-data.frame(origin=cut,origin_date=as.character(d$date[cut]),native_fit_cut=bank$cut[idx],newest_partial_origin=ap$newest_origin,newest_fullH_origin=aH$newest_origin,newest_full40_origin=a40$newest_origin,max_partial_target=ap$max_target,min_n_partial=ap$n_min,max_n_partial=ap$n_max,q11=ap$Q[1,1],q12=ap$Q[1,2],q22=ap$Q[2,2],b1=ap$b[1],b2=ap$b[2],lambda=pos$MCPB$lambda)
    for(m in names(beta)) {pred[[m]][i,]<-beta[[m]][1]*P[idx,]+beta[[m]][2]*E[idx,];row[[paste0('betaR_',m)]]<-beta[[m]][1];row[[paste0('betaE_',m)]]<-beta[[m]][2]};choices[[i]]<-row
  }
  case<-list(asset=d$symbol,protocol=protocol,H=H,origin=te,Y=d$Y[match(te,d$origins),seq_len(H),drop=FALSE],pred=pred,choices=j_bind(choices));case$certificates<-data.frame(method=rownames(cert),cert,row.names=NULL);case
}
mc_inference <- function(case,d,cfg,seed) {
  losses<-p_loss(case,d,cfg);pairs<-mc_pairs();ans<-list();n<-nrow(case$Y)
  for(mult in cfg$bootstrap_multipliers) {
    L<-case$H*mult;W<-p_boot_weights(n,L,cfg$bootstrap_reps,seed+L)
    for(metric in c('PathMSE','PathQLIKE')) {
      loss<-losses[[metric]];point<-colMeans(loss);bl<-W%*%loss
      for(k in seq_len(nrow(pairs))) {
        m<-pairs$method[k];b<-pairs$benchmark[k];md<-point[b]-point[m];bd<-bl[,b]-bl[,m];ci<-unname(quantile(bd,c(.025,.975)))
        pre<-if(metric=='PathMSE') 100*(1-point[m]/point[b]) else NA_real_;pc<-if(metric=='PathMSE') unname(quantile(100*(1-bl[,m]/bl[,b]),c(.025,.975))) else c(NA_real_,NA_real_)
        ans[[length(ans)+1L]]<-data.frame(asset=case$asset,protocol=case$protocol,H=case$H,method=m,benchmark=b,family=pairs$family[k],metric=metric,n=n,block=L,B=cfg$bootstrap_reps,loss_improvement=md,CI_low=ci[1],CI_high=ci[2],PRE=pre,PRE_low=pc[1],PRE_high=pc[2],bootstrap_p=(1+sum(abs(bd-md)>=abs(md)))/(cfg$bootstrap_reps+1),uncertainty_scope='paired_frozen_realized_losses_not_full_model_refitting',stringsAsFactors=FALSE)
      }
    }
  };j_bind(ans)
}
mc_solver_reference_cases <- function(cfg) {
  set.seed(cfg$seed+19);rows<-list()
  for(i in 1:120) {X<-matrix(rnorm(40),20,2);if(i%%3==0) X[,2]<-X[,1]+1e-5*X[,2];yy<-rnorm(20)+X[,1]*(i%%4-1);Q<-crossprod(X)/20;b<-as.numeric(crossprod(X,yy)/20);f<-mc_positive(Q,b,cfg$kappa);rows[[i]]<-data.frame(id=i,q11=Q[1,1],q12=Q[1,2],q22=Q[2,2],b1=b[1],b2=b[2],lambda=f$lambda,beta_R=f$beta[1],beta_E=f$beta[2])};j_bind(rows)
}
mc_main <- function(cfg=mc_config()) {
  dir.create(cfg$out_dir,recursive=TRUE,showWarnings=FALSE);status<-file.path(cfg$out_dir,'RUN_STATUS.txt');if(file.exists(status) && readLines(status,n=1L,warn=FALSE)=='COMPLETE') stop('Preserve completed output; choose a new JOEF_MCPB_OUTDIR.')
  complete<-FALSE;writeLines(c('RUNNING',cfg$evidence_status),status);on.exit(if(!complete) writeLines(c('INCOMPLETE',cfg$evidence_status),status),add=TRUE)
  j_write(mc_selftests(cfg),file.path(cfg$out_dir,'SELFTESTS.csv'));j_write(mc_solver_reference_cases(cfg),file.path(cfg$out_dir,'INDEPENDENT_SOLVER_CASES.csv'))
  ref<-read.csv(cfg$reference_accuracy,stringsAsFactors=FALSE);manifest<-read.csv(cfg$reference_manifest,stringsAsFactors=FALSE);cached<-nzchar(cfg$cache_dir)
  if(cached) {cm<-read.csv(file.path(cfg$cache_dir,'NATIVE_BANK_MANIFEST.csv'),stringsAsFactors=FALSE);j_assert(nrow(cm)==30 && all(unname(tools::md5sum(file.path(cfg$cache_dir,cm$file)))==cm$md5),'Native cache checksum mismatch.')}
  accs<-infs<-pars<-chs<-certs<-timings<-inputs<-list();nc<-0L
  for(ai in seq_along(cfg$symbols)) {
    asset<-cfg$symbols[ai];prices<-j_read_prices(asset,cfg);j_assert(identical(attr(prices,'source_md5'),manifest$md5[match(asset,manifest$asset)]),'Price input differs from submitted run.')
    inputs[[ai]]<-data.frame(asset=asset,md5=attr(prices,'source_md5'),n_prices=nrow(prices));d<-j_build(prices,cfg$Hmax);layout<-p_layout(d,cfg)
    for(protocol in cfg$protocols) {
      bank<-if(cached) readRDS(file.path(cfg$cache_dir,paste0(j_slug(asset),'_',protocol,'.rds'))) else gr_bank(d,layout,protocol,cfg)
      j_assert(identical(as.integer(bank$origin),as.integer(layout$native)) && all(bank$cut<=bank$origin),'Invalid historical native bank.')
      for(H in cfg$horizons) {
        j_log('MCPB:',asset,protocol,'H=',H);nc<-nc+1L;case<-mc_case(d,bank,layout,protocol,H,cfg);acc<-gr_accuracy(case,d,cfg)
        for(m in c('Ridge','Ridge_PAV','EWMA','RidgeEWMA')) for(metric in c('n','PathMSE','H1_MSE','H1_5_MSE','PathQLIKE')) {
          got<-acc[acc$method==m,metric];rr<-ref[ref$asset==asset & ref$protocol==protocol & ref$H==H & ref$method==m,metric]
          tol<-if(metric=='n') 0 else if(metric=='PathQLIKE') 1e-8*(1+abs(rr)) else max(1e-15,1e-8*abs(rr));pass<-length(rr)==1L && is.finite(got) && abs(got-rr)<=tol
          pars[[length(pars)+1L]]<-data.frame(asset=asset,protocol=protocol,H=H,method=m,metric=metric,observed=got,reference=rr,absolute_difference=abs(got-rr),tolerance=tol,passed=pass);j_assert(pass,paste('Parent parity failed:',asset,protocol,H,m,metric))
        }
        cp<-file.path(cfg$out_dir,'cases',paste(j_slug(asset),protocol,paste0('H',H),sep='_'));dir.create(cp,recursive=TRUE,showWarnings=FALSE)
        saveRDS(case,file.path(cp,'forecast_arrays.rds'));j_write(acc,file.path(cp,'accuracy.csv'));j_write(case$choices,file.path(cp,'choices.csv'))
        ls<-p_loss(case,d,cfg);lossrows<-list()
        for(m in names(case$pred)) {z<-data.frame(asset=asset,protocol=protocol,H=H,origin=case$origin,origin_date=as.character(d$date[case$origin]),method=m);for(metric in names(ls)) z[[metric]]<-ls[[metric]][,m];lossrows[[length(lossrows)+1L]]<-z};j_write(j_bind(lossrows),file.path(cp,'origin_losses.csv'))
        ii<-mc_inference(case,d,cfg,cfg$seed+ai*1000L+match(protocol,cfg$protocols)*100L+H);j_write(ii,file.path(cp,'inference.csv'))
        ch<-case$choices;ch$asset<-asset;ch$protocol<-protocol;ch$H<-H;ce<-case$certificates;ce$asset<-asset;ce$protocol<-protocol;ce$H<-H;bt<-bank$timing;bt$asset<-asset;bt$protocol<-protocol
        accs[[nc]]<-acc;infs[[nc]]<-ii;chs[[nc]]<-ch;certs[[nc]]<-ce
      };timings[[length(timings)+1L]]<-bt
    }
  }
  inf<-j_bind(infs);inf$p_holm_primary<-NA_real_;inf$p_holm_component<-NA_real_;scope<-inf$H==30 & inf$protocol=='expanding' & inf$block==30 & inf$metric=='PathMSE'
  for(f in c('primary','component')) {ix<-scope & inf$family==f;n<-if(f=='primary') 30L else 60L;j_assert(sum(ix)==n && !anyDuplicated(paste(inf$asset[ix],inf$method[ix],inf$benchmark[ix])),'Incomplete declared test family.');inf[[paste0('p_holm_',f)]][ix]<-p.adjust(inf$bootstrap_p[ix],'holm')}
  j_write(j_bind(accs),file.path(cfg$out_dir,'SUMMARY_accuracy.csv'));j_write(inf,file.path(cfg$out_dir,'SUMMARY_inference.csv'));j_write(j_bind(pars),file.path(cfg$out_dir,'REFERENCE_PARITY_CHECKS.csv'));j_write(j_bind(chs),file.path(cfg$out_dir,'SUMMARY_choices.csv'));j_write(j_bind(certs),file.path(cfg$out_dir,'SOLVER_AUDIT_CASE_MAXIMA.csv'));j_write(j_bind(timings),file.path(cfg$out_dir,'Native_Timing.csv'));j_write(j_bind(inputs),file.path(cfg$out_dir,'INPUT_MANIFEST.csv'));saveRDS(cfg,file.path(cfg$out_dir,'CONFIGURATION.rds'));capture.output(sessionInfo(),file=file.path(cfg$out_dir,'SESSION_INFO.txt'))
  if(!is.na(cfg$script)) file.copy(cfg$script,file.path(cfg$out_dir,'SOURCE_MCPB.R'),overwrite=TRUE)
  writeLines(c('COMPLETE',cfg$evidence_status,'cases 120','primary_family 30','component_family 60',paste('native_cache_used',cached),'No untouched independent holdout was used.'),status);complete<-TRUE;j_log('MCPB complete:',cfg$out_dir);invisible(list(accuracy=j_bind(accs),inference=inf))
}
mc_source_capture <- function(script=NA_character_) {
  if(is.character(script)&&length(script)==1L&&!is.na(script)&&file.exists(script)) {
    return(list(file=normalizePath(script,winslash='/',mustWork=TRUE),md5=unname(tools::md5sum(script)),mode='exact_script_bytes'))
  }
  env<-environment(mc_main);nms<-MC_CODE_FUNCTIONS
  canonical<-function(x) deparse(x,width.cutoff=500L,control=c('keepNA','keepInteger','niceNames'))
  decl<-canonical(nms)
  lines<-c('# MCPB loaded-function snapshot; defines functions without starting a run.',paste0('MC_CODE_FUNCTIONS <- ',decl[1L]),decl[-1L],'')
  for(nm in nms) {
    f<-get(nm,envir=env,inherits=FALSE)
    definition<-canonical(as.call(list(as.name('function'),formals(f),body(f))))
    lines<-c(lines,paste0(nm,' <- ',definition[1L]),definition[-1L],'')
  }
  path<-tempfile('MCPB_loaded_source_',fileext='.R');writeLines(enc2utf8(lines),path,useBytes=TRUE)
  list(file=path,md5=unname(tools::md5sum(path)),mode='loaded_function_snapshot')
}


MC_CODE_FUNCTIONS <- c("j_bool","j_int","j_slug","j_assert","j_log","j_bind","j_hash","j_write","j_asset_universe","j_synthetic_prices","j_fetch_yahoo","j_read_prices","j_rollmean","j_build","j_hac","j_increments","j_cumulate","j_linear","j_predict_linear","j_pav","p_layout","p_training","p_choose_ridge","p_ewma","p_boot_weights","p_loss","gr_alpha","gr_native_block","gr_bank","gr_accuracy","mc_config","mc_prefix","mc_stats","mc_simplex","mc_positive","mc_pairs","mc_selftests","mc_case","mc_inference","mc_solver_reference_cases","mc_main","mc_source_capture")
if(!j_bool(Sys.getenv('JOEF_MCPB_NO_AUTO','false'))) MCPB_RESULT<-mc_main()
