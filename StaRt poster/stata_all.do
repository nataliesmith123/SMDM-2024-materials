set more off

/*****************************************************************************
SETUP 
*****************************************************************************/

* !!! IF YOU ARE RUNNING THIS, THIS IS THE ONLY THING YOU SHOULD HAVE TO CHANGE
* put the file path to the orchid0 parent folder in the quotes
global DIR "/Users/nas2623/Library/CloudStorage/OneDrive-HarvardUniversity/research/start-software"

clear

about

* check if lclogit is installed
capture which lclogit
if _rc ssc install lclogit

set seed 243521

global ATTRIBUTES_LIST maxOOP_1 maxOOP_2 maxOOP_3 premium_1 premium_2 planType_1 planType_2 network_1 network_2 drugDevice_1 drugDevice_2

* bring in data, already formatted/cleaned from R
use "$DIR/output/fromR_forStata.dta"

* CMSET DATA
cmset id choiceQuestion option
* panels are described by personId_numeric: "The variable panelvar identifies panels, which are typically IDs for individuals or decision makers."
* choiceSituation describes the 'time' variable here, which is not really time but rather the different choices people make, repeatedly: "The variable timevar identifies times within panels, points at which choices were made. Both panelvar and timevar must be numeric, and both must contain integers only."
* alternatives are defined by option, which has values opt1/opt2/opt3

cmtab, choice(choice_binary)

count
* should equal totalPop * 8 questions * 3 alternatives


/***************************************************************************** 
BASIC MULTINOMIAL 
*****************************************************************************/
cmclogit choice_binary $ATTRIBUTES_LIST, base(opt1)
	estimates store base

esttab base using "$DIR/output/stata_MNL.csv", b(3) se(3) wide nostar plain replace

	
/***************************************************************************** 
MIXED LOGIT 
*****************************************************************************/
/*
scalar t1 = c(current_time)

cmxtmixlogit choice_binary, random($ATTRIBUTES_LIST) base(opt1) intpoints(100) intmethod(halton)
	est store mixed
	
scalar t2 = c(current_time)
display (clock(t2, "hms") - clock(t1, "hms")) / 1000 " seconds"

esttab mixed using "$DIR/output/stata_MXL.csv", b(3) se(3) wide nostar plain replace
*/

* the model with all attributes modeled as random has issues converging, so just modeling one as a random parameter for now
cmxtmixlogit choice_binary maxOOP_2 maxOOP_3 premium_1 premium_2 planType_1 planType_2 network_1 network_2 drugDevice_1 drugDevice_2, random(maxOOP_1) base(opt1) intpoints(100) intmethod(halton)

/***************************************************************************** 
LCLOGIT RESULTS 
*****************************************************************************/


global MEMBERSHIP_VARS binaryVar

lclogit2 choice_binary, rand(optionNum_1 optionNum_3 $ATTRIBUTES_LIST) membership($MEMBERSHIP_VARS) id(id) nclasses(2) group(personChoiceId_numeric) seed(234)


* code for model selection
/*
matrix fitstats = J(5,3,.)
matrix colnames fitstats = class aic bic

foreach classNum of numlist 2/5{
	
	lclogit2 choice_binary, rand(optionNum_1 optionNum_3 $ATTRIBUTES_LIST) membership($MEMBERSHIP_VARS) id(personId_numeric) nclasses(`classNum') group(personChoiceId_numeric) seed(`classNum')

	matrix fitstats[`classNum'-1, 1] = `classNum'
	matrix fitstats[`classNum'-1, 2] = e(aic)
	matrix fitstats[`classNum'-1, 3] = e(bic)
	
} 

*/ 

* code to get for SE estimates if desired
* save lclogit2 estimates as 'start' to help the algorithm
/*
	lclogitml2 choice_binary, rand(optionNum_1 optionNum_3 $ATTRIBUTES_LIST) membership($MEMBERSHIP_VARS) id(id) nclasses(`class') group(personChoiceId_numeric) from(start) tolcheck seed(456)
		estimates store lca`class'_class_ml
		estimates save "$DIR/output/stata/lca`class'_class_ml", replace

	* posterior probabilities of class membership
	lclogitpr2 lca`class'_classAllocation_cp, cp

	