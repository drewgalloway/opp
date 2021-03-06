source("common.R")


# VALIDATION: [GREEN] Almost no data before 2010. The New Orlean's
# "Bias-Free-Policing-annual-report-2015.pdf" has statistics on stops by
# subject race, and out percentages nearly perfectly match them; the
# discrepancy is likely due to what counts as a traffic/pedestrian stop;
# namely, we have some offenses here that aren't classified as either by the
# PD.
load_raw <- function(raw_data_dir, n_max) {
  d <- load_regex(raw_data_dir, "Stop", n_max)
  bundle_raw(d$data, d$loading_problems)
}


clean <- function(d, helpers) {

  tr_race <- c(
    tr_race,
    "amer. ind." = "other/unknown"
  )

  d$data %>%
    merge_rows(
      EventDate,
      BlockAddress,
      SubjectID
    ) %>%
    rename(
      district = District,
      zone = Zone,
      officer_assignment = OfficerAssignment,
      reason_for_stop = StopDescription,
      vehicle_year = VehicleYear,
      vehicle_make = VehicleMake,
      vehicle_model = VehicleModel,
      vehicle_color = VehicleColor,
      subject_age = SubjectAge,
      location = BlockAddress
    ) %>%
    mutate(
      actions = tolower(ActionsTaken),
      type = if_else(
        str_detect(reason_for_stop, "TRAFFIC|VEHICLE"),
        "vehicular",
        if_else(
          str_detect(reason_for_stop, "SUSPECT PERSON"),
          "pedestrian",
          NA_character_
        )
      ),
      datetime = parse_datetime(EventDate, "%m/%d/%Y %H:%M:%S %p"),
      date = as.Date(datetime),
      time = format(datetime, "%H:%M:%S"),
      warning_issued = str_detect(actions, "warning"),
      citation_issued = str_detect(actions, "citation"),
      arrest_made = str_detect(actions, "arrest"),
      outcome = first_of(
        arrest = arrest_made,
        citation = citation_issued,
        warning = warning_issued
      ),
      search_conducted = str_detect(actions, "search occurred: yes"),
      search_basis = first_of(
        "plain view" = str_detect(actions, "legal basises: plain"),
        "consent" = str_detect(
          actions,
          str_c(
            "consent form completed: yes",
            "consent given: yes",
            "consent to search: yes",
            sep = "|"
          )
        ),
        "other" = str_detect(actions, "warrant|incident|inventory|vehicle"),
        "probable cause" = search_conducted
      ),
      search_person = str_detect(actions, "driver|passenger|pedestrian"),
      search_vehicle = str_detect(actions, "vehicle"),
      frisk_performed = str_detect(actions, "pat down: yes|pat-down"),
      contraband_drugs = str_detect(actions, "evidence types: drugs"),
      contraband_weapons = str_detect(actions, "evidence types: weapon"),
      contraband_found = str_detect(actions, "evidence seized: yes"),
      subject_race = tr_race[tolower(SubjectRace)],
      subject_sex = tr_sex[SubjectGender],
      # NOTE: addresses are given sanitized, so we attempt to geocode them by
      # replacing XX with 00 to at least get block level geocodes
      latitude = if_else(Latitude == "0", NA_character_, Latitude),
      longitude = if_else(Longitude == "0", NA_character_, Longitude),
      tmp_location = str_replace(location, "XX", "00")
    ) %>%
    helpers$add_lat_lng(
    ) %>%
    standardize(d$metadata)
}
