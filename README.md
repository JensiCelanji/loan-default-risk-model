# Loan Default Risk Model

I wanted to understand how lenders decide who gets approved for a loan, so I built a credit risk model on real Lending Club data and turned it into a dashboard where you can adjust the approval cutoff and see what happens.

<img width="1447" height="796" alt="image" src="https://github.com/user-attachments/assets/e217bac7-0fe8-4368-bf41-121f93ad61d2" />


## The Question
If you're a lender, how strict should you be? Approve too many people and defaults go up. Approve too few and you lose business. I wanted to find where that balance is and put real numbers on it.

## What I Used
- **PostgreSQL** to clean the data and build features
- **R (tidymodels)** to train and evaluate the model
- **Power BI** for the interactive dashboard

## The Data
I used Lending Club's loan data from 2007 to 2018 ([Kaggle link](https://www.kaggle.com/datasets/wordsforthewise/lending-club)). The full dataset has over 2 million loans, but a lot of them were still being paid off, so there was no way to know if they'd default. I kept only the loans that had actually finished, which left me with **1,348,099 loans** and a **20% default rate**.

## How I Built It
1. **Loaded the data into PostgreSQL with R.** The raw file has 150+ columns, but I only kept 31. I made sure to leave out anything that happens after a loan is approved (like total payments made), since the model wouldn't have that information in real life. Using it would basically be cheating.
2. **Created 15 new features in SQL**, like how much of someone's income goes to their loan payment, how long they've had credit, and whether they're maxing out their credit cards.
3. **Trained a logistic regression model in R.** I went with logistic regression instead of something more complex because lenders actually have to explain why they deny someone, and logistic regression makes that possible.
4. **Tested different approval cutoffs** to see how the approval rate and default rate change together.
5. **Built a dashboard in Power BI** with a slider so you can pick a cutoff and watch all the numbers update.

## What I Found
- The model scored an **AUC of 0.71**, which is solid for this dataset.
- The biggest red flags for default were **longer loan terms** (60-month loans are way riskier), **high debt-to-income**, and **lower FICO scores**.
- At a cutoff of 0.33, a lender could still approve **85% of applicants** and keep **81% of loan volume** while dropping the default rate from **20% to 16.2%**. That's a **19% reduction** in defaults.
- Lending Club's grades line up with risk pretty well: grade A loans defaulted about 6% of the time, compared to 38% for grade G.
- **Small business** and **educational** loans were the riskiest, while **debt consolidation** loans made up the biggest chunk of volume.

## Things I'd Improve
- The 2018 loans look less risky than they really are. The ones that finished early are mostly people who paid off early or defaulted fast, so it skews the numbers. Next time I'd split the data by time instead of randomly.
- I included Lending Club's own grade and interest rate as features. They help the model a lot, but they're based on Lending Club's own risk scoring, so the model is partly building on their work.
- I'd like to try XGBoost to see if it beats logistic regression, even if it's harder to explain.

## Files
| File | What it does |
|---|---|
| `01_load_data.R` | Loads the raw data into PostgreSQL |
| `02_features.sql` | Cleans the data and creates features |
| `03_model.R` | Trains the model and tests approval cutoffs |
| `loan_default_dashboard.pbix` | The Power BI dashboard |
| `output/` | Charts and dashboard screenshot |

## Running It Yourself
1. Download the data from Kaggle and put `accepted_2007_to_2018Q4.csv.gz` in a `data/` folder.
2. Create a PostgreSQL database called `my_portfolio`.
3. Run `01_load_data.R`, then `02_features.sql` in pgAdmin, then `03_model.R`.
4. Open the `.pbix` file in Power BI Desktop.
