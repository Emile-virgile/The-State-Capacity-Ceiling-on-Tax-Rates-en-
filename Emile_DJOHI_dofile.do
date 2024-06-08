version 15
clear all
set more off
cap log close
drop _all
macro drop _all

/* 
List od users
Emile 1 
user 2 
NB: You will be representing the user 2. Add your path to the empty working 
space and then run
*/



global user 1

if $user == 1 {
    global workdir "C:\Users\Probook\Dropbox\PC\Desktop\Emile_DJOHI_data_test"
}

if $user == 2 {
    global workdir "..."
}

cap mkdir "$workdir"  // Create the main folder   
cd "$workdir"  // Set the working directory

foreach x in docs dos data graphs output {
    cap mkdir $`x' // Create subfolders
}


log using the_log, replace // Create the log file


*1. Import the combined_data.dta dataset into Stata.

use "$workdir\data\combined_data.dta", clear // Importing the data combined_data.dta

/******************************************************************************
* Step 2: List and drop duplicates and drop incomplete surveys
******************************************************************************/


/* The Bergeron et.al paper uses households as units of study, we will then assume the same and consider the compound as unit of study. The compound_code variable should then be an id. We check the duplicates according to it. */

duplicates report compound_code
duplicates list compound_code

* We can notice 3 compound_code that are repeated twice each. We will then remove them
duplicates drop compound_code, force

* We drop incomplete surveys

codebook survey_complete
* It remains one incompleted survey that we will remove.
drop if survey_complete !=1



/******************************************************************************
* Step 3: Merge with nearest_property dataset
******************************************************************************/

save "$workdir\data\nodupl_combined_data.dta", replace
/*We first check and drop duplicates information from ou coumpound_code variable
We need that variable to be an id and then we can use it to merge the two data
After that we save the modifications*/

import delimited "$workdir\data\nearest_property.csv", clear
save nearest_property.dta, replace
/*We now import the second data nearest_property which is an csv data and then 
check if compound_code is can also be used as an id variable. And we found that 
the variable compound variable is an id variable, then no duplicate informations
We finaly save the modification*/

use "$workdir\data\nodupl_combined_data.dta", clear
merge 1:1 compound_code using "$workdir\nearest_property.dta" 
keep if _merge == 1 | _merge == 3

save "$workdir\data\merge_data.dta", replace
/*We now import again the master data nodupl_combined_data and then merge with
the using data nearest_property which now is a stata data. And we keep 
observation that merge perfectly (merge == 3) and those observation remaining 
in the master data that do not have a match in the using data (merge == 1)*/



 * or


/*import delimited "$workdir\data\nearest_property.csv", clear
merge 1:1 compound_code using "$workdir\data\nodupl_combined_data.dta"
keep if _merge == 3 | _merge == 2
*/




/******************************************************************************
* Step 4: Impute missing values of number of visits post carto using polygon average
******************************************************************************/

bysort a7: egen nb_visit_pcarto_mean = mean(nb_visit_post_carto) // I create a variable, that equals the mean of nb_visit_post_carto for each polygon a7
replace nb_visit_post_carto = nb_visit_pcarto_mean if missing(nb_visit_post_carto) // I impute the missing values of nb_visit_post_carto with values of the variable we created
drop nb_visit_pcarto_mean // I drop it

/******************************************************************************
* Step 5: Generate log version of the variable "rate"
******************************************************************************/

gen rate_numeric = real(rate)
gen log_rate = log(rate_numeric)

/******************************************************************************
* Step 6: Generate dummy variables for percentage of tax rate to be paid
******************************************************************************/

tabulate reduction_pct, generate(pct_)
rename (pct_1 pct_2 pct_3 pct_4) (pct_100 pct_83 pct_67 pct_50) // I rename the variables as it is required

* And I change the labels
label variable pct_100 "0% Reduction"
label variable pct_83 "17% Reduction"
label variable pct_67 "33% Reduction"
label variable pct_50 "50% Reduction" 



/******************************************************************************
* Step 7: For the subset of those that paid taxes, by tax reduction percentages,
*         plot (separately) the day of tax payment and then combine all four graphs
*         into one publication-suitable and well-formatted graph.
*         Label axes and give graph titles indicating percentage reductions on
*         each subgraph and a title for the combined graph.
******************************************************************************/

// 7 - Plot the taxes pay days
* I first create a variable that will take the value of the lowest day where a given individual paid according to the database
gen tax_pay_day = .
forvalues i = 0/30{
	replace tax_pay_day = `i' if taxes_paid_`i'd == 1 & missing(tax_pay_day)
}

* Now, I plot the required graphs (I opt for a histogram)
hist tax_pay_day if taxes_paid == 1 & pct_50 == 1, discrete freq name(perc_50) xtitle("Days") title("50% Reduction")
hist tax_pay_day if taxes_paid == 1 & pct_67 == 1, discrete freq name(perc_67) xtitle("Days") title("33% Reduction")
hist tax_pay_day if taxes_paid == 1 & pct_83 == 1, discrete freq name(perc_83) xtitle("Days") title("17% Reduction")
hist tax_pay_day if taxes_paid == 1 & pct_100 == 1, discrete freq name(perc_100) xtitle("Days") title("0% Reduction")
graph combine perc_50 perc_67 perc_83 perc_100, scale(.75) name(tax_pay_days) title("Days (of the 30 days) on which taxes were paid")


/******************************************************************************
* Step 8: Calculate average taxes paid amount for polygons with over 5% compounds paid taxes
******************************************************************************/

* Let's first create a variable that captures the percentage of compound who paid taxes in a polygon
egen total_paid = total(taxes_paid), by(a7) // number of people that paid taxes in a given polygon
egen total_people = count(a7), by (a7) // number of people in a polygon
gen perc_paid = total_paid/total_people // proportion of people who pays in a polygon

estpost  summarize taxes_paid_amt if perc_paid > .05
esttab ., cells("mean(fmt(a5))")


/******************************************************************************
* Step 9: Produce a balance table by treatment group
******************************************************************************/
// 9 - Balance table by treatment group over a few vars
* Property characteristics variables like elect1 fence walls roof are categorical, let's generate dummies for each of the values they take and adequately label these dummies
tab elect1, gen(elect__)
label variable elect__1 "Property does not have electricity"
label variable elect__2 "Property have electricity"

tab fence, gen(fence__)
label variable fence__1 "Property with no walls"
label variable fence__2 "Property with Bamboo walls"
label variable fence__3 "Property with Brick walls"
label variable fence__4 "Property with Ciment walls"

tab walls, gen(walls__)
label variable walls__1 "Walls in Stick/Palm"
label variable walls__2 "Walls in Mud brick"
label variable walls__3 "Walls in Brick - bad conditions"
label variable walls__4 "Walls in Ciment"

tab roof, gen(roof__)
label variable roof__1 "Roof in tchatch/straw"
label variable roof__2 "Roof in palms/bamboos"
label variable roof__3 "Roof in logs (pieces)"
label variable roof__4 "Roof in concrete slab"
label variable roof__5 "Roof in tiles (for roof)/slate/eternit"
label variable roof__6 "Roof in sheet iron"

global prop_char dist_city_center dist_commune_buildings dist_gas_stations dist_health_centers dist_hospitals dist_markets dist_police_stations dist_private_schools dist_public_schools dist_state_buildings dist_universities dist_roads dist_ravin inc_mo elect__* fence__* walls__* roof__* // property characteristics variables

* adequately label the variables fro property characteristics
label variable dist_city_center "Distance to the city center"
label variable dist_commune_buildings "Distance to the commune buildings"
label variable dist_gas_stations "Distance to gas stations"
label variable dist_health_centers "Distance to health centers"
label variable dist_hospitals"Distance to hospitals"
label variable dist_markets"Distance to markets"
label variable dist_police_stations"Distance to police stations"
label variable dist_private_schools"Distance to private schools"
label variable dist_public_schools"Distance to public schools"
label variable dist_state_buildings"Distance to state buildings"
label variable dist_universities"Distance to universities"
label variable dist_roads"Distance to roads"
label variable dist_ravin"Distance to the erosion"
label variable inc_mo "Household total earnings past month"

* I also do the same for the owner categorical characteristics (sex dummies)
tab sex_prop, gen(sex_prop__)
label variable sex_prop__1 "Female owner"
label variable sex_prop__2 "Male owner"

global own_char sex_prop__* age_prop // property owner characteristics

label variable age_prop "Age of the owner"

* There are lots of missing values for all of the aformentionned variable.
* Let's output the balance table. 
* The treatment is tax reduction and we have 3 different reductions (.17 .33 .50) and 0 that will be the control group. Such groups are identified by the variable reduction_pct

//ssc install ietoolkit
iebaltab $prop_char $own_char, groupvar(reduction_pct) control(0) rowv savecsv(".\output\balance table.csv") replace

* The table is produced using a student test of means between groups identified by reduction_pct

* From the table we get, we can be tempted to say that all the treatment groups are similar to the control group. Because the majority of coefficients in the table are non significant. In other words, there is no significant different between the means (proportions for the categorical) of all the characteristics variable we choose across the treatment groups and the control group.

/******************************************************************************
* Step 10: Regress compound visited post carto on tax reductions
******************************************************************************/
// 10 - Regressions
eststo clear
eststo visit : reg visit_post_carto pct_83 pct_67 pct_50
eststo bon_cons : reg visit_post_carto pct_83 pct_67 pct_50 if bonus_constant == 1
eststo bon_prop : reg visit_post_carto pct_83 pct_67 pct_50 if bonus_prop == 1

esttab visit bon_cons bon_prop using ".\output\reg_visit", mtitles(all bonus_constant_cons bonus_prop) replace csv nonumb label title("Regression of visit dummy") b(4)


/******************************************************************************
* Step 11: Repeat regression with polygon fixed effects and correct standard errors
******************************************************************************/
eststo clear
eststo visit : reg visit_post_carto pct_83 pct_67 pct_50 i.a7, vce(cluster a7)
eststo bon_cons : reg visit_post_carto pct_83 pct_67 pct_50 i.a7 if bonus_constant == 1, vce(cluster a7)
eststo bon_prop : reg visit_post_carto pct_83 pct_67 pct_50 i.a7 if bonus_prop == 1, vce(cluster a7)

esttab visit bon_cons bon_prop using ".\output\reg_visit_fixed", mtitles(all bonus_constant_cons bonus_prop) replace csv nonumb label title("Regression of visit dummy with polygon fixed effect and clustered standard errors") b(4) drop(*.a7)


/******************************************************************************
* Step 12: Regress taxes paid on tax reductions including controls
******************************************************************************/

eststo clear
eststo visit : reg taxes_paid pct_83 pct_67 pct_50 i.visited visits
eststo bon_cons : reg taxes_paid pct_83 pct_67 pct_50 i.visited visits if bonus_constant == 1
eststo bon_prop : reg taxes_paid pct_83 pct_67 pct_50 i.visited visits if bonus_prop == 1

esttab visit bon_cons bon_prop using ".\output\reg_paid", mtitles(all bonus_constant_cons bonus_prop) replace csv nonumb label title("Regression of taxes payment dummy with controls") b(4)


/******************************************************************************
* Step 13: Repeat regression using log version of taxes paid as dependent variable
******************************************************************************/

gen log_tax_paid_amt = log(taxes_paid_amt)

eststo clear
eststo visit : reg log_tax_paid_amt pct_83 pct_67 pct_50 i.visited visits
eststo bon_cons : reg log_tax_paid_amt pct_83 pct_67 pct_50 i.visited visits if bonus_constant == 1
eststo bon_prop : reg log_tax_paid_amt pct_83 pct_67 pct_50 i.visited visits if bonus_prop == 1

esttab visit bon_cons bon_prop using ".\output\reg_log_paid", mtitles(all bonus_constant_cons bonus_prop) replace csv nonumb label title("Regression of log of taxes amount paid with controls") b(4)



/* Exercice 2
1.
Dans cette situation, il semble y avoir un problème potentiel de contamination 
des groupes (treatment et control) dans le quartier de Tshinsambi. 
La contamination se produit lorsque les participants ou les ménages du groupe 
contrôle sont exposés à l'intervention, ce qui peut fausser les résultats de 
l'étude.

Dans ce cas, puisque la collecte de données Baseline dans le quartier de 
Tshinsambi prend plus de temps que prévu, les enquêteurs ont déjà informé 
certains ménages de leur groupe d'intervention (traitement ou contrôle) avant 
que tous les ménages n'aient été sondés. Cela signifie que certains ménages du 
quartier pourraient être informés de leur groupe d'intervention avant la 
randomisation complète des groupes.

Cela pourrait potentiellement biaiser les résultats de l'étude, car les ménages
 qui ont été informés de leur groupe d'intervention pourraient agir différemment
 ou être influencés par cette information, même s'ils ne sont pas censés 
 connaître leur statut d'intervention avant la randomisation.

Pour atténuer ce problème, il est important de veiller à ce que la randomisation
 des groupes soit effectuée avant que les enquêteurs ne révèlent à quiconque son
 groupe d'intervention. Si la randomisation a déjà été effectuée dans d'autres 
 quartiers, il pourrait être nécessaire de re-randomiser les ménages du quartier
 de Tshinsambi pour garantir l'intégrité de l'étude. De plus, il est essentiel 
 de documenter toute contamination potentielle et d'analyser ses effets sur les
 résultats de l'étude.*/
 
 
 /* 2.
Dans cette situation, plusieurs options peuvent être envisagées pour résoudre 
le problème de traduction manquante dans le sondage Baseline :
Traduction immédiate : Si vous disposez des compétences linguistiques 
nécessaires ou si vous avez accès à une ressource qui peut traduire rapidement
 la question manquante en français, vous pouvez effectuer la traduction 
 vous-même ou faire appel à un traducteur pour le faire immédiatement.

Reporter le déploiement : Si le déploiement du sondage Baseline peut être 
retardé sans compromettre le calendrier global du projet, vous pouvez 
contacter les PIs pour leur signaler le problème et leur demander de 
reprogrammer le déploiement une fois que la question aura été correctement 
traduite en français.

Utiliser une traduction temporaire : Si vous devez procéder au déploiement
 du sondage Baseline dès le lendemain et qu'une traduction professionnelle
 ne peut pas être obtenue à temps, vous pouvez envisager de fournir une
 traduction temporaire ou une paraphrase de la question manquante en français.
 Cela peut permettre de continuer le déploiement tout en informant les 
 répondants de la question à venir.

Prévenir les répondants : Si vous optez pour la traduction temporaire ou si 
vous ne pouvez pas obtenir une traduction avant le déploiement, assurez-vous 
d'informer les répondants de la situation. Vous pouvez leur expliquer que la 
question spécifique sera traduite ultérieurement mais qu'ils doivent répondre
 aux autres questions en attendant.

Quelle que soit l'option choisie, il est important de communiquer efficacement
 avec les PIs et les répondants pour garantir la qualité des données recueillies
 et maintenir la crédibilité de l'étude.*/
