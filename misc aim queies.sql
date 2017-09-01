INSERT INTO SGRDISA 
      (  SGRDISA_PIDM
       , SGRDISA_TERM_CODE
       , SGRDISA_DISA_CODE
       , SGRDISA_ACTIVITY_DATE)
VALUES ( fz_get_pidm(:id)
        , :term_cd
        , :disibility_cd
        , sysdate);
        
select fz_get_pidm(:id)
from dual;

------------------------------
-- DISABILITY CONTROL TABLE --
------------------------------
select * 
from stvdisa;

-------------------------------------
-- Student / term disability table --
-------------------------------------
select *
from SGRDISA;