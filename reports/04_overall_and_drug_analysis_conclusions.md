# Overall and Drug Analysis

**Project:** Every Seizure Is a Signal  
**Dataset:** UNODC Individual Drug Seizures (IDS)  
**Period covered:** 2011–2025 for full-year comparisons; 2026 is partial  
**Status:** Preliminary analytical findings — revalidate using the revised SQL script

\---

## 1\. Purpose and scope

This analysis examines the distribution of reported individual drug-seizure records over time. It focuses on:

1. Overall reporting trends and country participation.
2. Changes in the composition of reported records by drug class.
3. Substance-level patterns, with a closer look at opioids.
4. Substance-level patterns and geographical concentration for cocaine-type records.

The unit of analysis is a **reported seizure record**. The number of records should not be interpreted as the quantity of drugs seized, the prevalence of a drug in a market, trafficking volume, or the number of trafficking events. The dataset does not provide origin–destination country pairs, so it cannot be used to infer trafficking routes.

Annual reporting analyses use `source\_year`, which identifies the year of the original source sheet. This is distinct from the calendar year derived from the seizure date. The 2026 data are partial and should not be compared directly with full-year observations.

> \*\*Important status note:\*\* The findings below summarize the earlier analytical outputs available for this project. The revised SQL script standardizes annual analyses on `source\_year` and corrects several percentage denominators and country groupings. Rerun the revised queries before treating these findings or figures as final.

\---

## 2\. Overall reporting trends

### 2.1 Annual volume and country participation

The dataset contains substantial variation in the number of reported seizure records across years. The annual counts previously obtained from the fact table are:

|Source year|Seizure records|Reporting countries|
|-:|-:|-:|
|2011|41,806|67|
|2012|62,090|72|
|2013|62,036|63|
|2014|265,457|53|
|2015|238,294|45|
|2016|307,817|46|
|2017|232,409|54|
|2018|220,003|82|
|2019|119,368|77|
|2020|151,682|84|
|2021|259,342|83|
|2022|235,079|98|
|2023|354,923|100|
|2024|184,464|85|
|2025|91,898|64|
|2026\*|14,620|32|

<sub>\*2026 is partial and is shown for context only. These values should be refreshed after rerunning the revised SQL queries.</sub>

The largest annual record count in this period was observed in 2023. The subsequent decline in 2024 and 2025 coincides with a reduction in the number of reporting countries. This suggests that changes in reporting participation may contribute to changes in the total number of records.

However, country participation alone does not explain all fluctuations. The comparison of countries reporting in consecutive years, and the comparison of record counts among continuing countries, are important for separating changes in coverage from changes in reported activity within the same group of countries.

### 2.2 Reporting coverage and interpretation

The analysis distinguishes:

* **Continuing countries:** countries with records in both consecutive years.
* **New countries:** countries with records in the current year but not the previous year.
* **Countries no longer reporting:** countries with records in the previous year but not the current year.

A change in the total number of records can reflect several processes: changes in the countries included, changes in the number of records submitted by continuing countries, and changes in how records are classified or transmitted.

The country-level comparisons for 2013–2014, 2023–2024 and 2024–2025 are particularly useful for identifying countries that account for large increases or decreases. These comparisons should be interpreted as changes in the reporting dataset, not necessarily changes in underlying drug markets.

### 2.3 Selected country-year comparisons

Two country comparisons were examined in more detail:

* **Colombia, 2013–2014:** the increase in records was concentrated in cannabis- and cocaine-related records.
* **Sweden, 2023–2024:** the decline affected multiple substances and warrants a closer investigation of data completeness and reporting practices.

Reporting-channel and source distributions were also examined for these country-years. These checks help assess whether changes in the observed record counts may be associated with changes in reporting processes.

**Interpretation:** these cases illustrate why annual record counts should not be interpreted in isolation. Changes in country participation, reporting channels, data sources and substance composition all matter.

\---

## 3\. Annual evolution of drug classes

Across the full dataset, the largest drug classes by number of records were previously reported as:

|Drug class|Records|Share of all records|
|-|-:|-:|
|Cannabis-type|1,297,979|45.68%|
|Cocaine-type|967,787|34.06%|
|Amphetamine-type|171,857|6.05%|
|Opioids|151,142|5.32%|
|New psychoactive substances (NPS)|64,806|2.28%|

These figures describe the composition of the full set of reported records. They are not estimates of the relative prevalence or market share of these drugs.

The annual analysis suggests several broad patterns:

* **Cannabis-type records** represent the largest category in most years.
* **Cocaine-type records** account for a substantial share of the dataset, although their relative share fluctuates and shows a longer-term decline in some comparisons.
* **Amphetamine-type records** become more prominent in several years from 2020 onward.
* **Opioid records** fluctuate considerably across years.
* **NPS records** remain a smaller category overall, although their share increases in some recent years.

These patterns should be interpreted alongside the annual number of reporting countries. A change in a class's share can result from changes in the records submitted by particular countries, differences in reporting coverage, or changes in substance classification.

The revised annual class query retains an **Unclassified** category. This is important because excluding records without a matched drug class would change the denominator and could distort the annual composition.

\---

## 4\. Drug-level analysis: opioids

The opioid analysis focuses on the composition of opioid records and their distribution across reporting countries. Heroin, fentanyl and tramadol were selected for closer examination.

### 4.1 Composition of reported opioid records

The earlier analysis indicated a substantial change in the composition of reported opioid records over time:

* Heroin was the dominant opioid category historically.
* Heroin's share of opioid records declined over the longer period, from approximately 72.95% in 2011 to 33.98% in 2023.
* Fentanyl and tramadol became more prominent in selected years.

These are changes in the composition of reported opioid records. They do not establish that the prevalence or consumption of these substances changed by the same amount.

### 4.2 Country-level concentration

The country-level analysis indicated that opioid records can be highly concentrated among a small number of reporting countries.

**Fentanyl**

* Canada accounted for more than 99% of reported fentanyl records in several years between 2020 and 2024 in the earlier output.
* In 2025, Mexico became the leading reporting country in the dataset, while Canada was absent from the records.
* This coincided with a change in overall reporting volume and country participation.

The 2025 pattern should therefore be treated as a potential reporting discontinuity. It is not sufficient evidence of a geographical shift in trafficking.

**Tramadol**

* Tramadol records were concentrated in a limited number of reporting countries, particularly Sweden and Nigeria.
* Sweden was prominent in several years between 2018 and 2023.
* Nigeria was the leading contributor in 2022, 2024 and 2025 in the earlier output.
* Nigeria's reported tramadol record count increased from 721 in 2019 to 2,042 in 2025, with fluctuations in between.

These findings should be checked against the country's total reporting volume and the composition of its reported opioid records.

**Heroin**

* Heroin was more geographically dispersed than fentanyl or tramadol in several years.
* The earlier HHI results indicated a decline in geographical concentration between 2011 and 2023, followed by an increase in 2025.
* Italy accounted for a substantial share of reported heroin records in 2025 in the earlier output.

The HHI measures concentration in the distribution of reported records across countries. It does not identify trafficking routes or the origin of seized substances.

### 4.3 Opioid composition within selected countries

The country-level composition analysis examined Canada, Sweden and Nigeria.

The earlier outputs suggested:

* Nigeria's reported opioid records became increasingly dominated by tramadol. Its share was previously calculated as increasing from approximately 65.0% in 2019 to 82.2% in 2025.
* Codeine was the second-largest opioid category in Nigeria, while heroin's relative contribution declined.
* Sweden also had a tramadol-dominated opioid profile, with oxycodone and buprenorphine accounting for meaningful shares in some years.
* Canada's opioid profile showed a substantial fentanyl component in the years when it reported fentanyl records.

These country profiles should be interpreted cautiously, particularly where overall reporting volume changes substantially between years.

### 4.4 Main takeaway for opioids

The distribution of reported opioid records is strongly influenced by a relatively small number of countries. Changes in the global composition of reported opioid records can reflect changes in country-level reporting patterns and coverage, rather than changes in underlying drug markets.

\---

## 5\. Drug-level analysis: cocaine

Cocaine-type records form one of the largest categories in the dataset. The earlier analysis identified four particularly prominent substance categories:

* Coca paste
* Cocaine base
* Non-specified cocaine-type
* Cocaine hydrochloride (powder cocaine)

Together, these categories accounted for approximately 95.2% of cocaine-type records in the earlier output.

### 5.1 Substance composition over time

The earlier annual analysis suggested that the composition of reported cocaine records changed substantially across years:

* Cocaine base was prominent in 2011.
* Coca paste became particularly prominent between 2014 and 2017.
* Cocaine base again dominated in 2018–2019.
* Non-specified cocaine-type records became particularly prominent between 2022 and 2024.
* In 2025, powder cocaine accounted for a much larger share of cocaine-type records.

These shifts may reflect changes in reporting countries and substance classification, as well as changes in the composition of reported seizures. They should not be interpreted directly as changes in the cocaine market.

### 5.2 Geographical concentration

The HHI analysis indicated substantial differences in geographical concentration across cocaine substances:

* **Coca paste and cocaine base** were highly concentrated in a relatively small number of reporting countries in several years.
* **Powder cocaine** became more geographically dispersed in the earlier 2020–2024 comparison. Its HHI declined from 0.8953 to 0.4337, while the number of reporting countries increased from 11 to 37.
* **Non-specified cocaine-type** records showed considerable variation in geographical concentration.

These results describe the distribution of records across countries. They do not indicate where substances originated or where they were transported.

### 5.3 The 2025 discontinuity

The earlier analysis identified a substantial change in the 2025 composition:

* Powder cocaine accounted for approximately 70.12% of cocaine-type records.
* Italy was the main contributor to this pattern.
* The number of countries reporting cocaine-type records declined from 72 in 2024 to 55 in 2025 in the earlier output.

This is an important discontinuity to investigate. The change could reflect country participation, differences in reporting volume, or changes in how substances were classified. It should not be presented as evidence of a sudden change in the underlying cocaine market.

### 5.4 Main takeaway for cocaine

The distribution of reported cocaine records varies substantially by substance and country. Country participation and substance classification are central to interpreting these patterns. Changes in the global distribution of records can arise from changes in which countries report and how they classify seizures.

\---

## 6\. Methodological limitations and interpretation

The following limitations apply to the analysis as a whole:

1. **Records are not quantities.** A larger number of records does not necessarily mean a larger quantity of drugs was seized.
2. **Records are not market prevalence.** The dataset does not measure consumption, availability or the size of illicit drug markets.
3. **Reporting coverage varies.** The number and identity of reporting countries change over time.
4. **Classification can change.** Countries may use different substance categories or reporting practices.
5. **2026 is partial.** It should not be compared directly with complete calendar years.
6. **No trafficking routes can be inferred.** The dataset does not contain the origin–destination pairs needed to identify routes.
7. **Concentration is descriptive.** HHI describes how reported records are distributed across countries; it does not establish causal mechanisms or trafficking geography.
8. **Measurement units matter.** Quantities should not be summed across different measurement units. This analysis therefore focuses on record counts rather than aggregating seized quantities.

\---

## 7\. Overall conclusion

The IDS dataset provides a detailed record-level view of reported drug seizures across countries and years. The analysis reveals substantial variation in annual reporting volume, country participation, drug-class composition and the geographical distribution of records for selected substances.

Cannabis-type and cocaine-type records account for the largest shares of the dataset. The composition of reported opioid records changes over time, with heroin becoming less dominant in the earlier results and fentanyl and tramadol becoming more prominent in selected country-years. Cocaine records also show substantial variation in substance composition and geographical concentration, including a notable discontinuity in the 2025 reporting data.

A central finding across all sections is that **reporting patterns are an essential part of the data-generating process**. Changes in the number or composition of records may reflect changes in reporting participation, reporting volume and substance classification. These factors need to be considered before drawing conclusions about underlying drug markets.

The most defensible interpretation is therefore that this analysis describes **patterns in reported seizure records**, rather than directly measuring drug markets, trafficking volumes or trafficking routes.

