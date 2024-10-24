## --------------------------------------------------------------------------------------------
options(repos = c(CRAN = "https://cloud.r-project.org/"))

install.packages("readxl")
install.packages("openxlsx")
install.packages("dplyr")
install.packages("tidyr")
install.packages("lubridate")

library(readxl)
library(openxlsx)
library(dplyr)
library(tidyr)
library(lubridate)


## --------------------------------------------------------------------------------------------
file_path <- "SAS_Data_Experienced.xlsx"


## --------------------------------------------------------------------------------------------
activity_df <- read_excel(file_path, sheet = "Activity")
diagnosis_df <- read_excel(file_path, sheet = "Diagnosis")
rx_df <- read_excel(file_path, sheet = "Rx")


## --------------------------------------------------------------------------------------------
head(activity_df)
head(diagnosis_df)
head(rx_df)


## --------------------------------------------------------------------------------------------
diagnosis_df$Date <- as.Date(diagnosis_df$Date)
rx_df$`Rx Date` <- as.Date(rx_df$`Rx Date`)


## --------------------------------------------------------------------------------------------
activity_long <- activity_df %>%
  pivot_longer(
    cols = starts_with("M_"),
    names_to = "Month",
    values_to = "Enrolled"
  ) %>%
  arrange(Patient_ID, Month) %>%
  mutate(
    Year_Month = ymd(paste0(gsub("M_", "", Month), "01"))
  )


## --------------------------------------------------------------------------------------------
activity_long


## --------------------------------------------------------------------------------------------
has_12_consecutive <- function(enrollments) {
  rle_result <- rle(enrollments)
  any(rle_result$values == 1 & rle_result$lengths >= 12)
}


## --------------------------------------------------------------------------------------------
patients_continuous <- activity_long %>%
  group_by(Patient_ID) %>%
  summarise(continuous_12_months = has_12_consecutive(Enrolled)) %>%
  filter(continuous_12_months == TRUE) %>%
  select(Patient_ID)


## --------------------------------------------------------------------------------------------
patients_continuous


## --------------------------------------------------------------------------------------------
write.xlsx(patients_continuous, "patients_continuously_12_months.xlsx")


## --------------------------------------------------------------------------------------------
recent_months <- activity_long %>%
  group_by(Patient_ID) %>%
  arrange(desc(Year_Month)) %>%
  slice_head(n = 12)


## --------------------------------------------------------------------------------------------
recent_months


## --------------------------------------------------------------------------------------------
recently_enrolled <- recent_months %>%
  group_by(Patient_ID) %>%
  summarise(All_Enrolled = all(Enrolled == 1)) %>%
  filter(All_Enrolled == TRUE) %>%
  select(Patient_ID)


## --------------------------------------------------------------------------------------------
recently_enrolled


## --------------------------------------------------------------------------------------------
write.xlsx(recently_enrolled, "patients_most_recent_12_months.xlsx")


## --------------------------------------------------------------------------------------------
recently_enrolled <- read_excel("patients_most_recent_12_months.xlsx")


## --------------------------------------------------------------------------------------------
icd_codes_of_interest <- c("299.00", "399.88", "495.01")


## --------------------------------------------------------------------------------------------
most_recent_date <- max(activity_long$Year_Month)
one_year_ago <- most_recent_date %m-% months(11)


## --------------------------------------------------------------------------------------------
print(most_recent_date)
print(one_year_ago)


## --------------------------------------------------------------------------------------------
recent_diagnosis_df <- diagnosis_df %>%
  filter(
    Patient_ID %in% recently_enrolled$Patient_ID,
    Diag_Code %in% icd_codes_of_interest,
    Date >= one_year_ago & Date <= most_recent_date
  )


## --------------------------------------------------------------------------------------------
recent_diagnosis_df


## --------------------------------------------------------------------------------------------
patients_with_at_least_2_icd <- recent_diagnosis_df %>%
  group_by(Patient_ID) %>%
  summarise(ICD_Count = n()) %>%
  filter(ICD_Count >= 2)


## --------------------------------------------------------------------------------------------
patients_with_at_least_2_icd


## --------------------------------------------------------------------------------------------
patients_continuous <- read_excel("patients_continuously_12_months.xlsx")


## --------------------------------------------------------------------------------------------
icd_codes_of_interest <- c("299.00", "399.88", "495.01")


## --------------------------------------------------------------------------------------------
diagnosis_with_2_icd <- diagnosis_df %>%
  filter(
    Patient_ID %in% patients_continuous$Patient_ID,
    Diag_Code %in% icd_codes_of_interest
  ) %>%
  group_by(Patient_ID) %>%
  summarise(ICD_Count = n(), First_Diagnosis_Date = min(Date)) %>%
  filter(ICD_Count >= 2)


## --------------------------------------------------------------------------------------------
diagnosis_with_2_icd


## --------------------------------------------------------------------------------------------
patient_diagnosis_activity <- activity_long %>%
  filter(Patient_ID %in% diagnosis_with_2_icd$Patient_ID) %>%
  left_join(diagnosis_with_2_icd, by = "Patient_ID") %>%
  mutate(
    Diagnosis_Washout_Period = interval(First_Diagnosis_Date %m-% months(12), First_Diagnosis_Date),
    Diagnosis_Look_Forward_Period = interval(First_Diagnosis_Date, First_Diagnosis_Date %m+% months(24))
  )


## --------------------------------------------------------------------------------------------
patient_diagnosis_activity


## --------------------------------------------------------------------------------------------
patients_with_washout <- patient_diagnosis_activity %>%
  group_by(Patient_ID) %>%
  filter(Year_Month <= First_Diagnosis_Date) %>%
  summarise(Enrolled_12_Months_Before = all(Enrolled == 1))


## --------------------------------------------------------------------------------------------
patients_with_look_forward <- patient_diagnosis_activity %>%
  group_by(Patient_ID) %>%
  filter(Year_Month >= First_Diagnosis_Date) %>%
  summarise(Enrolled_24_Months_After = all(Enrolled == 1))


## --------------------------------------------------------------------------------------------
patients_with_2_icd_washout_and_look_forward <- patients_with_washout %>%
  inner_join(patients_with_look_forward, by = "Patient_ID") %>%
  inner_join(diagnosis_with_2_icd, by = "Patient_ID") %>%
  filter(Enrolled_12_Months_Before == TRUE & Enrolled_24_Months_After == TRUE)


## --------------------------------------------------------------------------------------------
patients_with_2_icd_washout_and_look_forward


## --------------------------------------------------------------------------------------------
drugs_of_interest <- c("Abilify", "Seroquel")


## --------------------------------------------------------------------------------------------
patients_with_treatment <- rx_df %>%
  filter(
    Patient_ID %in% patients_with_2_icd_washout_and_look_forward$Patient_ID,
    Drug %in% drugs_of_interest
  )


## --------------------------------------------------------------------------------------------
patients_with_treatment


## --------------------------------------------------------------------------------------------
patients_with_treatment <- patients_with_treatment %>%
  left_join(diagnosis_with_2_icd, by = "Patient_ID")


## --------------------------------------------------------------------------------------------
patients_with_treatment


## --------------------------------------------------------------------------------------------
patients_treated_within_24_months <- patients_with_treatment %>%
  filter(`Rx Date` >= First_Diagnosis_Date & `Rx Date` <= (First_Diagnosis_Date %m+% months(24)))


## --------------------------------------------------------------------------------------------
patients_treated_within_24_months


## --------------------------------------------------------------------------------------------
individual_counts <- patients_treated_within_24_months %>%
  group_by(Drug) %>%
  distinct(Patient_ID) %>%
  summarise(Num_Patients = n())

total_patients_treated <- patients_treated_within_24_months %>%
  distinct(Patient_ID) %>%
  count()

print(individual_counts)
print(total_patients_treated)


## --------------------------------------------------------------------------------------------
drugs_of_interest <- c("Abilify", "Seroquel")


## --------------------------------------------------------------------------------------------
patients_with_treatment <- rx_df %>%
  filter(
    Patient_ID %in% patients_treated_within_24_months$Patient_ID,
    Drug %in% drugs_of_interest
  )


## --------------------------------------------------------------------------------------------
patients_with_treatment


## --------------------------------------------------------------------------------------------
patients_with_treatment <- patients_with_treatment %>%
  left_join(diagnosis_with_2_icd, by = "Patient_ID")


## --------------------------------------------------------------------------------------------
patients_with_treatment


## --------------------------------------------------------------------------------------------
patients_first_treatment <- patients_with_treatment %>%
  filter(`Rx Date` >= First_Diagnosis_Date & `Rx Date` <= (First_Diagnosis_Date %m+% months(24))) %>%
  group_by(Patient_ID, Drug) %>%
  summarise(First_Treatment_Date = min(`Rx Date`))


## --------------------------------------------------------------------------------------------
patients_first_treatment


## --------------------------------------------------------------------------------------------
patients_with_prior_treatment <- patients_first_treatment %>%
  left_join(rx_df, by = c("Patient_ID", "Drug")) %>%
  filter(`Rx Date` < First_Treatment_Date & `Rx Date` >= (First_Treatment_Date %m-% months(12)))


## --------------------------------------------------------------------------------------------
patients_with_prior_treatment


## --------------------------------------------------------------------------------------------
patients_with_washout_treatment <- patients_first_treatment %>%
  filter(!(Patient_ID %in% patients_with_prior_treatment$Patient_ID))


## --------------------------------------------------------------------------------------------
patients_with_washout_treatment


## --------------------------------------------------------------------------------------------
patients_days_supply <- patients_with_washout_treatment %>%
  left_join(rx_df, by = c("Patient_ID", "Drug")) %>%
  left_join(diagnosis_with_2_icd, by = "Patient_ID") %>%
  filter(
    `Rx Date` >= First_Treatment_Date & 
    `Rx Date` <= (First_Treatment_Date %m+% months(12)) &
    `Rx Date` <= (First_Diagnosis_Date %m+% months(24))
  ) %>%
  group_by(Patient_ID, Drug) %>%
  summarise(
    Mean_Days_Supply = mean(Days_Supply, na.rm = TRUE),
    Median_Days_Supply = median(Days_Supply, na.rm = TRUE)
  )


## --------------------------------------------------------------------------------------------
patients_days_supply

