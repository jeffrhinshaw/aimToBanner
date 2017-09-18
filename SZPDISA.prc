CREATE OR REPLACE PROCEDURE BANINST1.SZPDISA IS

/******************************************************************************
   NAME:       SZPDISA
   PURPOSE:    This procedure reads table (external file) to add student / disability codes
               into Banner.  The external file is imported nightly from AIMS.
   Called by:  \app\Banr\local\aim\AimToBanner\aim.bat

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        8/18/2017   jhinshaw       1. Created this procedure.

   NOTES:


******************************************************************************/

l_integrityConstraint exception;
l_nullInsert exception;
PRAGMA EXCEPTION_INIT(l_integrityConstraint, -2291);
PRAGMA EXCEPTION_INIT(l_nullInsert, -1400);
gv_term_code VARCHAR2(6);
TYPE student_disability_rec IS RECORD( 
          student_id  VARCHAR2(10)
        , dsblty_code VARCHAR2(2)
        , error_description VARCHAR2(100));
TYPE student_disability_table_type IS TABLE OF student_disability_rec INDEX BY PLS_INTEGER;
error_students student_disability_table_type;

cursor c_student is
select *
from SZXDISA;
        

procedure p_load_current_term is
begin
    select sz_dates.this_term
    into gv_term_code
    from dual;
    DBMS_OUTPUT.put_line('Current term: ' || gv_term_code);
end p_load_current_term;


procedure p_initialize is
begin
    DBMS_OUTPUT.ENABLE (1000000);
    DBMS_OUTPUT.put_line('Job running');
    p_load_current_term();
end p_initialize;


procedure p_capture_error(in_student in SZXDISA%rowtype, in_error_description in VARCHAR2) is
    error_student student_disability_rec;
begin
    error_student.student_id := in_student.student_id;
    error_student.dsblty_code := in_student.dsblty_code;
    error_student.error_description := in_error_description;
    
    error_students(error_students.count) := error_student;
end p_capture_error;


procedure p_process_student_disability(in_student in SZXDISA%rowtype) is
begin
    
    INSERT INTO SGRDISA 
      (  SGRDISA_PIDM
       , SGRDISA_TERM_CODE
       , SGRDISA_DISA_CODE
       , SGRDISA_ACTIVITY_DATE)
    VALUES ( fz_get_pidm(in_student.student_id)
        , gv_term_code
        , in_student.DSBLTY_CODE
        , sysdate);
        
    EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        -- this is fine, the student has already been noted for this disability for this term
        DBMS_OUTPUT.put_line('Student / disability already stored: ' 
            || in_student.student_id || ', ' || in_student.DSBLTY_CODE);
        NULL;
    WHEN l_integrityConstraint THEN
        -- the disability code does not exist in SGVDISA
        DBMS_OUTPUT.put_line('Disability code not found (student/code): ' 
            || in_student.student_id || ', ' || in_student.DSBLTY_CODE);
        p_capture_error(in_student, 'Disability code not found');
    WHEN l_nullInsert THEN
        -- null insert -- most likely student not found and pidm is therefore null
        DBMS_OUTPUT.put_line('Student or Disability not found (student/code): ' 
            || in_student.student_id || ', ' || in_student.DSBLTY_CODE);
        p_capture_error(in_student, 'Student or Disability not found');
    WHEN OTHERS THEN
        -- unknown error 
        DBMS_OUTPUT.put_line('Error inserting SGRDISA: ' 
            || in_student.student_id || ', ' || in_student.DSBLTY_CODE
            || ', ' || SQLCODE || ' / ' || SQLERRM
        );
        p_capture_error(in_student, substr((SQLCODE || '-' || SQLERRM),1,100));
    
end p_process_student_disability;


procedure p_process_the_daily_feed is
begin
    FOR student in c_student LOOP
        p_process_student_disability(student);
    END LOOP; 
end p_process_the_daily_feed;


function f_build_error_email_body return VARCHAR2 is
   message         VARCHAR2 (3800);
   l_crlf          varchar2(2) := chr(13) || chr(10);

begin
    FOR i in error_students.first .. error_students.last LOOP
        message := message 
            || error_students(i).student_id
            || ' ' || error_students(i).dsblty_code
            || ' ' || error_students(i).error_description
            || l_crlf;
    END LOOP;
    
    return message;
     
    EXCEPTION
     WHEN OTHERS THEN
        -- Most likely blew out the message size.  Keep what we have, and prepend a message to user
       DBMS_OUTPUT.put_line('Exception occurred building email body: ' || SQLCODE || ' / ' || SQLERRM);
       message := '*** Too many errors to list in email.  This list is truncated  ***' || l_crlf 
               || '*** Please contact Banner-SA@ColoradoCollege.edu for full list ***' || l_crlf|| l_crlf ||
               substr(message,1,3640);
       
       return message;
    
end f_build_error_email_body;


procedure p_send_email_on_error is
   name            VARCHAR (80) := 'SZPDISA';
   label           VARCHAR (80) := 'DEFAULT';
   subject         VARCHAR2 (256) := 'SZPDISA Failed to Load Banner With Some AIMS Data';
   message         VARCHAR2 (3800) := 'this is a sample message body';
begin

    IF (error_students.count = 0) THEN
        return;
    END IF;

    message := f_build_error_email_body();

    sz_utilities.p_send_email (
        name
        , label
        , subject
        , message
    );
    DBMS_OUTPUT.put_line('Email sent');
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.put_line('Email send failed: ' || SQLCODE || ' / ' || SQLERRM);
end p_send_email_on_error;


BEGIN
    p_initialize();
    p_process_the_daily_feed();       
    p_send_email_on_error();

   EXCEPTION
     WHEN OTHERS THEN
       DBMS_OUTPUT.put_line('Exception occurred.  Job exiting: ' || SQLCODE || ' / ' || SQLERRM);
       RAISE;
END SZPDISA;
/
