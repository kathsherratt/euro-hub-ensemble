# Author list
library(readr)
library(here)
library(dplyr)
library(stringr)
library(tidyr)
library(janitor)
library(googlesheets4)
library(tibble)

# Set up ---------------------------------------------------------
author_types <- ordered(c("first", "second",
                          "hub", "hub_support", "model",
                          "second_last", "last"))

if (!exists("load_from_local")) {
  load_from_local <- TRUE
}

#  Load -----------------------------------------------------------
if (load_from_local) {
  authors_raw <- read_csv(here("output", "metadata", "authorship_raw.csv"))
} else {
  gs4_deauth()
  authors_raw <- try(read_sheet("https://docs.google.com/spreadsheets/d/19hS7r7y126J3BPBhJa20rHApFu3Hx1DQEWe7av7fX68/edit#gid=1316950565",
                                sheet = "Authorship details"))
  readr::write_csv(authors_raw, here("output", "metadata", "authorship_raw.csv"))
}

authors <- authors_raw %>%
  clean_names() %>%
  mutate(
    # author format: "Surname, Initial."
    init_1 = substr(first_name, 1, 1),
    init_2 = substr(middle_name_s_initial_s, 1, 1),
    init_first = ifelse(!is.na(middle_name_s_initial_s),
                        paste0(init_1, init_2),
                        init_1),
    author_name = paste0(last_name, ", ", init_first, "."),
    # independent authors
    institution = ifelse(is.na(institution), "Independent", institution))

# Create author list for insertion into document
authors <- authors %>%
  mutate(type = ordered(type, levels = author_types)) %>%
  group_by(institution) %>%
  arrange(author_name, .by_group = TRUE) %>%
  arrange(type) %>%
  mutate(author_index = row_number()) %>%
  ungroup()

institutions <- authors %>%
  select(author_index, institution, city, country) %>%
  distinct(institution, city, country) %>%
  mutate(institution_index = row_number(),
         institution_name = paste0("^", institution_index, "^", institution),
         institution_city_country = paste(institution_name, city, country, sep = ", "))

authors <- left_join(authors, institutions, by = c("institution", "city", "country")) %>%
  mutate(author_inst = paste0(author_name, " ^", institution_index, "^"))

# Save --------------------------------------------------------------------
# List authors with subscript numbered institutions
author_text <- paste(authors$author_inst, collapse = ", ")
writeLines(author_text, con = here::here("output", "metadata",
                                         "authors.txt"))

# Separately list the institutions
institution_text <- paste(institutions$institution_city_country, collapse = ", ")
writeLines(institution_text,
           con = here::here("output", "metadata",
                            "institutions.txt"))


# create medrxiv csv ------------------------------------------------------
medrxiv <- authors %>%
  mutate(corresponding = ifelse(last_name == "Sherratt", TRUE, NA),
         "Suffix" = NA,
         "Home Page URL" = NA,
         "Collaborative Group/Consortium" = NA)

medrxiv_headers <- c("Email" = "email",
             "Institution" = "institution",
             "First Name" = "first_name",
             "Middle Name(s)/Initial(s)" = "middle_name_s_initial_s",
             "Last Name" = "last_name",
             "Suffix" = "Suffix",
             "Corresponding Author" = "corresponding",
             "Home Page URL" = "Home Page URL",
             "Collaborative Group/Consortium" = "Collaborative Group/Consortium",
             "ORCiD" = "or_ci_d")

medrxiv <- select(medrxiv, all_of(medrxiv_headers)) %>%
  mutate(across(.cols = everything(),
               ~ iconv(., from = "UTF-8", to = "ASCII//TRANSLIT")))

readr::write_tsv(medrxiv,
                 here::here("output", "metadata", "medrxiv-authorship.tsv"),
                 na = "")

# Table of authors by model ------------------------------------
# author_list_models <- authors %>%
#   select(author_name, institution, abbreviated_team_name, country)

# checks ------------------------------------------------------------------
# author_model <- read_sheet("https://docs.google.com/spreadsheets/d/19hS7r7y126J3BPBhJa20rHApFu3Hx1DQEWe7av7fX68/",
#                       sheet = "Authorship details") %>%
#   janitor::clean_names()
#
# authors_with_info <- author_model %>%
#   filter(type == "model") %>%
#   distinct(abbreviated_team_name) %>%
#   mutate(info = TRUE)
#
# source(here("code", "load", "ensemble-criteria.R"))
# models <- ensemble_criteria %>%
#   filter(!target_variable == "inc hosp" &
#            included_in_ensemble) %>%
#   group_by(model) %>%
#   tally() %>%
#   left_join(authors_with_info, by = c("model" = "abbreviated_team_name"))
#
#
# # get author names associated with models from metadata
# source(here("code", "load", "download_metadata.R"))
# metadata <- download_model_metadata()
#
# authors_metadata <- metadata %>%
#   select(model_abbr, model_contributors, team_model_designation) %>%
#   left_join(models, by = c("model_abbr" = "model")) %>%
#   filter(!is.na(n)) %>%
#   distinct(model_contributors, .keep_all = TRUE) %>%
#   arrange(desc(n)) %>%
#   arrange(info)
#
# write_csv(authors_metadata, here("model-authors.csv"))
#

# -------------------------------------------------------------------------

# # twitter handles
# twt <- select(metadata, twitter_handles)
#
#
# # authors email
# authors <- readr::read_tsv(here("output", "metadata", "medrxiv-authorship.tsv")) |>
#   filter(!is.na(Email)) |>
#   pull(Email)
#
# writeClipboard(paste(authors, collapse = "; "))
