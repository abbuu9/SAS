PROC SQL;
 CREATE TABLE Labesl_rfm1 AS
 SELECT * 
 FROM Labesl_rfm A
 join on IRI_KEY,WEEK,BRAND;
QUIT;

PROC SQL;
 CREATE TABLE Labels_rfm1 AS
 SELECT *
 FROM Labels_rfm A LEFT JOIN Panel_demo B
 ON (A.PANID = B.Panelist_ID);
QUIT;

data Labels_rfm2;
   set Labels_rfm1;
   array change _numeric_;
        do over change;
            if change=. then change=0;
        end;
 run ;

 PROC SQL;
 CREATE TABLE survival1 AS
 SELECT *
 FROM panel_full 
 where week >= (SELECT min(week) from panel_full) and week < (SELECT min(week)+21 from panel_full);
QUIT;

DATA survival2;
SET survival1;
if L4= 'CLOROX COMPANY' then flag=1; else flag=0;
RUN;
DATA CLOROX_surv;
SET survival2;
WHERE L4 = 'CLOROX COMPANY';
RUN;

 PROC SQL;
 CREATE TABLE survival11 AS
 SELECT *
 FROM panel_full 
 where week >= (SELECT min(week)+21 from panel_full) and week < (SELECT min(week)+41 from panel_full);
QUIT;

 PROC SQL;
 CREATE TABLE survival_new AS
 SELECT * FROM survival11 s1 where PANID IN (SELECT PANID from CLOROX_surv s2);
QUIT;
DATA survival_new1;
SET survival_new;
if L4= 'CLOROX COMPANY' then flag=1; else flag=0;
RUN;

DATA survival_man;
SET survival_new;
if L4= 'CLOROX COMPANY' then flag=1;
ELSE IF L4="RECKITT BENCKISER" THEN flag = 2;
ELSE IF L4="S. C. JOHNSON & SON INC" THEN flag = 3;
ELSE flag = 4;
RUN;

proc lifetest data=survival_new2;
time week1*flag(0);
run;

PROC SQL;
 SELECT min(week)
 FROM survival_new1;
QUIT;

DATA survival_new2;
SET survival_new1;
week1= week-1134;
RUN;

