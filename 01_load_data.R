library(data.table)
library(DBI)
library(RPostgres)

con <- dbConnect(
  Postgres(),
  dbname   = "my_portfolio",
  host     = "localhost",
  port     = 5432,
  user     = "postgres",
  password = Sys.getenv("PG_PASSWORD"),
  bigint   = "numeric"
)

cols <- c(
  "id", "loan_amnt", "funded_amnt", "term", "int_rate", "installment",
  "grade", "sub_grade", "emp_length", "home_ownership", "annual_inc",
  "verification_status", "issue_d", "loan_status", "purpose", "addr_state",
  "dti", "delinq_2yrs", "earliest_cr_line", "fico_range_low",
  "fico_range_high", "inq_last_6mths", "open_acc", "pub_rec", "revol_bal",
  "revol_util", "total_acc", "mort_acc", "pub_rec_bankruptcies",
  "total_rec_prncp", "recoveries"
)

loans <- fread("data/accepted_2007_to_2018Q4.csv.gz", select = cols)

loans <- loans[!is.na(loan_amnt)]
loans[, id := as.character(id)]

cat("Rows loaded:", format(nrow(loans), big.mark = ","), "\n")
print(loans[, .N, by = loan_status][order(-N)])

dbWriteTable(con, "loans_raw", as.data.frame(loans), overwrite = TRUE)
cat("Table loans_raw written to PostgreSQL\n")

dbDisconnect(con)