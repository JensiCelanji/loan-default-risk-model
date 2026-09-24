library(DBI)
library(RPostgres)
library(tidyverse)
library(tidymodels)
tidymodels_prefer()
set.seed(42)

con <- dbConnect(
  Postgres(),
  dbname   = "my_portfolio",
  host     = "localhost",
  port     = 5432,
  user     = "postgres",
  password = Sys.getenv("PG_PASSWORD"),
  bigint   = "numeric"
)

# 1. Load features
loans <- dbGetQuery(con, "SELECT * FROM loan_features") |>
  as_tibble() |>
  mutate(defaulted = factor(if_else(defaulted == 1, "default", "paid"),
                            levels = c("default", "paid")))

cat("Completed loans:", format(nrow(loans), big.mark = ","), "\n")

# 2. Train / test split
split <- initial_split(loans, prop = 0.75, strata = defaulted)
train <- training(split)
test  <- testing(split)

predictors <- c(
  "loan_amnt", "term_months", "int_rate", "grade", "emp_years",
  "home_ownership", "purpose", "fico_avg", "log_annual_inc", "dti_clean",
  "payment_to_income", "loan_to_income", "credit_history_years",
  "revol_util_clean", "open_acc_ratio", "any_derog",
  "recent_inquiries_flag", "has_mortgage", "high_utilization_flag",
  "income_verified", "delinq_2yrs", "inq_last_6mths", "pub_rec_bankruptcies",
  "mort_acc"
)

train_m <- train |> select(defaulted, all_of(predictors))
test_m  <- test  |> select(defaulted, all_of(predictors))

# 3. Preprocessing
rec <- recipe(defaulted ~ ., data = train_m) |>
  step_unknown(all_nominal_predictors()) |>
  step_other(all_nominal_predictors(), threshold = 0.01, other = "rare_category") |>
  step_impute_median(all_numeric_predictors()) |>
  step_dummy(all_nominal_predictors()) |>
  step_zv(all_predictors()) |>
  step_normalize(all_numeric_predictors())

# 4. Logistic regression
log_wf <- workflow() |>
  add_recipe(rec) |>
  add_model(logistic_reg() |> set_engine("glm"))

log_fit <- fit(log_wf, data = train_m)

log_preds <- test_m |>
  select(defaulted) |>
  bind_cols(predict(log_fit, test_m, type = "prob"))

log_auc <- roc_auc(log_preds, truth = defaulted, .pred_default)
cat("\nTest AUC:", round(log_auc$.estimate, 3), "\n")

# Risk drivers (negative estimate = raises default risk)
drivers <- log_fit |>
  extract_fit_parsnip() |>
  tidy() |>
  filter(term != "(Intercept)") |>
  mutate(effect_on_default = if_else(estimate < 0, "raises risk", "lowers risk")) |>
  arrange(desc(abs(statistic)))

cat("\nTop 10 risk drivers:\n")
print(head(drivers, 10))

# 5. Charts
dir.create("output", showWarnings = FALSE)

roc_plot <- log_preds |>
  roc_curve(truth = defaulted, .pred_default) |>
  autoplot() +
  labs(title = paste0("ROC Curve - Logistic Regression (AUC = ",
                      round(log_auc$.estimate, 3), ")"))
ggsave("output/roc_curve.png", roc_plot, width = 6, height = 5)

driver_plot <- drivers |>
  head(12) |>
  mutate(term = fct_reorder(term, abs(statistic))) |>
  ggplot(aes(abs(statistic), term, fill = effect_on_default)) +
  geom_col() +
  labs(title = "Strongest Default Risk Drivers",
       x = "Strength (|z statistic|)", y = NULL, fill = NULL)
ggsave("output/risk_drivers.png", driver_plot, width = 8, height = 5)

# 6. Approval cutoff analysis
scores <- test |>
  select(id, issue_year, grade, purpose, loan_amnt, funded_amnt, loss_amount) |>
  mutate(defaulted = as.integer(test$defaulted == "default"),
         pd = log_preds$.pred_default)

baseline_default <- mean(scores$defaulted)
total_volume     <- sum(scores$funded_amnt)

cutoffs <- tibble(cutoff = seq(0.05, 0.60, by = 0.01)) |>
  mutate(stats = map(cutoff, \(c) {
    approved <- scores |> filter(pd <= c)
    tibble(
      approval_rate     = nrow(approved) / nrow(scores),
      default_rate      = mean(approved$defaulted),
      default_reduction = 1 - mean(approved$defaulted) / baseline_default,
      volume_retained   = sum(approved$funded_amnt) / total_volume,
      actual_loss       = sum(approved$loss_amount)
    )
  })) |>
  unnest(stats)

cat("\nCutoff tradeoffs:\n")
print(cutoffs |> filter(volume_retained >= 0.80) |> head(15), n = 15)

# 7. Save results for Power BI
dbWriteTable(con, "loan_scores", scores, overwrite = TRUE)
dbWriteTable(con, "loan_cutoff_summary", cutoffs, overwrite = TRUE)
dbWriteTable(con, "loan_risk_drivers", drivers, overwrite = TRUE)
cat("\nDone! Tables written to PostgreSQL.\n")

dbDisconnect(con)