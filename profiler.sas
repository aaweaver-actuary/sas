/* Define a macro named profiler that accepts an optional parameter, desc. */
%macro profiler(desc=, profiler_output_name=profiler_output);
    /* Declare global macro variables. These variables are available across the entire SAS session, 
    not just within this macro. */
    %global profiler_start_time profiler_end_time profiler_output profiler_step;
    
    /* Check if the macro variable profiler_start_time exists. This variable is created when the 
    macro runs for the first time. If the variable does not exist, this is the first run of the macro. */
    %if not %symexist(profiler_start_time) %then %do;
        /* First run of the macro: Initialize variables and create the output dataset. */
        
        /* Store the current time in profiler_start_time. This marks the beginning of the first step. */
        %let profiler_start_time = %sysfunc(datetime());
        
        /* The first step is always named 'start'. */
        %let profiler_step = start;
        
        /* The output dataset is named 'profiler_output'. If you want a different name, change it here. */
        %let profiler_output = &profiler_output_name.;
        
        /* Create an empty dataset with the correct structure. This is a common SAS pattern to set up a 
        dataset with the correct variables and formats. This dataset will be replaced in the next DATA step. */
        data &profiler_output;
            length desc $ 50;
            format start_time end_time datetime20. time_taken 8. time_share 8.;
            stop;
        run;
        
        /* Replace the empty dataset with a new dataset that contains one row for the first step. 
        The end_time, time_taken, and time_share variables are missing because the step is not complete yet. */
        data &profiler_output;
            set &profiler_output;
            desc = "&profiler_step";
            start_time = &profiler_start_time;
            end_time = .;
            time_taken = .;
            time_share = .;
        run;
    %end;
    
    /* If the macro variable profiler_start_time exists, this is not the first run of the macro. */
    %else %do;
        /* Subsequent runs of the macro: Calculate the time taken for the previous step and add a row for the next step. */
        
        /* Store the current time in profiler_end_time. This marks the end of the previous step. */
        %let profiler_end_time = %sysfunc(datetime());
        
        /* Calculate the time taken for the previous step. This is the difference between the end time and the start time. */
        %let time_taken = %sysevalf(&profiler_end_time - &profiler_start_time);
        
        /* Update the previous step in the output dataset with the end time and time taken. The _N_ automatic variable 
        contains the current observation number, and the nobs option in the set statement contains the total number of 
        observations. The condition _N_ = nobs is true only for the last observation, i.e., the previous step. */
        data &profiler_output;
            set &profiler_output nobs=nobs;
            if _N_ = nobs then do;
                end_time = &profiler_end_time;
                time_taken = &time_taken;
            end;
        run;
        
        /* Store the end time of the previous step as the start time for the next step. */
        %let profiler_start_time = &profiler_end_time;
        
        /* Check if the macro parameter desc is equal to 'END'. If it is, this is the last run of the macro. */
        %if %upcase(&desc) = END %then %do;
            /* Last run of the macro: Calculate the total time and time share for each step. */
            
            /* Calculate the total time using PROC SQL. The noprint option suppresses the output. 
            The into clause stores the result in a macro variable named total_time. */
            proc sql noprint;
                select sum(time_taken) into :total_time from &profiler_output;
            quit;
            
            /* Update each step in the output dataset with the time share. The time share is the time taken by the step 
            as a percentage of the total time. This calculation is done only once, at the end of the last run. */
            data &profiler_output;
                set &profiler_output;
                time_share = (time_taken / &total_time) * 100;
            run;
        %end;
        
        /* If the macro parameter desc is not equal to 'END', this is not the last run of the macro. */
        %else %do;
            /* Not the last run of the macro: Start a new step. */
            
            /* Store the description of the next step in profiler_step. The superq function is used to preserve 
            leading and trailing blanks and to prevent macro execution or resolution. */
            %let profiler_step = %superq(desc);
            
            /* Add a row for the next step to the output dataset. The variables end_time, time_taken, and time_share are 
            missing because the step is not complete yet. The eof option in the set statement creates a temporary variable 
            named eof that is true only for the last observation. */
            data &profiler_output;
                set &profiler_output end=eof;
                if eof then do;
                    desc = "&profiler_step";
                    start_time = &profiler_start_time;
                    end_time = .;
                    time_taken = .;
                    time_share = .;
                    output;
                end;
            run;
        %end;
    %end;
%mend profiler;


/* ====================================================================================================== */
/* Define a macro named profiler that accepts an optional parameter, desc. */
%macro profiler(desc=, profiler_output_name=profiler_output, first_time=0);
    /* Declare global macro variables. These variables are available across the entire SAS session, 
    not just within this macro. */
    %global profiler_start_time profiler_end_time profiler_output profiler_step;
    
    /* Check if the macro variable profiler_start_time exists. This variable is created when the 
    macro runs for the first time. If the variable does not exist, this is the first run of the macro. */
%put 1 - &profiler_start_time.;
    %if &first_time=1 %then %do;
        /* First run of the macro: Initialize variables and create the output dataset. */
%put 14;       
        /* Store the current time in profiler_start_time. This marks the beginning of the first step. */
        %let profiler_start_time = %sysfunc(datetime());
%put 15;       
        /* The first step is always named 'start'. */
        %let profiler_step = start;

%put 2; 
        /* The output dataset is named 'profiler_output'. If you want a different name, change it here. */
        %let profiler_output=&profiler_output_name.;
%put 16;        
        /* Create an empty dataset with the correct structure. This is a common SAS pattern to set up a 
        dataset with the correct variables and formats. This dataset will be replaced in the next DATA step. */
        data &profiler_output;
            length desc $ 50;
            format start_time datetime20. end_time datetime20. time_taken 8.3 time_share 8.3;
            stop;
        run;
%put 3;  
        /* Replace the empty dataset with a new dataset that contains one row for the first step. 
        The end_time, time_taken, and time_share variables are missing because the step is not complete yet. */
        data &profiler_output.;
            set &profiler_output.;
            desc = "&profiler_step.";
            start_time = &profiler_start_time.;
            end_time = .;
            time_taken = .;
            time_share = .;
        run;
%put 4;
    %end;
    
    /* If the macro variable profiler_start_time exists, this is not the first run of the macro. */
    %else %do;
        /* Subsequent runs of the macro: Calculate the time taken for the previous step and add a row for the next step. */
%put 5;
        /* Store the current time in profiler_end_time. This marks the end of the previous step. */
        %let profiler_end_time = %sysfunc(datetime());
%put 6 - &profiler_start_time./&profiler_end_time.;  
        /* Calculate the time taken for the previous step. This is the difference between the end time and the start time. */
        %let time_taken = %sysevalf(&profiler_end_time - &profiler_start_time.);
%put 7;   
        /* Update the previous step in the output dataset with the end time and time taken. The _N_ automatic variable 
        contains the current observation number, and the nobs option in the set statement contains the total number of 
        observations. The condition _N_ = nobs is true only for the last observation, i.e., the previous step. */
        data &profiler_output;
            set &profiler_output nobs=nobs;
            if _N_ = nobs then do;
                end_time = &profiler_end_time;
                time_taken = &time_taken;
            end;
        run;
%put 8;     
        /* Store the end time of the previous step as the start time for the next step. */
        %let profiler_start_time = &profiler_end_time;
        
        /* Check if the macro parameter desc is equal to 'END'. If it is, this is the last run of the macro. */
        %if %upcase(&desc) = END %then %do;
%put 9;            /* Last run of the macro: Calculate the total time and time share for each step. */
            
            /* Calculate the total time using PROC SQL. The noprint option suppresses the output. 
            The into clause stores the result in a macro variable named total_time. */
            proc sql noprint;
                select sum(time_taken) into :total_time from &profiler_output;
            quit;
%put 10;            
            /* Update each step in the output dataset with the time share. The time share is the time taken by the step 
            as a percentage of the total time. This calculation is done only once, at the end of the last run. */
            data &profiler_output;
                set &profiler_output;
                time_share = (time_taken / &total_time) * 100;
            run;
%put 11;  
	%end;
      
        /* If the macro parameter desc is not equal to 'END', this is not the last run of the macro. */
        %else %do;
            /* Not the last run of the macro: Start a new step. */
%put 12;            
            /* Store the description of the next step in profiler_step. The superq function is used to preserve 
            leading and trailing blanks and to prevent macro execution or resolution. */
            %let profiler_step = %superq(desc);
%put 13;    
            /* Add a row for the next step to the output dataset. The variables end_time, time_taken, and time_share are 
            missing because the step is not complete yet. The eof option in the set statement creates a temporary variable 
            named eof that is true only for the last observation. */
            data &profiler_output;
                set &profiler_output end=eof;
                if eof then do;
                    desc = "&profiler_step";
                    start_time = &profiler_start_time;
                    end_time = .;
                    time_taken = .;
                    time_share = .;
                    output;
                end;
            run;
        %end;
    %end;
%mend profiler;
