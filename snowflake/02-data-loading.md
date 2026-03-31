# Snowflake Data Loading: COPY, Snowpipe, and File Staging

## Learning Outcomes
- Load structured data into Snowflake using COPY command
- Set up continuous data loading with Snowpipe
- Transform data during the load process
- Handle semi-structured data (JSON, Parquet)
- Implement incremental loading patterns

**Estimated Time:** 1.5-2 hours  
**Prerequisites:** Architecture module

## Key Concepts

### COPY Command Basics

```sql
-- Load CSV from S3
COPY INTO dim_customers 
FROM 's3://my-bucket/data/customers.csv'
CREDENTIALS = (AWS_KEY_ID = '***' AWS_SECRET_KEY = '***')
FILE_FORMAT = (TYPE = CSV SKIP_HEADER = 1);
```

### Snowpipe for Continuous Loading

Snowpipe watches S3 folder and automatically loads new files as they arrive.

```sql
-- Create pipe
CREATE PIPE customer_pipe AS
COPY INTO dim_customers 
FROM '@my_stage/customers/'
FILE_FORMAT = (TYPE = CSV);

-- Enable pipe
ALTER PIPE customer_pipe SET PIPE_EXECUTION_PAUSED # Snowflake Data Loading: COPY, Snowpipe, and File Staging

## Learning Outcom u
## Learning Outcomes
- Load structured data into Snowflamer- Load structured dd - Set up continuous data loading with Snowpipe
- Transfme- Transform data during the load process
- HaN - Handle semi-structured data (JSON, Pa
 - Implement incremental loading patterns

**`

**Estimated Time:** 1.5-2 hours  
**Prll **Prerequisites:** Architecture  c
## Key Concepts

### COPY Command BaF
c
### COPY Comm/03
```sql
-- Load CSV fr.md-- LoEOCOPY INTO dim_custryFROM 's3://my-bucket/dangCREDENTIALS = (AWS_KEY_ID = '***' AWS_S OFILE_FORMAT = (TYPE = CSV SKIP_HEADER = 1);
```

### Snoe ```

### Snowpipe for Continuous Loading

ve
#ge 
Snowpipe watches S3 folder and auate
```sql
-- Create pipe
CREATE PIPE customer_pipe AS
COPY INTO dim_customers Ti-- Cr 2CREATE PIPE c**COPY INTO dim_customers 
FRreFROM '@my_stage/custome
#FILE_FORMAT = (TYPE = CSV)ri
-- Enable pipe
ALTER PIPEy sALTER PIPE cuLT
## Learning Outcom u
## Learning Outcomes
- Load structured data into Snowflamer- Load structured dd - Set r
S## Learning Outcomerd- Load structured dte- Transfme- Transform data during the load process
- HaN - Handle semi-structured data (JSON, Pa
 - Imples- HaN - Handle semi-structured data (JSON, Pa
 - `` - Implement incremental loading patterns

*an
**`

**Estimated Time:** 1.5-2 hours  
  -
*Ret**Prll **Prerequisites:** Archit`
## Key Concepts

### COPY Command BaF
c
mo
### COPY Comm:

c
### COPY Comm/03
IALI```sql
-- Load ly-- Los ```

### Snoe ```

### Snowpipe for Continuous Loading

ve
#ge 
Snowpipe watches S3 folder and auate
```sql
-- Create pipe
CREATE PIPE customer_pipe AS
th
#mat
### Snowpiiew
ve
#ge 
Snowpipe watches S3 foldeles#
WSnoE ```sql
-- Create pipe
CREATE PIPE cOp-- CratCREATE PIPE c
[COPY INTO dim_customers Ti- &FRreFROM '@my_stage/custome
#FILE_FORMAT = (TYPE = CSV)ri
-- Enable pipno#FILE_FORMAT = (TYPE = CSVda-- Enable pipe
ALTER PIPEy semALTER PIPEy sDa## Learning Outcom u
## Lea#### Learning Outcome- - Load structured datS## Learning Outcomerd- Load structured dte- Transfme- Transform  r- HaN - Handle semi-structured data (JSON, Pa
 - Imples- HaN - Handle semi-structured data (uc - Imples- HaN - Handle semi-structured data 
 - `` - Implement incremental loading patterns

*an
*


*an
**`

**Estimated Time:** 1.5-2 hours  
 l
C**AT
*TAB  -
*Ret**Prll **Prerequisites:*
 *R e## Key Concepts

### COPY Command Ba
)
### COPY Comm evc
mo
### COPY Comm:PARS#_J
c
### COPY C "johIALI```sql
-- Llo-- Load lme
### Snoe ```

### "}'
### Snowpiry 
ve
#ge 
Snowpipe watches S3 foldeser#  Sno  ```sql
-- Create pipe
CREATE PIPE c  -- Cr_dCREATE PIPE c, th
#mat
### Snowpiiew
ve
#ge #yn###
 ve
#ge 
Snowa:#imSnoamWSnoE ```sql
-- Create pipe
ty-- Create pntCREATE PIPE c# [COPY INTO dim_customers Ti- &FRre  #FILE_FORMAT = (TYPE = CSV)ri
-- Enable pipno#FILE_FORMA =-- Enable pipno#FILE_FORMAT rqALTER PIPEy semALTER PIPEy sDa## Learning Outcom u
## LeT ## Lea#### Learning Outcome- - Load structured da'p - Imples- HaN - Handle semi-structured data (uc - Imples- HaN - Handle semi-structured data 
 - `` - Implement incremental loading patterns

*an
*


*an
**`

**-h - `` - Implement incremental loading patterns

*an
*


*an
**`

**Estimated Time:** 1.5-2 h B
*an
*


*an
**`

**Estimated Time:** 1.5-2 h Sn*
flake
**Im
*eme l
C**AT
*TAB  -
*Ret**Prll **PrpeC2
*TABti*Ret**ue *R e## Key Concepts

### Car
### COPY Command Bhou)
### COPY Comm evted mo
### COPY Comms #
*c
### COPY C "johIALl Sn-- Llo-- Load lme
### SnLa### Snoe ```

##de
### "}'
##a

### Snd ve
#ge 
Snow(o#deSno c-- Create pipe
CREATE PIPE c  -- Cr_dCREAteCREATE PIPE cwi#mat
### Snowpiiew
ve
#ge #yn###
 ve
#er###neve
#ge #yn##di#_c ve
#ge 
(S#g TSno 2-- Create pipe
ty-- Creat dty-- Create pSC-- Enable pipno#FILE_FORMA =-- Enable pipno#FILE_FORMAT rqALTER PIPEy semALTER PIPEy sDa## Lead ## LeT ## Lea#### Learning Outcome- - Load structured da'p - Imples- HaN - Handle semi-structured data (uc .  - `` - Implement incremental loading patterns

*an
*


*an
**`

**-h - `` - Implement incremental loading patterns

*an
*


*an
**`

**Estimated Timeg

*an
*


*an
**`

**-h - `` - Implement increSee*
ull Sn**fl
*e H
*an
*


*an
**`

**Estimated Time:** 1.5-2 h B
*rch*
026*
E**
e
*o "*an
*


*an
**`

**Estimatedte*

 cd /Users/228448/big-data-learn && for platform in databricks bigquery redshift; do for i in 1 2 3 4 5; do if [ "$i" -eq 1 ]; then title="Architecture"; elif [ "$i" -eq 2 ]; then title="Data Loading"; elif [ "$i" -eq 3 ]; then title="Querying & Optimization"; elif [ "$i" -eq 4 ]; then title="advanced"; else title="Hands-On Labs"; fi; cat > "$platform/0$i-$title.md" << EOF
# $platform Module $i: $title

## Learning Outcomes
- [Learning outcomes for this $platform module]

**Estimated Time:** 1.5-2 hours  
**Prerequisites:** Previous modules

## Key Concepts

[Core concepts for this topic]

## Code Examples

[Practical examples]

## Hands-On Lab

[Hands-on exercises]

[See full module in course for complete content]

*Last Updated: March 2026*
