# 06. Transportation and Temporal Analysis — Conclusions

## Purpose and scope

This analysis examines (1) the availability and distribution of transportation-mode information in the UNODC Individual Drug Seizures (IDS) dataset and (2) temporal patterns in the dates of reported seizure records.

The main comparisons cover **2011–2025**. The 2026 data are partial and are excluded from the main annual and monthly comparisons.

## Main findings

### 1. Transportation information is unavailable for most records

Transportation information is recorded as `Data not available` for approximately **89.21% of all records** in the dataset. This leaves only a minority of records with a usable transportation-mode category.

This is the central limitation of the transportation analysis. Any distribution calculated among records with a reported mode describes only this selected subset, not all seizures in the dataset.

### 2. Transportation reporting varies across countries and years

The availability of transportation information is uneven across countries and across source years. Consequently, differences in the reported frequency of transportation modes may reflect differences in reporting practices and data coverage, rather than differences in actual transportation practices.

Country-level reporting coverage is therefore an important diagnostic and should be considered before comparing countries.

The original exploratory analysis also noted examples of substantial differences in country-level coverage. Any country-specific percentages should be reported only with their precise denominator and population (for example, all drug records versus cocaine records). Do not reuse the earlier Spain/Colombia comparison as a cocaine-specific result unless it has been recalculated with an explicit cocaine filter.

### 3. Reported transportation modes are descriptive, not representative

Among records for which a transportation mode is available, postal, airplane, and land-based transportation are frequently reported in the exploratory results.

However, because nearly nine in ten records lack transportation information, these categories cannot be interpreted as representative of actual trafficking methods. The observed distribution may be shaped by which countries report transportation details and which cases include that information.

The analysis should not be used to infer trafficking routes. The IDS dataset does not provide origin–destination country pairs.

### 4. Monthly patterns are modest

The exploratory monthly analysis suggests some variation in the distribution of records across calendar months. In the country-year normalized comparison, March has the highest average monthly share (approximately **9.05%**) and December the lowest (approximately **7.41%**).

The differences are modest. They should not be presented as evidence of a strong seasonal pattern without further analysis and consideration of reporting coverage, enforcement activity, and data collection practices.

The normalized comparison gives equal weight to eligible country-years, rather than allowing countries with very large numbers of records to dominate the result. Eligibility requires at least one record in each of the twelve months; this does not prove that reporting was complete or continuous.

## Interpretation and limitations

- **Missing transportation information:** `Data not available`, SQL `NULL`, and blank values should all be treated as unavailable. `Not applicable/not transported` is a separate category and should not be conflated with missing information.
- **Selection of reported records:** Transportation-mode shares are conditional on a mode being reported. They are not shares of all seizure records.
- **Uneven country coverage:** Countries differ in the completeness of transportation reporting. Cross-country comparisons should include coverage rates and record counts.
- **No route inference:** Transportation mode is not equivalent to an origin–destination route. The dataset does not support reconstruction of trafficking routes.
- **Temporal interpretation:** `source_year` is the year associated with the source workbook sheet, while the calendar year comes from the seizure date. They are conceptually different and should not be interchanged.
- **Monthly normalization:** A country-year with observations in all twelve months is not necessarily a fully or consistently reporting country-year. The normalized monthly comparison remains descriptive.
- **Partial 2026:** 2026 is incomplete and should not be compared directly with complete years.

## Overall conclusion

The transportation analysis is constrained by substantial missing information: approximately 89.21% of records do not provide a usable transportation mode. The available records indicate that postal, airplane, and land-based modes are frequently reported, but the coverage limitations prevent these observations from being generalized to trafficking activity as a whole.

The temporal analysis suggests modest differences in monthly record distributions, with March relatively high and December relatively low in the country-year normalized comparison. These patterns should be interpreted cautiously because the dataset reflects both seizure activity and the reporting processes that generate the records.

Overall, this module is most useful for documenting data coverage, describing the subset of records with transportation information, and exploring temporal patterns in reported seizures—not for estimating actual trafficking methods, routes, or seasonality in drug markets.
