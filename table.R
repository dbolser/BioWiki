if(!interactive())
  png()

## my.dat <- 
##   read.table("table.dat", sep="\t")


## barplot(table(my.dat$V1),
##         main="New BioWikis by Year")




## The table can be downloaded from the wiki directly using:
## curl "http://www.bioinformatics.org/wiki/Special:Ask/-5B-5BCategory:BioWiki-5D-5D/-3FCategories/-3FContent-20pages-20new/-3FContributions/-3FCreated-23ISO/-3FEdits/-3FEmail/-3FExtension/-3FHomepage/-3FInstitution/-3FLogo-20file/-3FMediaWiki-20API-20URL/-3FModification-20date/-3FPerson/-3FPlatform/-3FUsers/-3FUsers-20active/format%3Dcsv/sep%3D,/mainlabel%3DName/headers%3Dshow/limit%3D100" >  biowiki.table.csv

my.dat <-
  read.csv("biowiki.table.csv")

head(my.dat, 3)
nrow(my.dat)

as.Date(my.dat$Created)

## Test for 'bad' dates
my.dat[is.na(as.Date(my.dat$Created)),]

my.years <-
  format(as.Date(my.dat$Created), "%Y")

barplot(table(my.years),
        main="New BioWikis by Year")
