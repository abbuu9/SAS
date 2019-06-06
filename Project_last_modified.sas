libname qq "H:\test1\Project";

DATA DRUG_STORE;
INFILE "H:\test1\Project\hhclean_drug_1114_1165" DLM=" " FIRSTOBS=2;
INPUT IRI_KEY WEEK SY GE VEND ITEM UNITS DOLLARS F$ D PR;
RUN;

DATA GROCERY_STORE;
INFILE "H:\test1\Project\hhclean_groc_1114_1165" DLM=" " FIRSTOBS=2;
INPUT IRI_KEY WEEK SY GE VEND ITEM UNITS DOLLARS F$ D PR;
RUN;

/*DATA qq.PRODUCT;
SET PRODUCT;
RUN;*/

data GROCERY_STORE1;
SET GROCERY_STORE;
 SY_p=put(SY,z2.);
 format SY z2.;
 GE_p=put(GE,z2.);
 format GE z2.;
 VEND_p=put(VEND,z5.);
 format VEND z5.;
 ITEM_p=put(ITEM,z5.);
 format ITEM z5.;
 UPC = catx('-',SY_p ,GE_p,VEND_p ,ITEM_p);
run;

DATA PRODUCT1;
SET PRODUCT;
VENDOR_ITEM = catt(strip(VEND), strip(ITEM));
RUN;

PROC SQL;
 CREATE TABLE GROC_PROD_JOIN AS
 SELECT *
 FROM GROCERY_STORE1 A LEFT JOIN PRODUCT1 B
 ON (A.UPC = B.UPC);
QUIT;
/*data qq.groc_prod_join;
set GROC_PROD_JOIN;
run;*/

/*Drug data*/

data DRUG_STORE1;
SET DRUG_STORE;
 SY_p=put(SY,z2.);
 format SY z2.;
 GE_p=put(GE,z2.);
 format GE z2.;
 VEND_p=put(VEND,z5.);
 format VEND z5.;
 ITEM_p=put(ITEM,z5.);
 format ITEM z5.;
 UPC = catx('-',SY_p ,GE_p,VEND_p ,ITEM_p);
RUN;

PROC SQL;
 CREATE TABLE DRUG_PROD_JOIN AS
 SELECT *
 FROM DRUG_STORE1 A LEFT JOIN PRODUCT1 B
 ON (A.UPC = B.UPC);
QUIT;
/*data qq.DRUG_PROD_JOIN;
set DRUG_PROD_JOIN;
run;*/

/*Drug Stores - Market share
Market share = Dollars/Total Dollars for each brand*/
PROC SQL;
	CREATE TABLE  X AS
	SELECT L4,sum(DOLLARS) as TOTAL_DOLLARS
	FROM DRUG_PROD_JOIN
	GROUP BY L4;

	CREATE TABLE MARKET_SHARE AS
	SELECT L4,TOTAL_DOLLARS/SUM(TOTAL_DOLLARS) as market_share
	FROM X
	ORDER BY market_share DESC;
QUIT;

DATA DRUG;
SET DRUG_PROD_JOIN;
IF L4='CLOROX COMPANY' THEN BRAND = 'CLOROX COMPANY';
ELSE IF L4="RECKITT BENCKISER" THEN BRAND = "RECKITT BENCKISER";
ELSE IF L4="S. C. JOHNSON & SON INC" THEN BRAND = "S.C.JOHNSON & SON INC";
ELSE BRAND = 'OTHERS';
RUN;

/*checking count of each brand*/
PROC SQL;
	CREATE TABLE Y as
	SELECT BRAND,COUNT(BRAND) AS COUNT 
	FROM DRUG
	GROUP BY BRAND;
QUIT;

/* creating Price/OZ and Weighted Prices for running regression and other models*/
PROC SQL;
 CREATE TABLE DRUG_PROD1 AS
 SELECT * ,SUM(UNITS) as TOTAL_SALES
 FROM DRUG 
 GROUP BY IRI_KEY,WEEK,BRAND;
QUIT;

DATA DRUG_PROD;
SET DRUG_PROD1;
PR_PER_OZ = (DOLLARS/UNITS)/VOL_EQ;
PRICE_WT = (PR_PER_OZ*UNITS)/TOTAL_SALES;
RUN;

DATA DRUG_PROD2 (KEEP = IRI_KEY WEEK UNITS DOLLARS F D PR L4 L5 BRAND TOTAL_SALES PRICE_WT);
SET DRUG_PROD;
RUN;

DATA DRUG_PROD3;
SET DRUG_PROD2;
if BRAND = "CLOROX COMPANY" then BR_1 = 1; ELSE BR_1 = 0;
if BRAND = "RECKITT BENCKISER" then BR_2 = 1; ELSE BR_2 = 0;
if BRAND = "S.C.JOHNSON & SON INC" then BR_3 = 1; ELSE BR_3 = 0;
if BRAND = "OTHERS" then BR_4 = 1; ELSE BR_4 = 0;

if F = "A" THEN feature_A = 1; ELSE feature_A = 0;
if F = "A+" then feature_AP = 1; ELSE FEATURE_AP = 0;
if F = "B" then feature_B =1; ELSE feature_B = 0;
if F = "C" then feature_C = 1; ELSE FEATURE_C = 0;

if D=1 then dminor=1; else dminor=0;
if D=2 then dmajor=1; else dmajor=0;

weight = UNITS/TOTAL_SALES;
featureA_wt = feature_A*weight;
featureB_wt = feature_B*weight;
featureC_wt = feature_C*weight;
featureAP_wt = feature_AP*weight;

dminor_wt = dminor*weight;
dmajor_wt = dmajor*weight;
PR_wt = PR*weight;

RUN;


PROC SQL;
 CREATE TABLE DRUG_PROD4 AS
 SELECT IRI_KEY,WEEK,BRAND, SUM(UNITS) as UNITS1, SUM(DOLLARS) as DOLLARS1, SUM(PRICE_WT) as PRICE_WGT, SUM(featureA_wt) as featureA_wgt, 
	SUM(featureAP_wt) as  featureAP_wgt,SUM(featureB_wt)as featureB_wgt, SUM(featureC_wt) as featureC_wgt, SUM(dminor_wt) as  dminor_wgt,
	SUM(dmajor_wt) as dmajor_wgt, SUM(PR_wt) as PR_wgt
 FROM DRUG_PROD3 
 GROUP BY IRI_KEY,WEEK,BRAND;
QUIT;

DATA CLOROX;
SET DRUG_PROD4;
WHERE BRAND = 'CLOROX COMPANY';
RUN;
proc reg data=CLOROX;
model DOLLARS1= PRICE_WGT featureA_wgt featureAP_wgt featureB_wgt featureC_wgt dminor_wgt dmajor_wgt PR_wgt/ stb ;
run;

proc transpose data=drug_prod4 out=wide1 prefix=UNITS1;
   by IRI_KEY WEEK;
   id BRAND;
   var UNITS1;
run;
proc transpose data=drug_prod4 out=wide2 prefix=DOLLARS1;
   by IRI_KEY WEEK;
   id BRAND;
   var DOLLARS1;
run;
proc transpose data=drug_prod4 out=wide3 prefix=PRICE_WGT;
   by IRI_KEY WEEK;
   id BRAND;
   var PRICE_WGT;
run;

proc transpose data=drug_prod4 out=wide4 prefix=featureA_wgt;
   by IRI_KEY WEEK;
   id BRAND;
   var featureA_wgt;
run;
proc transpose data=drug_prod4 out=wide5 prefix=featureAP_wgt;
   by IRI_KEY WEEK;
   id BRAND;
   var featureAP_wgt;
run;
proc transpose data=drug_prod4 out=wide6 prefix=featureB_wgt;
   by IRI_KEY WEEK;
   id BRAND;
   var featureB_wgt;
run;
proc transpose data=drug_prod4 out=wide7 prefix=featureC_wgt;
   by IRI_KEY WEEK;
   id BRAND;
   var featureC_wgt;
run;
proc transpose data=drug_prod4 out=wide8 prefix=dminor_wgt;
   by IRI_KEY WEEK;
   id BRAND;
   var dminor_wgt;
run;
proc transpose data=drug_prod4 out=wide9 prefix=dmajor_wgt;
   by IRI_KEY WEEK;
   id BRAND;
   var dmajor_wgt;
run;
proc transpose data=drug_prod4 out=wide10 prefix=PR_wgt;
   by IRI_KEY WEEK;
   id BRAND;
   var PR_wgt;
run;

data widef;
    merge  wide1(drop=_name_) wide2(drop=_name_) wide3(drop=_name_) wide4(drop=_name_) wide5(drop=_name_)
           wide6(drop=_name_) wide7(drop=_name_) wide8(drop=_name_) wide9(drop=_name_) wide10(drop=_name_);
    by IRI_KEY WEEK;
run;

/*replace missing values with 0*/
data drug_final;
   set widef;
   array change _numeric_;
        do over change;
            if change=. then change=0;
        end;
 run ;
/*grocery store*/

PROC SQL;
	CREATE TABLE  X1 AS
	SELECT L4,sum(DOLLARS) as TOTAL_DOLLARS
	FROM Groc_prod_join
	GROUP BY L4;

	CREATE TABLE MARKET_SHARE1 AS
	SELECT L4,TOTAL_DOLLARS/SUM(TOTAL_DOLLARS) as market_share
	FROM X1
	ORDER BY market_share DESC;
QUIT;

DATA groc;
SET Groc_prod_join;
IF L4='CLOROX COMPANY' THEN BRAND = 'CC';
ELSE IF L4="RECKITT BENCKISER" THEN BRAND = "RB";
ELSE IF L4="S. C. JOHNSON & SON INC" THEN BRAND = "JJ";
ELSE BRAND = 'OTHERS';
RUN;

/*checking count of each brand*/
PROC SQL;
	CREATE TABLE Y1 as
	SELECT BRAND,COUNT(BRAND) AS COUNT 
	FROM groc
	GROUP BY BRAND;
QUIT;

/* creating Price/OZ and Weighted Prices for running regression and other models*/
PROC SQL;
 CREATE TABLE Groc_PROD1 AS
 SELECT * ,SUM(UNITS) as TOTAL_SALES
 FROM Groc 
 GROUP BY IRI_KEY,WEEK,BRAND;
QUIT;

DATA Groc_PROD;
SET Groc_PROD1;
PR_PER_OZ = (DOLLARS/UNITS)/VOL_EQ;
PRICE_WT = (PR_PER_OZ*UNITS)/TOTAL_SALES;
RUN;

DATA Groc_PROD2 (KEEP = IRI_KEY WEEK UNITS DOLLARS F D PR L4 L5 BRAND TOTAL_SALES PRICE_WT);
SET Groc_PROD;
RUN;

DATA Groc_PROD3;
SET Groc_PROD2;
if BRAND = "CC" then BR_1 = 1; ELSE BR_1 = 0;
if BRAND = "RB" then BR_2 = 1; ELSE BR_2 = 0;
if BRAND = "JJ" then BR_3 = 1; ELSE BR_3 = 0;
if BRAND = "OT" then BR_4 = 1; ELSE BR_4 = 0;

if F = "A" THEN feature_A = 1; ELSE feature_A = 0;
if F = "A+" then feature_AP = 1; ELSE FEATURE_AP = 0;
if F = "B" then feature_B =1; ELSE feature_B = 0;
if F = "C" then feature_C = 1; ELSE FEATURE_C = 0;

if D=1 then dminor=1; else dminor=0;
if D=2 then dmajor=1; else dmajor=0;

weight = UNITS/TOTAL_SALES;
featureA_wt = feature_A*weight;
featureB_wt = feature_B*weight;
featureC_wt = feature_C*weight;
featureAP_wt = feature_AP*weight;

dminor_wt = dminor*weight;
dmajor_wt = dmajor*weight;
PR_wt = PR*weight;

RUN;


PROC SQL;
 CREATE TABLE Groc_PROD4 AS
 SELECT IRI_KEY,WEEK,BRAND, SUM(UNITS) as UNITS1, SUM(DOLLARS) as DOLLARS1, SUM(PRICE_WT) as PRICE_WGT, SUM(featureA_wt) as featureA_wgt, 
	SUM(featureAP_wt) as  featureAP_wgt,SUM(featureB_wt)as featureB_wgt, SUM(featureC_wt) as featureC_wgt, SUM(dminor_wt) as  dminor_wgt,
	SUM(dmajor_wt) as dmajor_wgt, SUM(PR_wt) as PR_wgt
 FROM Groc_PROD3 
 GROUP BY IRI_KEY,WEEK,BRAND;
QUIT;

DATA CLOROX1;
SET Groc_PROD4;
WHERE BRAND = 'CLOROX COMPANY';
RUN;
proc reg data=CLOROX1;
model DOLLARS1= PRICE_WGT featureA_wgt featureAP_wgt featureB_wgt featureC_wgt dminor_wgt dmajor_wgt PR_wgt/ stb ;
run;

proc transpose data=Groc_PROD4 out=wide1 prefix=UNITS1;
   by IRI_KEY WEEK;
   id BRAND;
   var UNITS1;
run;
proc transpose data=Groc_PROD4 out=wide2 prefix=DOLLARS1;
   by IRI_KEY WEEK;
   id BRAND;
   var DOLLARS1;
run;
proc transpose data=Groc_PROD4 out=wide3 prefix=PRICE_WGT;
   by IRI_KEY WEEK;
   id BRAND;
   var PRICE_WGT;
run;

proc transpose data=Groc_PROD4 out=wide4 prefix=featureA_wgt;
   by IRI_KEY WEEK;
   id BRAND;
   var featureA_wgt;
run;
proc transpose data=Groc_PROD4 out=wide5 prefix=featureAP_wgt;
   by IRI_KEY WEEK;
   id BRAND;
   var featureAP_wgt;
run;
proc transpose data=Groc_PROD4 out=wide6 prefix=featureB_wgt;
   by IRI_KEY WEEK;
   id BRAND;
   var featureB_wgt;
run;
proc transpose data=Groc_PROD4 out=wide7 prefix=featureC_wgt;
   by IRI_KEY WEEK;
   id BRAND;
   var featureC_wgt;
run;
proc transpose data=Groc_PROD4 out=wide8 prefix=dminor_wgt;
   by IRI_KEY WEEK;
   id BRAND;
   var dminor_wgt;
run;
proc transpose data=Groc_PROD4 out=wide9 prefix=dmajor_wgt;
   by IRI_KEY WEEK;
   id BRAND;
   var dmajor_wgt;
run;
proc transpose data=Groc_PROD4 out=wide10 prefix=PR_wgt;
   by IRI_KEY WEEK;
   id BRAND;
   var PR_wgt;
run;

data widef_groc;
    merge  wide1(drop=_name_) wide2(drop=_name_) wide3(drop=_name_) wide4(drop=_name_) wide5(drop=_name_)
           wide6(drop=_name_) wide7(drop=_name_) wide8(drop=_name_) wide9(drop=_name_) wide10(drop=_name_);
    by IRI_KEY WEEK;
run;

data grocery_final;
   set grocery_final1;
   array change _numeric_;
        do over change;
            if change=. then change=0;
        end;
 run ;

PROC PANEL data=grocery_final;
ID IRI_KEY WEEK;
Model DOLLARS_CC = PRICE_CC fA_CC fAP_CC fB_CC fC_CC dminor_CC dmajor_CC PR_CC/fixone;
RUN; 


proc reg data=CLOROX1;
model DOLLARS1= PRICE_WGT featureA_wgt featureAP_wgt featureB_wgt featureC_wgt dminor_wgt dmajor_wgt PR_wgt/ stb ;
run;






















