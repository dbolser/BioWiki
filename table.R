if(!interactive())
  png()

my.dat <- 
  read.table("table.dat", sep="\t")




barplot(table(my.dat$V1),
        main="New BioWikis by Year")
