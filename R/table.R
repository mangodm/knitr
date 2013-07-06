#' Create tables in LaTeX, HTML, Markdown and reStructuredText
#'
#' This is a very simple table generator. It is simply by design. It is not
#' intended to replace any other R packages for making tables.
#' @param x an R object (typically a matrix or data frame)
#' @param format a character string; possible values are \code{latex},
#'   \code{html}, \code{markdown} and \code{rst}; this will be automatically
#'   determined if the function is called within \pkg{knitr}; it can also be set
#'   in the global option \code{knitr.table.format}
#' @param digits the maximum number of digits for numeric columns (passed to
#'   \code{round()})
#' @param row.names whether to include row names
#' @param align the alignment of columns: a character vector consisting of
#'   \code{'l'} (left), \code{'c'} (center) and/or \code{'r'} (right); by
#'   default, numeric columns are right-aligned, and other columns are
#'   left-aligned; if \code{align = NULL}, the default alignment is used
#' @param output whether to write out the output in the console
#' @param ... other arguments (see examples)
#' @return A character vector of the table source code. When \code{output =
#'   TRUE}, the results are also written into the console as a side-effect.
#' @seealso Other R packages such as \pkg{xtable} and \pkg{tables}.
#' @export
#' @examples kable(head(iris), format = 'latex')
#' kable(head(iris), format = 'html')
#' # use the booktabs package
#' kable(mtcars, format = 'latex', booktabs = TRUE)
#' # use the longtable package
#' kable(matrix(1000, ncol=5), format = 'latex', digits = 2, longtable = TRUE)
#' # add some table attributes
#' kable(head(iris), format = 'html', table.attr = 'id="mytable"')
#' # reST output
#' kable(head(mtcars), format = 'rst')
#' # no row names
#' kable(head(mtcars), format = 'rst', row.names = FALSE)
#' # R Markdown/Github Markdown tables
#' kable(head(mtcars[, 1:5]), format = 'markdown')
#' # Pandoc tables
#' kable(head(mtcars), format = 'pandoc')
#' # save the value
#' x = kable(mtcars, format = 'html', output = FALSE)
#' cat(x, sep = '\n')
#' # can also set options(knitr.table.format = 'html') so that the output is HTML
kable = function(x, format, digits = getOption('digits'), row.names = TRUE,
                 align, output = TRUE, ...) {
  if (missing(format)) format = getOption('knitr.table.format', switch(
    out_format() %n% 'markdown', latex = 'latex', listings = 'latex', sweave = 'latex',
    html = 'html', markdown = 'markdown', rst = 'rst',
    stop('table format not implemented yet!')
  ))
  # if the original object does not have colnames, we need to remove them later
  ncn = is.null(colnames(x))
  if (!is.matrix(x) && !is.data.frame(x)) x = as.data.frame(x)
  # numeric columns
  isn = if (is.matrix(x)) rep(is.numeric(x), ncol(x)) else sapply(x, is.numeric)
  if (missing(align) || (format == 'latex' && is.null(align)))
    align = ifelse(isn, 'r', 'l')
  # rounding
  x = apply(x, 2, function(z) if (is.numeric(z)) format(round(z, digits)) else z)
  if (row.names && !is.null(rownames(x))) {
    x = cbind(' ' = rownames(x), x)
    if (!is.null(align)) align = c('l', align)  # left align row names
  }
  x = as.matrix(x)
  if (ncn) colnames(x) = NULL
  if (!is.null(align)) align = rep(align, length.out = ncol(x))
  attr(x, 'align') = align
  res = do.call(paste('kable', format, sep = '_'), list(x = x, ...))
  if (output) cat(res, sep = '\n')
  invisible(res)
}

kable_latex = function(x, booktabs = FALSE, longtable = FALSE) {
  if (!is.null(align <- attr(x, 'align'))) {
    align = paste(align, collapse = if (booktabs) '' else '|')
    align = paste('{', align, '}', sep = '')
  }

  paste(c(
    sprintf('\\begin{%s}', if (longtable) 'longtable' else 'tabular'), align,
    sprintf('\n%s\n', if (booktabs) '\\toprule' else '\\hline'),
    paste(c(if (!is.null(cn <- colnames(x))) paste(cn, collapse = ' & '),
            apply(x, 1, paste, collapse = ' & ')),
          collapse = sprintf('\\\\\n%s\n', if (booktabs) '\\midrule' else '\\hline')),
    '\\\\\n', if (booktabs) '\\bottomrule' else '\\hline',
    sprintf('\n\\end{%s}', if (longtable) 'longtable' else 'tabular')
  ), collapse = '')
}

kable_html = function(x, table.attr = '') {
  table.attr = gsub('^\\s+|\\s+$', '', table.attr)
  # need a space between <table and attributes
  if (nzchar(table.attr)) table.attr = paste('', table.attr)
  paste(c(
    sprintf('<table%s>', table.attr),
    if (!is.null(cn <- colnames(x)))
      c(' <thead>', '  <tr>', paste('   <th>', cn, '</th>'), '  </tr>', ' </thead>'),
    '<tbody>',
    paste(
      '  <tr>',
      apply(x, 1, function(z) paste('   <td>', z, '</td>', collapse = '\n')),
      '  </tr>', sep = '\n'
    ),
    '</tbody>',
    '</table>'
  ), sep = '', collapse = '\n')
}

#' Generate tables for Markdown and reST
#'
#' This function provides the basis for Markdown and reST tables.
#' @param x the data matrix
#' @param sep.row a chracter vector of length 3 that specifies the separators
#'   before the header, after the header and at the end of the table,
#'   respectively
#' @param sep.col the column separator
#' @return A character vector of the table content.
#' @noRd
kable_mark = function(x, sep.row = c('=', '=', '='), sep.col = '  ') {
  l = apply(x, 2, function(z) max(nchar(z), na.rm = TRUE))
  cn = colnames(x)
  if (!is.null(cn)) {
    if (grepl('^\\s*$', cn[1L])) cn[1L] = 'id'  # no empty cells
    l = pmax(l, nchar(cn))
  }
  if (!is.null(align <- attr(x, 'align'))) l = l + 2
  s = sapply(l, function(i) paste(rep(sep.row[2], i), collapse = ''))
  res = rbind(if (!is.na(sep.row[1])) s, cn, s, x, if (!is.na(sep.row[3])) s)
  apply(mat_pad(res, l, align), 1, paste, collapse = sep.col)
}

kable_rst = kable_mark

# actually R Markdown
kable_markdown = function(x) {
  if (is.null(colnames(x))) stop('the table must have a header (column names)')
  kable_mark(x, c(NA, '-', NA), ' | ')
}

kable_pandoc = function(x) {
  kable_mark(x, c(NA, '-', if (is.null(colnames(x))) '-' else NA), '  ')
}

# pad a matrix
mat_pad = function(m, width, align = NULL) {
  stopifnot((n <- ncol(m)) == length(width))
  res = matrix('', nrow = nrow(m), ncol = n)
  side = rep('both', n)
  if (!is.null(align)) side = c(l = 'right', c = 'both', r = 'left')[align]
  for (j in 1:n) {
    res[, j] = str_pad(m[, j], width[j], side = side[j])
  }
  res
}