library(magrittr)
library(dplyr)

test <- read.csv("C:/Users/luish/Downloads/snomed/CONCEPT_ANCESTOR.csv", sep='\t')

runPlp_gerda <- readRDS("D:/git/transfer-learning/models-full-l1/GERDA_Full/plpResult/runPlp.rds")
runPlp_mdcr <- readRDS("D:/git/transfer-learning/models-full-l1/MDCR_Full/plpResult/runPlp.rds")
runPlp_opehr <- readRDS("D:/git/transfer-learning/models-full-l1/OPEHR_Full/plpResult/runPlp.rds")
runPlp_opses <- readRDS("D:/git/transfer-learning/models-full-l1/OPSES_Full/plpResult/runPlp.rds")
runPlp_ipci <- readRDS("D:/git/transfer-learning/models-full-l1/IPCI_Full/plpResult/runPlp.rds")

################################################################################

# ensure no concepts in set are invalid, this will give false as there is no ancestry available
full_set <- c(test$ancestor_concept_id, test$descendant_concept_id)
# indx <- which(!(set %in% full_set))
# set[indx]


set_gerda <- runPlp_gerda$covariateSummary %>%
  filter(!is.na(covariateValue) & covariateValue != 0.0) %>%
  filter(analysisId == 102) %>% # only from condition table
  filter(conceptId %in% full_set) %>% # concept is part of most recent hierarchy
  mutate(conceptId=as.integer(conceptId)) %>%
  select(conceptId) %>%
  unlist()

set_mdcr <- runPlp_mdcr$covariateSummary %>%
  filter(!is.na(covariateValue) & covariateValue != 0.0) %>%
  filter(analysisId == 102) %>% # only from condition table
  filter(conceptId %in% full_set) %>% # concept is part of most recent hierarchy
  mutate(conceptId=as.integer(conceptId)) %>%
  select(conceptId) %>%
  unlist()

set_opehr <- runPlp_opehr$covariateSummary %>%
  filter(!is.na(covariateValue) & covariateValue != 0.0) %>%
  filter(analysisId == 102) %>% # only from condition table
  filter(conceptId %in% full_set) %>% # concept is part of most recent hierarchy
  mutate(conceptId=as.integer(conceptId)) %>%
  select(conceptId) %>%
  unlist()

set_opses <- runPlp_opses$covariateSummary %>%
  filter(!is.na(covariateValue) & covariateValue != 0.0) %>%
  filter(analysisId == 102) %>% # only from condition table
  mutate(conceptId=as.integer(conceptId)) %>%
  filter(conceptId %in% full_set) %>% # concept is part of most recent hierarchy
  select(conceptId) %>%
  unlist()

set_ipci <- runPlp_ipci$covariateSummary %>%
  filter(!is.na(covariateValue) & covariateValue != 0.0) %>%
  filter(analysisId == 102) %>% # only from condition table
  filter(conceptId %in% full_set) %>% # concept is part of most recent hierarchy
  mutate(conceptId=as.integer(conceptId)) %>%
  select(conceptId) %>%
  unlist()

saveRDS(set_gerda, file.path("./data", "set_gerda.RDS"))
saveRDS(set_mdcr, file.path("./data", "set_mdcr.RDS"))
saveRDS(set_opehr, file.path("./data", "set_opehr.RDS"))
saveRDS(set_opses, file.path("./data", "set_opses.RDS"))
saveRDS(set_ipci, file.path("./data", "set_ipci.RDS"))

clinical_finding_concept_id <- 441840
set <- c(set_gerda, set_mdcr, set_opehr, set_opses, set_ipci, clinical_finding_concept_id)
set <- unique(set)

countIdentical <- function(a, b) {
  sum(pmin(
    table(a[a %in% intersect(a, b)]),
    table(b[b %in% intersect(a, b)])
  ))
}

countIdentical(set_gerda, set_ipci)
countIdentical(set_gerda, set_mdcr)
countIdentical(set_gerda, set_opehr)
countIdentical(set_gerda, set_opses)




################################################################################
`%notin%` <- Negate(`%in%`)

#######
# some testing here
output_internal <- test %>%
  filter(min_levels_of_separation != 0 & max_levels_of_separation != 0) %>% # remove the self-reference, we do not need it
  filter(descendant_concept_id %in% set)

set <- c(output_internal$ancestor_concept_id, output_internal$descendant_concept_id)
set <- unique(set)
######

# another ancestor exists within the set
output_internal <- test %>%
  filter(min_levels_of_separation != 0 & max_levels_of_separation != 0) %>% # remove the self-reference, we do not need it
  filter(descendant_concept_id %in% set) %>% # descendant is in our set
  filter(ancestor_concept_id %in% set) # and at the same time also the ancestor is in our set, btw, since we manually added clinical finding all will be selected, but we know which ones have clinical finding

# to_add_later <- output_internal %>%
#   filter(ancestor_concept_id == clinical_finding_concept_id)


# order and keep only the one with smallest level of separation
data_ordered <- output_internal[order(output_internal$min_levels_of_separation, output_internal$max_levels_of_separation, decreasing = FALSE), ]
data_output_internal <- data_ordered[!duplicated(data_ordered$descendant_concept_id), ]
# data_output_internal <- bind_rows(data_output_internal, to_add_later)
write.csv(data_output_internal, file="C:/Users/luish/Downloads/pars.csv", row.names=FALSE)


infer_ancestor <- data_output_internal %>%
  filter(ancestor_concept_id == clinical_finding_concept_id) %>%
  filter(min_levels_of_separation != 1 & max_levels_of_separation != 1) # some of the concepts may actually have clinical finding as 1-distance parent, so remove those for the next step 

i <- 1
for (i in 1:nrow(infer_ancestor)) {
  concept_id <- infer_ancestor$descendant_concept_id[i]
  output_infer <- test %>%
    filter(min_levels_of_separation != 0 & max_levels_of_separation != 0) %>%
    filter(descendant_concept_id == concept_id & ancestor_concept_id != clinical_finding_concept_id)
  
  output_infer_ordered <- output_infer[order(output_infer$min_levels_of_separation, output_infer$max_levels_of_separation, decreasing = FALSE), ]
  
  j <- 2

  for (j in 1:nrow(infer_ancestor)) {
    
    to_test <- infer_ancestor$descendant_concept_id[j]
    common_ancestor <- test %>%
      filter(min_levels_of_separation != 0 & max_levels_of_separation != 0) %>%
      filter(descendant_concept_id == to_test & ancestor_concept_id ==  output_infer_ordered$ancestor_concept_id[1])
    writeLines(paste0("iteration: ",j , ": ",common_ancestor$ancestor_concept_id))
  }
  
}

data_output_internal
write.csv(data_output_internal, file="~/Downloads/pars.csv", row.names=FALSE)


set2 <- c(set, 441840)

# no ancestor exists within the set
output_alone <- test %>%
  filter(min_levels_of_separation != 0 & max_levels_of_separation != 0) %>%
  filter(descendant_concept_id %in% set2) %>%
  filter(ancestor_concept_id %notin% set2)

data_ordered_alone <- output_alone[order(output_alone$min_levels_of_separation, output_alone$max_levels_of_separation, decreasing = FALSE), ]
data_output_alone <- data_ordered_alone[!duplicated(data_ordered_alone$descendant_concept_id), ]
data_output_alone <- output_alone
# output_alone2 <- test %>%
  

# data <- data.frame(ancestor_concept_id = numeric(), descendant_concept_id = numeric(),
#                    min_levels_of_separation = numeric(), max_levels_of_separation = numeric())


write.csv(data_output_internal, file="~/Downloads/pars.csv", row.names=FALSE)

ttt <- refOriginal %>%
  filter(concept_id %in% set)


# dist2 <- test %>%
#   filter(min_levels_of_separation == 1 & max_levels_of_separation == 1 |
#            min_levels_of_separation == 2 & max_levels_of_separation == 2) %>%
#   mutate(dist = min_levels_of_separation) %>%
#   select(ancestor_concept_id, descendant_concept_id, dist)
# write.csv(dist2, file="~/Desktop/dist2.csv", row.names=FALSE)
#
#
# dist3 <- test %>%
#   filter(min_levels_of_separation == 1 & max_levels_of_separation == 1 |
#            min_levels_of_separation == 2 & max_levels_of_separation == 2 |
#            min_levels_of_separation == 3 & max_levels_of_separation == 3) %>%
#   mutate(dist = min_levels_of_separation) %>%
#   select(ancestor_concept_id, descendant_concept_id, dist)
# write.csv(dist3, file="~/Desktop/dist3.csv", row.names=FALSE)
#
#
# dist4 <- test %>%
#   filter(min_levels_of_separation == 1 & max_levels_of_separation == 1 |
#            min_levels_of_separation == 2 & max_levels_of_separation == 2 |
#            min_levels_of_separation == 3 & max_levels_of_separation == 3 |
#            min_levels_of_separation == 4 & max_levels_of_separation == 4) %>%
#   mutate(dist = min_levels_of_separation) %>%
#   select(ancestor_concept_id, descendant_concept_id, dist)
# write.csv(dist4, file="~/Desktop/dist4.csv", row.names=FALSE)
#
#
# dist5 <- test %>%
#   filter(min_levels_of_separation == 1 & max_levels_of_separation == 1 |
#            min_levels_of_separation == 2 & max_levels_of_separation == 2 |
#            min_levels_of_separation == 3 & max_levels_of_separation == 3 |
#            min_levels_of_separation == 4 & max_levels_of_separation == 4 |
#            min_levels_of_separation == 5 & max_levels_of_separation == 5) %>%
#   mutate(dist = min_levels_of_separation) %>%
#   select(ancestor_concept_id, descendant_concept_id, dist)
# write.csv(dist5, file="~/Desktop/dist5.csv", row.names=FALSE)
#
#
# dist6 <- test %>%
#   filter(min_levels_of_separation == 1 & max_levels_of_separation == 1 |
#            min_levels_of_separation == 2 & max_levels_of_separation == 2 |
#            min_levels_of_separation == 3 & max_levels_of_separation == 3 |
#            min_levels_of_separation == 4 & max_levels_of_separation == 4 |
#            min_levels_of_separation == 5 & max_levels_of_separation == 5 |
#            min_levels_of_separation == 6 & max_levels_of_separation == 6) %>%
#   mutate(dist = min_levels_of_separation) %>%
#   select(ancestor_concept_id, descendant_concept_id, dist)
# write.csv(dist6, file="~/Desktop/dist6.csv", row.names=FALSE)


refOriginal = read.table("~/Downloads/vocab_v5/CONCEPT.csv", sep="\t", quote = "", fill = TRUE, header = TRUE)

ref <- refOriginal %>%
  select(concept_id, concept_name, concept_class_id, standard_concept) %>%
  filter(concept_class_id == "Clinical Finding")
write.csv(ref, file="~/Downloads/vocab_v5/ref.csv", row.names=FALSE)

nSample <- 100 # was 10
delta <- 1
depth <- 10

set.seed(1001)

##########
# temp1 <- dist1 %>%
#   filter(ancestor_concept_id == 316139) %>%
#   left_join(ref, by = c("descendant_concept_id" = "concept_id")) %>%
#   mutate(descendant_concept_name = concept_name) %>%
#   select(-c(concept_class_id, standard_concept, concept_name)) %>%
#   slice_sample(n = nSample)
#########

# Abdominal pain: 21522001
# Clinical finding: 441840
# Cardiovascular finding: 4023995

####   rename(id1 = descendant_concept_id, id2 = ancestor_concept_id)
temp1 <- dist1 %>%
  filter(id2 == 4023995) %>% # 4274025 This is disease, the super parent
  slice_sample(n = nSample)
man <- temp1

for (i in 1:depth) {
  temp2 <- dist1 %>%
    filter(id2 %in% temp1$id1) %>%
    slice_sample(n = nSample*delta)
    # slice_sample(n = nSample*i*delta)

  man <- bind_rows(man, temp2)
  temp1 <- temp2
}
################### same code as above, but no sampling
temp1 <- dist1 %>%
  filter(ancestor_concept_id == 316139)
man <- temp1

for (i in 1:100) {
  temp2 <- dist1 %>%
    filter(ancestor_concept_id %in% temp1$descendant_concept_id)
  # slice_sample(n = nSample*i*delta)

  man <- bind_rows(man, temp2)
  temp1 <- temp2
}

# # Some code to join references onto concept ids
# dist1Sample <- man %>%
#   left_join(ref, by = c("descendant_concept_id" = "concept_id")) %>%
#   mutate(descendant_concept_name = concept_name) %>%
#   select(-c(concept_class_id, standard_concept, concept_name))

dist1Sample <- man %>%
  select(c(id1, id2, weight))
  # rename(id1 = descendant_concept_id, id2 = ancestor_concept_id)

write.csv(dist1Sample, file="~/Desktop/dist1HeartDis.csv", row.names=FALSE, quote = FALSE)


##### LOAD DATA

options(arrow.int64_downcast = FALSE)
plpData <- PatientLevelPrediction::loadPlpData("D:/git/omop-poincare/data/ims_germany")
mappedData <- PatientLevelPrediction:::toSparseM(plpData)


