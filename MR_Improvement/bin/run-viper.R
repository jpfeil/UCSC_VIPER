#!/usr/bin/env	Rscript

# Get command line options:
library('getopt')

# the real network score --
opt = getopt(matrix(c(
    'expression', 'e', 1, "character",
    'phenotypes', 'p', 1, "character",
    'output', 'o', 1, "character",
    'regulon', 'n', 1, "character",
	'regul_object', 'f', 1, "character",
    'test_phenotype', 't', 1, "character",
    'reference_phenotype', 'r', 1, "character",
    'num_results', 'y', 2, "double",
    'viper_null', 'x', 0, "logical"
    ),ncol=4,byrow=TRUE));

library(mixtools)
#library(bcellViper)
library(viper)
library(Biobase)

# Input: 
#   - A TAB separated file: the first line is column header (sample) info. 
#       The first column has feature names 
#
# Returns:
#
#       - A data matrix with the 'colnames' and 'rownames' attributes set, the first column
#       a 'character' vector with the description/HUGO id's, and the following columns are
#       numeric data. 
parse.tab <- function (file) {

  m <- read.table(file, sep="\t", row.names=1, header=TRUE, quote="", check.names=FALSE)
  return (as.matrix(m))
}

parse.phenotypes <- function (file) {
	m <- read.table(file, sep="\t", row.names=1, header=TRUE, quote="", check.names=FALSE)
	phenoData <- new("AnnotatedDataFrame", data = m)
	return (phenoData)
}

#
# Input:  
#       - A data matrix with columns as samples, rows are genes
#       - phenotype data should include sample annotations (tumor/normal classes)
#
# Returns:
#
#       A data frame of predictors, filtered down the the top X
#
makeExpressionSet <- function(data.matrix, phenoData) {

  exprSet <- new("ExpressionSet", exprs = data.matrix, phenoData = phenoData, 
		 annotation = "viper_input")

	return (exprSet)
}

run.viper.MR <- function (exp.obj, regulon, set1.label, set2.label) {

	# get set 1 indexes
	set1.idx <- which(colnames(exp.obj) %in% rownames(pData(exp.obj))[which(pData(exp.obj)[,1] == set1.label)])
	set2.idx <- which(colnames(exp.obj) %in% rownames(pData(exp.obj))[which(pData(exp.obj)[,1] == set2.label)])

	print (paste("Comparing ", length(set1.idx), " test samples with ", length(set2.idx), " reference samples..." ))

	# get just the data matrix from this object
	data.matrix = exprs(exp.obj)
	# generate the signature and normalize to z-scores
	signature <- rowTtest( data.matrix[,set1.idx], data.matrix[,set2.idx] )
	signature <- (qnorm(signature$p.value/2, lower.tail=F) * sign(signature$statistic))[, 1]
	# create the null model signatures
	nullmodel <- ttestNull(data.matrix[,set1.idx], data.matrix[,set2.idx], per=1000, repos=T)
	# compute MARINa scores based on the null model
	print(length(regulon))
	mrs <- msviper(signature, regulon, nullmodel)

	return (mrs)
}

##
## Read-in expression and phenotype data
##

exprs = parse.tab(opt$expression)
pheno = parse.phenotypes(opt$phenotypes)

# check phenotype data matches
#
if (length(setdiff(rownames(pData(pheno)),colnames(exprs)))!=0) {
	print ("Error: phenotype and expression sample lists must be identical!")
	q();
}

if ( is.null( opt$num_results) ) { opt$num_results<- 30 }


expset.obj = makeExpressionSet(exprs, pheno)
print (expset.obj)
# parse the adj file to get a regulon object:
# note: all candidate regulators and genes must be in the 
# dataset you parsed
regulon <- opt$regulon 
#load(opt$regul_object)
regul <- aracne2regulon(regulon, expset.obj)

# display the top X master regulators
num_results <- as.numeric(opt$num_results)
if (is.null(opt$num_results)) {
num_results <- 100
}

result = run.viper.MR(expset.obj, regul, opt$test_phenotype, opt$reference_phenotype)
mr.result = result

mr.summary = summary(mr.result, num_results)
write.table(mr.summary, file=paste(opt$output, "/", "masterRegulators.txt", sep=""), col.names = NA, sep="\t", quote=F)

#pdf(file=paste(opt$output, "/", "masterRegulators.pdf", sep=""))
#plot(mr.result,num_results,cex=0.7)
#dev.off()

save.image(file=paste(opt$output, "/", "master-reg.RData", sep=""))
q();


