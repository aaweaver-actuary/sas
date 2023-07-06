%macro profilerStart(desc=, profiler_output_name=profiler_output);
/* Store the current time in profiler_start_time. This marks the
beginning of the first step. */
%let profiler_start_time = %sysfunc(datetime());

/* The first step is always named 'start'. */
%let profiler_step = start;

/* Create an empty dataset with the correct structure. This is a
common SAS pattern to set up a dataset with the correct variables
and formats. This dataset will be replaced in the next DATA step. */
data &profiler_output_name;
	length desc $ 50;
    format 
		start_time datetime20.
		end_time datetime20.
		time_taken 8.3
		time_share 8.3;
    stop;
run;

/* Replace the empty dataset with a new dataset that contains one
row for the first step. The end_time, time_taken, and time_share
variables are missing because the step is not complete yet. */
data &profiler_output_name.;
	set &profiler_output_name.;
	desc = "&profiler_step.";
	start_time = &profiler_start_time.;
	end_time = .;
	time_taken = .;
	time_share = .;
run;
%mend profilerStart;

%macro profilerSubsequent(desc=, profiler_output_name=profiler_output);
/* 
	Subsequent runs of the macro: Calculate the time taken for the previous
	step and add a row for the next step.
*/

/* Store the current time in profiler_end_time. This marks the end
of the previous step. */
%let profiler_end_time = %sysfunc(datetime());

/* Calculate the time taken for the previous step. This is the difference
between the end time and the start time. */
%let time_taken = %sysevalf(&profiler_end_time - &profiler_start_time.);

/* Update the previous step in the output dataset with the end time
and time taken. The _N_ automatic variable contains the current
observation number, and the nobs option in the set statement contains
the total number of observations. The condition _N_ = nobs is true only
for the last observation, i.e., the previous step. */
data &profiler_output_name.;
    set &profiler_output_name. nobs=nobs;
	if _N_ = nobs then do;
        end_time = &profiler_end_time.;
        time_taken = &time_taken.;
    end;
run;

/* Store the end time of the previous step as the start time for the
next step. */
%let profiler_start_time = &profiler_end_time.;

/* Check if the macro parameter desc is equal to 'END'. If it is, this
is the last run of the macro. */
%if %upcase(&desc.) = END %then %do;

/* Last run of the macro: Calculate the total time and time share for
each step. */

    /* Calculate the total time using PROC SQL. The noprint option
	suppresses the output. The into clause stores the result in a
	macro variable named total_time. */
    proc sql noprint;
        select
			sum(time_taken)
				into :total_time
		from
			&profiler_output_name.
	;
	quit;

    /* Update each step in the output dataset with the time share.
	The time share is the time taken by the step as a percentage of
	the total time. This calculation is done only once, at the
	end of the last run. */
    data &profiler_output_name.;
        set &profiler_output_name.;
        time_share = (time_taken / &total_time.) * 100;
    run;
%end;

/* If the macro parameter desc is not equal to 'END', this is not
the last run of the macro. */
%else %do;

/* Not the last run of the macro: Start a new step. */

	/* Store the description of the next step in profiler_step. The
	superq function is used to preserve leading and trailing blanks
	and to prevent macro execution or resolution. */
    %let profiler_step = %superq(desc);

%put profiler_step: &profiler_step.;

    /* Add a row for the next step to the output dataset. The variables
	end_time, time_taken, and time_share are missing because the step
	is not complete yet. The eof option in the set statement creates
	a temporary variable named eof that is true only for the last
	observation. */
    data &profiler_output_name;
        set &profiler_output_name end=eof;
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

%mend profilerSubsequent;



%macro profiler(desc=, profiler_output_name=profiler_output, first_time=0);
/* Declare global macro variables. These variables are available across
the entire SAS session, not just within this macro. */
%global profiler_start_time profiler_end_time profiler_step;

%if not %symexist(profiler_start_time) or %superq(profiler_start_time)= %then %do;
	%let profiler_start_time = %sysfunc(datetime());
%end;
%else %do;
	%let fake_var=2;
%end;

/* Check if the macro variable profiler_start_time exists. This variable is
created when the macro runs for the first time. If the variable does not
exist, this is the first run of the macro. */
%put before start;
%if &first_time=1 %then %do;
	%profilerStart(desc=&desc., profiler_output_name=&profiler_output_name.);
%end;

%put after start;
    
%put before subsequent;
/* If the macro variable profiler_start_time exists, this is not the first
run of the macro. */
%if &first_time ne 1 %then %do;
    /* Subsequent runs of the macro: Calculate the time taken for the previous
	step and add a row for the next step. */
	%profilerSubsequent(desc=&desc., profiler_output_name=&profiler_output_name.);
%end;
%put after subsequent;
%mend profiler;
