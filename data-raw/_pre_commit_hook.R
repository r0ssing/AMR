# ==================================================================== #
# TITLE:                                                               #
# AMR: An R Package for Working with Antimicrobial Resistance Data     #
#                                                                      #
# SOURCE CODE:                                                         #
# https://github.com/msberends/AMR                                     #
#                                                                      #
# PLEASE CITE THIS SOFTWARE AS:                                        #
# Berends MS, Luz CF, Friedrich AW, Sinha BNM, Albers CJ, Glasner C    #
# (2022). AMR: An R Package for Working with Antimicrobial Resistance  #
# Data. Journal of Statistical Software, 104(3), 1-31.                 #
# https://doi.org/10.18637/jss.v104.i03                                #
#                                                                      #
# Developed at the University of Groningen and the University Medical  #
# Center Groningen in The Netherlands, in collaboration with many      #
# colleagues from around the world, see our website.                   #
#                                                                      #
# This R package is free software; you can freely use and distribute   #
# it for both personal and commercial purposes under the terms of the  #
# GNU General Public License version 2.0 (GNU GPL-2), as published by  #
# the Free Software Foundation.                                        #
# We created this package for both routine data analysis and academic  #
# research and it was publicly released in the hope that it will be    #
# useful, but it comes WITHOUT ANY WARRANTY OR LIABILITY.              #
#                                                                      #
# Visit our website for the full manual and a complete tutorial about  #
# how to conduct AMR data analysis: https://msberends.github.io/AMR/   #
# ==================================================================== #

# Run this file to update the package using:
# source("data-raw/_pre_commit_hook.R")

library(dplyr, warn.conflicts = FALSE)
try(detach("package:data.table", unload = TRUE), silent = TRUE) # to prevent like() to precede over AMR::like
devtools::load_all(quiet = TRUE)

suppressMessages(set_AMR_locale("English"))

old_globalenv <- ls(envir = globalenv())

# Save internal data to R/sysdata.rda -------------------------------------

# See 'data-raw/eucast_rules.tsv' for the EUCAST reference file
EUCAST_RULES_DF <- utils::read.delim(
  file = "data-raw/eucast_rules.tsv",
  skip = 9,
  sep = "\t",
  stringsAsFactors = FALSE,
  header = TRUE,
  strip.white = TRUE,
  na = c(NA, "", NULL)
) %>%
  # take the order of the reference.rule_group column in the original data file
  mutate(
    reference.rule_group = factor(reference.rule_group,
      levels = unique(reference.rule_group),
      ordered = TRUE
    ),
    sorting_rule = ifelse(grepl("^Table", reference.rule, ignore.case = TRUE), 1, 2)
  ) %>%
  arrange(
    reference.rule_group,
    reference.version,
    sorting_rule,
    reference.rule
  ) %>%
  mutate(reference.rule_group = as.character(reference.rule_group)) %>%
  select(-sorting_rule)

TRANSLATIONS <- utils::read.delim(
  file = "data-raw/translations.tsv",
  sep = "\t",
  stringsAsFactors = FALSE,
  header = TRUE,
  blank.lines.skip = TRUE,
  fill = TRUE,
  strip.white = TRUE,
  encoding = "UTF-8",
  fileEncoding = "UTF-8",
  na.strings = c(NA, "", NULL),
  allowEscapes = TRUE, # else "\\1" will be imported as "\\\\1"
  quote = ""
)

LANGUAGES_SUPPORTED_NAMES <- c(
  list(en = list(exonym = "English", endonym = "English")),
  lapply(
    TRANSLATIONS[, which(nchar(colnames(TRANSLATIONS)) == 2), drop = FALSE],
    function(x) list(exonym = x[1], endonym = x[2])
  )
)

LANGUAGES_SUPPORTED <- names(LANGUAGES_SUPPORTED_NAMES)

# vectors of CoNS and CoPS, improves speed in as.mo()
create_species_cons_cops <- function(type = c("CoNS", "CoPS")) {
  # Determination of which staphylococcal species are CoNS/CoPS according to:
  # - Becker et al. 2014, PMID 25278577
  # - Becker et al. 2019, PMID 30872103
  # - Becker et al. 2020, PMID 32056452
  # this function returns class <mo>
  MO_staph <- AMR::microorganisms
  MO_staph <- MO_staph[which(MO_staph$genus == "Staphylococcus"), , drop = FALSE]
  if (type == "CoNS") {
    MO_staph[
      which(MO_staph$species %in% c(
        "coagulase-negative", "argensis", "arlettae",
        "auricularis", "borealis", "caeli", "capitis", "caprae",
        "carnosus", "casei", "caseolyticus", "chromogenes", "cohnii", "condimenti",
        "croceilyticus",
        "debuckii", "devriesei", "edaphicus", "epidermidis",
        "equorum", "felis", "fleurettii", "gallinarum",
        "haemolyticus", "hominis", "jettensis", "kloosii",
        "lentus", "lugdunensis", "massiliensis", "microti",
        "muscae", "nepalensis", "pasteuri", "petrasii",
        "pettenkoferi", "piscifermentans", "pragensis", "pseudoxylosus",
        "pulvereri", "rostri", "saccharolyticus", "saprophyticus",
        "sciuri", "simulans", "stepanovicii", "succinus",
        "ureilyticus",
        "vitulinus", "vitulus", "warneri", "xylosus",
        "caledonicus", "canis",
        "durrellii", "lloydii",
        "ratti", "taiwanensis", "veratri", "urealyticus"
      ) |
        # old, now renamed to S. schleiferi (but still as synonym in our data of course):
        (MO_staph$species == "schleiferi" & MO_staph$subspecies %in% c("schleiferi", ""))),
      "mo",
      drop = TRUE
    ]
  } else if (type == "CoPS") {
    MO_staph[
      which(MO_staph$species %in% c(
        "coagulase-positive", "coagulans",
        "agnetis", "argenteus",
        "cornubiensis",
        "delphini", "lutrae",
        "hyicus", "intermedius",
        "pseudintermedius", "pseudointermedius",
        "schweitzeri", "simiae",
        "roterodami",
        "singaporensis"
      ) |
        # old, now renamed to S. coagulans (but still as synonym in our data of course):
        (MO_staph$species == "schleiferi" & MO_staph$subspecies == "coagulans")),
      "mo",
      drop = TRUE
    ]
  }
}
MO_CONS <- create_species_cons_cops("CoNS")
MO_COPS <- create_species_cons_cops("CoPS")
MO_STREP_ABCG <- AMR::microorganisms$mo[which(AMR::microorganisms$genus == "Streptococcus" &
  tolower(AMR::microorganisms$species) %in% c(
    "pyogenes", "agalactiae", "dysgalactiae", "equi", "canis",
    "group a", "group b", "group c", "group g"
  ))]
MO_LANCEFIELD <- AMR::microorganisms$mo[which(AMR::microorganisms$mo %like% "^(B_STRPT_PYGN(_|$)|B_STRPT_AGLC(_|$)|B_STRPT_(DYSG|EQUI)(_|$)|B_STRPT_ANGN(_|$)|B_STRPT_(DYSG|CANS)(_|$)|B_STRPT_SNGN(_|$)|B_STRPT_SLVR(_|$))")]
MO_PREVALENT_GENERA <- c(
  "Absidia", "Acanthamoeba", "Acremonium", "Aedes", "Alternaria", "Amoeba", "Ancylostoma", "Angiostrongylus",
  "Anisakis", "Anopheles", "Apophysomyces", "Aspergillus", "Aureobasidium", "Basidiobolus", "Beauveria",
  "Blastocystis", "Blastomyces", "Candida", "Capillaria", "Chaetomium", "Chrysonilia", "Cladophialophora",
  "Cladosporium", "Conidiobolus", "Contracaecum", "Cordylobia", "Cryptococcus", "Curvularia", "Demodex",
  "Dermatobia", "Dientamoeba", "Diphyllobothrium", "Dirofilaria", "Echinostoma", "Entamoeba", "Enterobius",
  "Exophiala", "Exserohilum", "Fasciola", "Fonsecaea", "Fusarium", "Giardia", "Haloarcula", "Halobacterium",
  "Halococcus", "Hendersonula", "Heterophyes", "Histomonas", "Histoplasma", "Hymenolepis", "Hypomyces",
  "Hysterothylacium", "Leishmania", "Malassezia", "Malbranchea", "Metagonimus", "Meyerozyma", "Microsporidium",
  "Microsporum", "Mortierella", "Mucor", "Mycocentrospora", "Necator", "Nectria", "Ochroconis", "Oesophagostomum",
  "Oidiodendron", "Opisthorchis", "Pediculus", "Penicillium", "Phlebotomus", "Phoma", "Pichia", "Piedraia", "Pithomyces",
  "Pityrosporum", "Pneumocystis", "Pseudallescheria", "Pseudoterranova", "Pulex", "Rhizomucor", "Rhizopus",
  "Rhodotorula", "Saccharomyces", "Sarcoptes", "Scolecobasidium", "Scopulariopsis", "Scytalidium", "Spirometra",
  "Sporobolomyces", "Stachybotrys", "Strongyloides", "Syngamus", "Taenia", "Talaromyces", "Toxocara", "Trichinella",
  "Trichobilharzia", "Trichoderma", "Trichomonas", "Trichophyton", "Trichosporon", "Trichostrongylus", "Trichuris",
  "Tritirachium", "Trombicula", "Trypanosoma", "Tunga", "Wuchereria"
)

# antibiotic groups
# (these will also be used for eucast_rules() and understanding data-raw/eucast_rules.tsv)
globalenv_before_ab <- c(ls(envir = globalenv()), "globalenv_before_ab")
AB_AMINOGLYCOSIDES <- antibiotics %>%
  filter(group %like% "aminoglycoside") %>%
  pull(ab)
AB_AMINOPENICILLINS <- as.ab(c("AMP", "AMX"))
AB_ANTIFUNGALS <- AMR_env$AB_lookup %>%
  filter(group %like% "antifungal") %>%
  pull(ab)
AB_ANTIMYCOBACTERIALS <- AMR_env$AB_lookup %>%
  filter(group %like% "antimycobacterial") %>%
  pull(ab)
AB_CARBAPENEMS <- antibiotics %>%
  filter(group %like% "carbapenem") %>%
  pull(ab)
AB_CEPHALOSPORINS <- antibiotics %>%
  filter(group %like% "cephalosporin") %>%
  pull(ab)
AB_CEPHALOSPORINS_1ST <- antibiotics %>%
  filter(group %like% "cephalosporin.*1") %>%
  pull(ab)
AB_CEPHALOSPORINS_2ND <- antibiotics %>%
  filter(group %like% "cephalosporin.*2") %>%
  pull(ab)
AB_CEPHALOSPORINS_3RD <- antibiotics %>%
  filter(group %like% "cephalosporin.*3") %>%
  pull(ab)
AB_CEPHALOSPORINS_4TH <- antibiotics %>%
  filter(group %like% "cephalosporin.*4") %>%
  pull(ab)
AB_CEPHALOSPORINS_5TH <- antibiotics %>%
  filter(group %like% "cephalosporin.*5") %>%
  pull(ab)
AB_CEPHALOSPORINS_EXCEPT_CAZ <- AB_CEPHALOSPORINS[AB_CEPHALOSPORINS != "CAZ"]
AB_FLUOROQUINOLONES <- antibiotics %>%
  filter(atc_group2 %like% "fluoroquinolone" | (group %like% "quinolone" & is.na(atc_group2))) %>%
  pull(ab)
AB_GLYCOPEPTIDES <- antibiotics %>%
  filter(group %like% "glycopeptide") %>%
  pull(ab)
AB_LIPOGLYCOPEPTIDES <- as.ab(c("DAL", "ORI", "TLV")) # dalba/orita/tela
AB_GLYCOPEPTIDES_EXCEPT_LIPO <- AB_GLYCOPEPTIDES[!AB_GLYCOPEPTIDES %in% AB_LIPOGLYCOPEPTIDES]
AB_LINCOSAMIDES <- antibiotics %>%
  filter(atc_group2 %like% "lincosamide" | (group %like% "lincosamide" & is.na(atc_group2))) %>%
  pull(ab)
AB_MACROLIDES <- antibiotics %>%
  filter(atc_group2 %like% "macrolide" | (group %like% "macrolide" & is.na(atc_group2))) %>%
  pull(ab)
AB_OXAZOLIDINONES <- antibiotics %>%
  filter(group %like% "oxazolidinone") %>%
  pull(ab)
AB_PENICILLINS <- antibiotics %>%
  filter(group %like% "penicillin") %>%
  pull(ab)
AB_POLYMYXINS <- antibiotics %>%
  filter(group %like% "polymyxin") %>%
  pull(ab)
AB_QUINOLONES <- antibiotics %>%
  filter(group %like% "quinolone") %>%
  pull(ab)
AB_STREPTOGRAMINS <- antibiotics %>%
  filter(atc_group2 %like% "streptogramin") %>%
  pull(ab)
AB_TETRACYCLINES <- antibiotics %>%
  filter(group %like% "tetracycline") %>%
  pull(ab)
AB_TETRACYCLINES_EXCEPT_TGC <- AB_TETRACYCLINES[AB_TETRACYCLINES != "TGC"]
AB_TRIMETHOPRIMS <- antibiotics %>%
  filter(group %like% "trimethoprim") %>%
  pull(ab)
AB_UREIDOPENICILLINS <- as.ab(c("PIP", "TZP", "AZL", "MEZ"))
AB_BETALACTAMS <- c(AB_PENICILLINS, AB_CEPHALOSPORINS, AB_CARBAPENEMS)
# this will be used for documentation:
DEFINED_AB_GROUPS <- ls(envir = globalenv())
DEFINED_AB_GROUPS <- DEFINED_AB_GROUPS[!DEFINED_AB_GROUPS %in% globalenv_before_ab]
create_AB_AV_lookup <- function(df) {
  new_df <- df
  new_df$generalised_name <- generalise_antibiotic_name(new_df$name)
  new_df$generalised_synonyms <- lapply(new_df$synonyms, generalise_antibiotic_name)
  if ("abbreviations" %in% colnames(df)) {
    new_df$generalised_abbreviations <- lapply(new_df$abbreviations, generalise_antibiotic_name)
  }
  new_df$generalised_loinc <- lapply(new_df$loinc, generalise_antibiotic_name)
  new_df$generalised_all <- unname(lapply(
    as.list(as.data.frame(
      t(new_df[,
        c(
          colnames(new_df)[colnames(new_df) %in% c("ab", "av", "atc", "cid", "name")],
          colnames(new_df)[colnames(new_df) %like% "generalised"]
        ),
        drop = FALSE
      ]),
      stringsAsFactors = FALSE
    )),
    function(x) {
      x <- generalise_antibiotic_name(unname(unlist(x)))
      x[x != ""]
    }
  ))
  new_df[, colnames(new_df)[colnames(new_df) %like% "^generalised"]]
}
AB_LOOKUP <- create_AB_AV_lookup(AMR::antibiotics)
AV_LOOKUP <- create_AB_AV_lookup(AMR::antivirals)

# Export to package as internal data ----
usethis::ui_info(paste0("Updating internal package data"))
suppressMessages(usethis::use_data(EUCAST_RULES_DF,
  TRANSLATIONS,
  LANGUAGES_SUPPORTED_NAMES,
  LANGUAGES_SUPPORTED,
  MO_CONS,
  MO_COPS,
  MO_STREP_ABCG,
  MO_LANCEFIELD,
  MO_PREVALENT_GENERA,
  AB_LOOKUP,
  AV_LOOKUP,
  AB_AMINOGLYCOSIDES,
  AB_AMINOPENICILLINS,
  AB_ANTIFUNGALS,
  AB_ANTIMYCOBACTERIALS,
  AB_CARBAPENEMS,
  AB_CEPHALOSPORINS,
  AB_CEPHALOSPORINS_1ST,
  AB_CEPHALOSPORINS_2ND,
  AB_CEPHALOSPORINS_3RD,
  AB_CEPHALOSPORINS_4TH,
  AB_CEPHALOSPORINS_5TH,
  AB_CEPHALOSPORINS_EXCEPT_CAZ,
  AB_FLUOROQUINOLONES,
  AB_LIPOGLYCOPEPTIDES,
  AB_GLYCOPEPTIDES,
  AB_GLYCOPEPTIDES_EXCEPT_LIPO,
  AB_LINCOSAMIDES,
  AB_MACROLIDES,
  AB_OXAZOLIDINONES,
  AB_PENICILLINS,
  AB_POLYMYXINS,
  AB_QUINOLONES,
  AB_STREPTOGRAMINS,
  AB_TETRACYCLINES,
  AB_TETRACYCLINES_EXCEPT_TGC,
  AB_TRIMETHOPRIMS,
  AB_UREIDOPENICILLINS,
  AB_BETALACTAMS,
  DEFINED_AB_GROUPS,
  internal = TRUE,
  overwrite = TRUE,
  version = 2,
  compress = "xz"
))

# Export data sets to the repository in different formats -----------------

for (pkg in c("haven", "openxlsx", "arrow")) {
  if (!pkg %in% rownames(utils::installed.packages())) {
    message("NOTE: package '", pkg, "' not installed! Ignoring export where this package is required.")
  }
}
if ("digest" %in% rownames(utils::installed.packages())) {
  md5 <- function(object) digest::digest(object, "md5")
} else {
  # will write all files anyway, since MD5 hash cannot be determined
  md5 <- function(object) "unknown-md5-hash"
}

write_md5 <- function(object) {
  conn <- file(paste0("data-raw/", deparse(substitute(object)), ".md5"))
  writeLines(md5(object), conn)
  close(conn)
}
changed_md5 <- function(object) {
  tryCatch(
    {
      conn <- file(paste0("data-raw/", deparse(substitute(object)), ".md5"))
      compared <- md5(object) != readLines(con = conn)
      close(conn)
      compared
    },
    error = function(e) TRUE
  )
}

# give official names to ABs and MOs
clin_break <- clinical_breakpoints %>%
  mutate(mo_name = mo_name(mo, language = NULL, keep_synonyms = TRUE, info = FALSE), .after = mo) %>%
  mutate(ab_name = ab_name(ab, language = NULL), .after = ab)
if (changed_md5(clin_break)) {
  usethis::ui_info(paste0("Saving {usethis::ui_value('clinical_breakpoints')} to {usethis::ui_value('data-raw/')}"))
  write_md5(clin_break)
  try(saveRDS(clin_break, "data-raw/clinical_breakpoints.rds", version = 2, compress = "xz"), silent = TRUE)
  try(write.table(clinical_breakpoints, "data-raw/clinical_breakpoints.txt", sep = "\t", na = "", row.names = FALSE), silent = TRUE)
  try(haven::write_xpt(clin_break, "data-raw/clinical_breakpoints.xpt"), silent = TRUE)
  try(haven::write_sav(clin_break, "data-raw/clinical_breakpoints.sav"), silent = TRUE)
  try(haven::write_dta(clin_break, "data-raw/clinical_breakpoints.dta"), silent = TRUE)
  try(openxlsx::write.xlsx(clin_break, "data-raw/clinical_breakpoints.xlsx"), silent = TRUE)
  try(arrow::write_feather(clin_break, "data-raw/clinical_breakpoints.feather"), silent = TRUE)
  try(arrow::write_parquet(clin_break, "data-raw/clinical_breakpoints.parquet"), silent = TRUE)
}

if (changed_md5(microorganisms)) {
  usethis::ui_info(paste0("Saving {usethis::ui_value('microorganisms')} to {usethis::ui_value('data-raw/')}"))
  write_md5(microorganisms)
  try(saveRDS(microorganisms, "data-raw/microorganisms.rds", version = 2, compress = "xz"), silent = TRUE)
  max_50_snomed <- sapply(microorganisms$snomed, function(x) paste(x[seq_len(min(50, length(x), na.rm = TRUE))], collapse = " "))
  mo <- microorganisms
  mo$snomed <- max_50_snomed
  mo <- dplyr::mutate_if(mo, ~ !is.numeric(.), as.character)
  try(haven::write_xpt(mo, "data-raw/microorganisms.xpt"), silent = TRUE)
  try(haven::write_sav(mo, "data-raw/microorganisms.sav"), silent = TRUE)
  try(haven::write_dta(mo, "data-raw/microorganisms.dta"), silent = TRUE)
  mo_all_snomed <- microorganisms %>% mutate_if(is.list, function(x) sapply(x, paste, collapse = ","))
  try(write.table(mo_all_snomed, "data-raw/microorganisms.txt", sep = "\t", na = "", row.names = FALSE), silent = TRUE)
  try(openxlsx::write.xlsx(mo_all_snomed, "data-raw/microorganisms.xlsx"), silent = TRUE)
  try(arrow::write_feather(microorganisms, "data-raw/microorganisms.feather"), silent = TRUE)
  try(arrow::write_parquet(microorganisms, "data-raw/microorganisms.parquet"), silent = TRUE)
}

if (changed_md5(microorganisms.codes)) {
  usethis::ui_info(paste0("Saving {usethis::ui_value('microorganisms.codes')} to {usethis::ui_value('data-raw/')}"))
  write_md5(microorganisms.codes)
  try(saveRDS(microorganisms.codes, "data-raw/microorganisms.codes.rds", version = 2, compress = "xz"), silent = TRUE)
  try(write.table(microorganisms.codes, "data-raw/microorganisms.codes.txt", sep = "\t", na = "", row.names = FALSE), silent = TRUE)
  try(haven::write_xpt(microorganisms.codes, "data-raw/microorganisms.codes.xpt"), silent = TRUE)
  try(haven::write_sav(microorganisms.codes, "data-raw/microorganisms.codes.sav"), silent = TRUE)
  try(haven::write_dta(microorganisms.codes, "data-raw/microorganisms.codes.dta"), silent = TRUE)
  try(openxlsx::write.xlsx(microorganisms.codes, "data-raw/microorganisms.codes.xlsx"), silent = TRUE)
  try(arrow::write_feather(microorganisms.codes, "data-raw/microorganisms.codes.feather"), silent = TRUE)
  try(arrow::write_parquet(microorganisms.codes, "data-raw/microorganisms.codes.parquet"), silent = TRUE)
}

if (changed_md5(microorganisms.groups)) {
  usethis::ui_info(paste0("Saving {usethis::ui_value('microorganisms.groups')} to {usethis::ui_value('data-raw/')}"))
  write_md5(microorganisms.groups)
  try(saveRDS(microorganisms.groups, "data-raw/microorganisms.groups.rds", version = 2, compress = "xz"), silent = TRUE)
  try(write.table(microorganisms.groups, "data-raw/microorganisms.groups.txt", sep = "\t", na = "", row.names = FALSE), silent = TRUE)
  try(haven::write_xpt(microorganisms.groups, "data-raw/microorganisms.groups.xpt"), silent = TRUE)
  try(haven::write_sav(microorganisms.groups, "data-raw/microorganisms.groups.sav"), silent = TRUE)
  try(haven::write_dta(microorganisms.groups, "data-raw/microorganisms.groups.dta"), silent = TRUE)
  try(openxlsx::write.xlsx(microorganisms.groups, "data-raw/microorganisms.groups.xlsx"), silent = TRUE)
  try(arrow::write_feather(microorganisms.groups, "data-raw/microorganisms.groups.feather"), silent = TRUE)
  try(arrow::write_parquet(microorganisms.groups, "data-raw/microorganisms.groups.parquet"), silent = TRUE)
}

ab <- dplyr::mutate_if(antibiotics, ~ !is.numeric(.), as.character)
if (changed_md5(ab)) {
  usethis::ui_info(paste0("Saving {usethis::ui_value('antibiotics')} to {usethis::ui_value('data-raw/')}"))
  write_md5(ab)
  try(saveRDS(antibiotics, "data-raw/antibiotics.rds", version = 2, compress = "xz"), silent = TRUE)
  try(haven::write_xpt(ab, "data-raw/antibiotics.xpt"), silent = TRUE)
  try(haven::write_sav(ab, "data-raw/antibiotics.sav"), silent = TRUE)
  try(haven::write_dta(ab, "data-raw/antibiotics.dta"), silent = TRUE)
  ab_lists <- antibiotics %>% mutate_if(is.list, function(x) sapply(x, paste, collapse = ","))
  try(write.table(ab_lists, "data-raw/antibiotics.txt", sep = "\t", na = "", row.names = FALSE), silent = TRUE)
  try(openxlsx::write.xlsx(ab_lists, "data-raw/antibiotics.xlsx"), silent = TRUE)
  try(arrow::write_feather(antibiotics, "data-raw/antibiotics.feather"), silent = TRUE)
  try(arrow::write_parquet(antibiotics, "data-raw/antibiotics.parquet"), silent = TRUE)
}

av <- dplyr::mutate_if(antivirals, ~ !is.numeric(.), as.character)
if (changed_md5(av)) {
  usethis::ui_info(paste0("Saving {usethis::ui_value('antivirals')} to {usethis::ui_value('data-raw/')}"))
  write_md5(av)
  try(saveRDS(antivirals, "data-raw/antivirals.rds", version = 2, compress = "xz"), silent = TRUE)
  try(haven::write_xpt(av, "data-raw/antivirals.xpt"), silent = TRUE)
  try(haven::write_sav(av, "data-raw/antivirals.sav"), silent = TRUE)
  try(haven::write_dta(av, "data-raw/antivirals.dta"), silent = TRUE)
  av_lists <- antivirals %>% mutate_if(is.list, function(x) sapply(x, paste, collapse = ","))
  try(write.table(av_lists, "data-raw/antivirals.txt", sep = "\t", na = "", row.names = FALSE), silent = TRUE)
  try(openxlsx::write.xlsx(av_lists, "data-raw/antivirals.xlsx"), silent = TRUE)
  try(arrow::write_feather(antivirals, "data-raw/antivirals.feather"), silent = TRUE)
  try(arrow::write_parquet(antivirals, "data-raw/antivirals.parquet"), silent = TRUE)
}

# give official names to ABs and MOs
intrinsicR <- data.frame(
  microorganism = mo_name(intrinsic_resistant$mo, language = NULL, keep_synonyms = TRUE, info = FALSE),
  antibiotic = ab_name(intrinsic_resistant$ab, language = NULL),
  stringsAsFactors = FALSE
)
if (changed_md5(intrinsicR)) {
  usethis::ui_info(paste0("Saving {usethis::ui_value('intrinsic_resistant')} to {usethis::ui_value('data-raw/')}"))
  write_md5(intrinsicR)
  try(saveRDS(intrinsicR, "data-raw/intrinsic_resistant.rds", version = 2, compress = "xz"), silent = TRUE)
  try(write.table(intrinsicR, "data-raw/intrinsic_resistant.txt", sep = "\t", na = "", row.names = FALSE), silent = TRUE)
  try(haven::write_xpt(intrinsicR, "data-raw/intrinsic_resistant.xpt"), silent = TRUE)
  try(haven::write_sav(intrinsicR, "data-raw/intrinsic_resistant.sav"), silent = TRUE)
  try(haven::write_dta(intrinsicR, "data-raw/intrinsic_resistant.dta"), silent = TRUE)
  try(openxlsx::write.xlsx(intrinsicR, "data-raw/intrinsic_resistant.xlsx"), silent = TRUE)
  try(arrow::write_feather(intrinsicR, "data-raw/intrinsic_resistant.feather"), silent = TRUE)
  try(arrow::write_parquet(intrinsicR, "data-raw/intrinsic_resistant.parquet"), silent = TRUE)
}

if (changed_md5(dosage)) {
  usethis::ui_info(paste0("Saving {usethis::ui_value('dosage')} to {usethis::ui_value('data-raw/')}"))
  write_md5(dosage)
  try(saveRDS(dosage, "data-raw/dosage.rds", version = 2, compress = "xz"), silent = TRUE)
  try(write.table(dosage, "data-raw/dosage.txt", sep = "\t", na = "", row.names = FALSE), silent = TRUE)
  try(haven::write_xpt(dosage, "data-raw/dosage.xpt"), silent = TRUE)
  try(haven::write_sav(dosage, "data-raw/dosage.sav"), silent = TRUE)
  try(haven::write_dta(dosage, "data-raw/dosage.dta"), silent = TRUE)
  try(openxlsx::write.xlsx(dosage, "data-raw/dosage.xlsx"), silent = TRUE)
  try(arrow::write_feather(dosage, "data-raw/dosage.feather"), silent = TRUE)
  try(arrow::write_parquet(dosage, "data-raw/dosage.parquet"), silent = TRUE)
}

suppressMessages(reset_AMR_locale())

# remove leftovers from global env
current_globalenv <- ls(envir = globalenv())
rm(list = current_globalenv[!current_globalenv %in% old_globalenv])
rm(current_globalenv)

devtools::load_all(quiet = TRUE)
suppressMessages(set_AMR_locale("English"))

# Update URLs -------------------------------------------------------------
usethis::ui_info("Checking URLs for redirects")
invisible(capture.output(urlchecker::url_update()))


# Document pkg ------------------------------------------------------------
usethis::ui_info("Documenting package")
suppressMessages(devtools::document(quiet = TRUE))


# Style pkg ---------------------------------------------------------------
if (!"styler" %in% rownames(utils::installed.packages())) {
  message("Package 'styler' not installed!")
} else if (interactive()) {
  # only when sourcing this file ourselves
  # usethis::ui_info("Styling package")
  # styler::style_pkg(
  #   style = styler::tidyverse_style,
  #   filetype = c("R", "Rmd")
  # )
}


# Finished ----------------------------------------------------------------
usethis::ui_done("All done")
suppressMessages(reset_AMR_locale())
