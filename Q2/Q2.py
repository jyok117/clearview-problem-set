# %% [markdown]
# # Classification of Disease Severity Using Simple Rules

# %%
from sklearn.metrics import confusion_matrix
import pandas as pd
!pip install pandas
!pip install scikit-learn

# %%

file_path = 'Mild Moderate Severe Data_Final.csv'
data = pd.read_csv(file_path)

data.head()

# %% [markdown]
# The dataset includes the following relevant columns:
# - `Final Category`: The severity classification as determined by the physician (Mild, Moderate, Severe).
# - Various symptom flags (e.g., `Fatigue`, `Weakness`, `Depression`, etc.) that indicate the presence (1) or absence (0) of symptoms.
# - `Number of Symptoms`: The total number of symptoms a patient has.

# %%
# Checking the distribution of the 'Final Category' to understand the data balance
data['Final Category'].value_counts()

# %% [markdown]
# The dataset is perfectly balanced, with 100 cases each for `Mild`, `Moderate`, and `Severe` categories.

# %% [markdown]
# Exploring the relationships between symptoms and severity to derive the rules that might be useful to classify the severity of the condition.

# %%
# Grouping by 'Final Category' to see the mean presence of symptoms across severity levels
symptom_columns = data.columns[2:-1]
severity_means = data.groupby('Final Category')[symptom_columns].mean()

severity_means.T  # Transpose for easier viewing

# %% [markdown]
# From the analysis, here are some clear patterns between symptom prevalence and severity levels:
# - `Mild` cases typically show low frequencies across most symptoms.
# - `Moderate` cases see a marked increase in symptoms like fatigue, weakness, depression, anxiety, and headaches.
# - `Severe` cases have the highest presence of more intense symptoms like spasms, cramps, and tingling.

# %% [markdown]
# Here are some simple rules based on these patterns and then use them to predict the severity for each patient.

# %%
# Rule for Mild: Few symptoms, particularly not high on severe symptoms


def classify_mild(row):
    return row['Number of Symptoms'] <= 2 and row['Spasms'] == 0 and row['Cramps'] == 0

# %%
# Rule for Severe: Presence of more severe symptoms like spasms, cramps, or a high number of symptoms


def classify_severe(row):
    return row['Spasms'] == 1 or row['Cramps'] == 1 or row['Number of Symptoms'] > 5

# %%
# Rule for Moderate: Falls between mild and severe, moderate number of symptoms and common symptoms like fatigue, depression, etc.


def classify_moderate(row):
    return not classify_mild(row) and not classify_severe(row)

# %% [markdown]
# Calculating the confusion matrix to evaluate the effectiveness of these rules.


# %%
# Applying the rules
data['Predicted Category'] = data.apply(lambda row: 'Mild' if classify_mild(
    row) else ('Severe' if classify_severe(row) else 'Moderate'), axis=1)


conf_matrix = confusion_matrix(data['Final Category'], data['Predicted Category'], labels=[
                               'Mild', 'Moderate', 'Severe'])

conf_matrix


# %% [markdown]
# ## Summary

# %% [markdown]
# ### Extracted Rules:
# 1. `Mild`: Patients with 2 or fewer symptoms, no spasms, and no cramps.
# 2. `Moderate`: Patients who do not fit into the mild or severe categories, with symptoms like fatigue, depression, or anxiety but without severe symptoms.
# 3. `Severe`: Patients with spasms, cramps, or more than 5 symptoms.

# %% [markdown]
# ### Confusion Matrix:
#
# |               | Predicted Mild | Predicted Moderate | Predicted Severe |
# |---------------|----------------|--------------------|------------------|
# | Actual Mild   | 86             | 12                 | 2                |
# | Actual Moderate| 9             | 86                 | 5                |
# | Actual Severe | 0              | 16                 | 84               |

# %% [markdown]
# ### Key Findings:
# - `Mild` Classification: The rule for mild severity successfully captured 86 out of 100 actual mild cases, misclassifying 12 patients as moderate and 2 as severe.
# - `Moderate` Classification: 86 out of 100 moderate patients were correctly classified. There was some confusion with mild and severe categories, with 9 and 5 patients misclassified, respectively.
# - `Severe` Classification: 84 out of 100 severe cases were correctly identified, though 16 patients were misclassified as moderate, indicating some overlap in symptom presentation between moderate and severe categories.

# %% [markdown]
# ### Approach:
#
# I examined the symptom prevalence across severity categories to extract simple classification rules based on the number of symptoms and the presence of specific severe symptoms (e.g., spasms, cramps). These rules were applied to classify patients, and the confusion matrix was used to evaluate their accuracy.

# %% [markdown]
#
