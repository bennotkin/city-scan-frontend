# These come from https://raw.githubusercontent.com/compoundrisk/monitor/databricks/src/fns/helpers.R
# Would be better to make a package

`%ni%` <- Negate(`%in%`)

which_not <- function(v1, v2, swap = F, both = F) {
  if (both) {
    list(
      "In V1, not in V2" = v1[v1 %ni% v2],
      "In V2, not in V1" = v2[v2 %ni% v1]
    )
  } else
  if (swap) {
    v2[v2 %ni% v1]
  } else {
    v1[v1 %ni% v2]
  }
}

paste_path <- compiler::cmpfun(function(...) {
  items <- c(...)
  if (items[1] == "") items <- items[-1]
  path <- paste(items, collapse = "/") %>%
    { gsub("/+", "/", .) }
  return(path)
})

paste_and <- function(v) {
    if (length(v) == 1) {
    string <- paste(v)
  } else {
    # l[1:(length(l)-1)] %>% paste(collapse = ", ")
    paste(head(v, -1), collapse = ", ") %>%
    paste("and", tail(v, 1))
  }
}

duplicated2way <- duplicated_all <- function(x) {
  duplicated(x) | duplicated(x, fromLast = T)
}

yaml_as_df <- function(yaml, print = F) {
  items <- names(yaml)
  keys <-  unique(unlist(sapply(yaml, names)))
  tib <- bind_cols(lapply(keys, function(k) tibble({{k}} := rep(list(NA), length(items)))))
  for (j in colnames(tib)) {
    for (i in seq_along(items)) {
      tib[i, j] <- list(yaml[[i]][j])
    }
    tib[[j]][sapply(tib[[j]], is.null)] <- NA
    if (all(lengths(tib[[j]])<=1)) tib[j] <- unlist(tib[j])
  }
  tib <- bind_cols(item = items, tib)
  # This method is much simpler but is 4x slower
  # tib <- bind_rows(lapply(yaml, function(item) {
  #   tidyr::pivot_wider(tibble::enframe(item), names_from = name, values_from = value)
  # }))
  if(print) print(as.data.frame(tib), right = F)
  return(tib)
}
