/* 
  PROFILER MACRO
  ==============

  This macro is used to profile the time taken by each step in a SAS
  program. The macro creates a dataset that contains the start time,
  end time, time taken, and time share for each step. The time share
  is the time taken by the step as a percentage of the total time.

  The macro is designed to be called at the beginning of each step in
  a SAS program. The macro is called with a description of the step
  and the name of the output dataset. The macro calculates the time
  taken by the previous step and adds a row for the current step to
  the output dataset. The macro is called with the description 'END'
  at the end of the program. The macro calculates the total time and
  time share for each step and adds these values to the output
  dataset.

  The macro is designed to be called multiple times in a SAS program.
  The same macro call is used for each step. 

  Parameters:
  ----------
    desc: (character) A description of the step. The description is
      stored in the desc variable in the output dataset.
    profiler_output_name: (character) The name of the output dataset.
      The output dataset is created in the first call to the macro.
    first_time: (binary) A flag that indicates if this is the first
      run of the macro. The macro is called with the first_time
      parameter set to 1 at the beginning of the program. The macro
      initializes the output dataset and calculates the time taken by
      the first step.
    last_time: (binary) A flag that indicates if this is the last run
      of the macro. The macro is called with the last_time parameter
      set to 1 at the end of the program. The macro calculates the
      total time and time share for each step and adds these values to
      the output dataset.

  Returns:
  -------
    The macro returns a dataset that contains:
      desc: (character) A description of the step.
      start_time: (datetime) The start time of the step.
      end_time: (datetime) The end time of the step.
      time_taken: (numeric) The time taken by the step in seconds.
      time_share: (numeric) The time taken by the step as a percentage
        of the total time.

  Example usage:
  -------------
    %profiler(desc=start,
              profiler_output_name=profiler_output,
              first_time=1);

      ... some code ... 

    %profiler(desc=sort, profiler_output_name=profiler_output);
      ... proc sort ...

    %profiler(desc=merge, profiler_output_name=profiler_output);
      ... proc merge ...

    %profiler(profiler_output_name=profiler_output, last_time=1);

  Notes:
  -----
    The first call to the macro must have the first_time parameter
    set to 1. The last call to the macro must have the last_time
    parameter set to 1. The macro will not work correctly if these
    parameters are not set correctly.

    If you set the desc to delete, the macro will filter that row
    out of the output dataset. This is useful if you want to delete
    a step from the output dataset.

    In most cases you should begin with (if using the default
    profiler_output_name):
      %profiler(desc=start, first_time=1);

    When running %profiler(last_time=1) to end the profiler, it
    doesn't matter what you set the desc to. The macro does not
    add a row to the output dataset when last_time=1.
*/

/* helper macros for profiling */
/* `init_global_variables` is used to initialize the global variables
   used by the profiler. */
%macro init_global_variables(variables=);
%let variables = %sysfunc(tranwrd(&variables., %str( ), %str( )));
%let count = %sysfunc(countw(&variables., %str( )));
%do i = 1 %to &count.;
  %let var = %scan(&variables., &i., %str( ));
  %if not %symexist(&var.) %then %do;
  	%if "&var."="profiler_start_time" or
		"&var."="profiler_end_time" %then %do;
		%let &var. = %sysfunc(datetime());
	%end;
	%else %do;
    	%let &var. = ;
	%end;
  %end;
%end;
%mend init_global_variables;

/* `create_temp_tbl` is used to create a temporary table that is used
    to store the time taken by each step. It is called at the
    beginning of each step, and appends a row to output dataset.
*/
%macro create_temp_tbl(desc=.,start_time=.,end_time=.);
  /* Set the global variable `profiler_step` to the description of the
  current step. Use the `superq` function to prevent the macro from
  being called when the macro is defined. */
  %let profiler_step = %superq(desc);

  /* Create an empty dataset with the correct structure. 
  This dataset will be replaced in the next DATA step. */
  data temp_tbl;
    length desc $ 50;
    format start_time datetime18.1 end_time datetime18.1;
  run;

  /* Create a row for the current step. */
  data temp_tbl;
    set temp_tbl;
    desc = "&profiler_step.";
    start_time = &start_time.;
    end_time = &end_time.;
  run;
%mend create_temp_tbl;

/* `drop_temp_tbl` is used to delete the temporary table. It is called
    at the end of each step. */
%macro drop_temp_tbl;
proc delete data=temp_tbl;
run;
%mend drop_temp_tbl;

/* `start_step` is used to initialize the profiler. It is called when
    the macro is first called (eg when first_time=1). */
%macro start_step(desc=start, profiler_output_name=profiler_output);
/* The first step is always named 'start'. */
%let profiler_step =&desc.;

/* initialize table */
%create_temp_tbl(desc=&desc., start_time=%sysfunc(datetime()), end_time=.)

/* set it equal to output */
data &profiler_output_name.;
set temp_tbl;
run;

%drop_temp_tbl;

%mend start_step;

%macro profilerSubsequent(desc=A_DESC, profiler_output_name=profiler_output,last_time=0);
/* 
	Subsequent runs of the macro: Calculate the time taken for the previous
	step and add a row for the next step.
*/

%let profiler_step=&desc.;

/* Store the current time in profiler_end_time. This marks the end
of the previous step. */
%let profiler_end_time = %sysfunc(datetime());

/* Update the previous step in the output dataset with the end time
and time taken. The _N_ automatic variable contains the current
observation number, and the nobs option in the set statement contains
the total number of observations. The condition _N_ = nobs is true only
for the last observation, i.e., the previous step. */
data &profiler_output_name.;
set &profiler_output_name. nobs=nobs;
if _N_ = nobs then do;
    end_time = &profiler_end_time.;
end;
run;

/* Store the end time of the previous step as the start time for the
next step. */
%let profiler_start_time = &profiler_end_time.;

/* Check if the macro parameter desc is equal to 'END'. If it is, this
is the last run of the macro. */
%if &last_time.=1 %then %do;
/* Last run of the macro: Calculate the total time and time share for
each step. */

	data &profiler_output_name.;
	set &profiler_output_name.;
	time_taken=end_time - start_time;
	if desc="delete" then delete;
	run;

    /* Calculate the total time using PROC SQL. The noprint option
	suppresses the output. The into clause stores the result in a
	macro variable named total_time. */
    proc sql noprint;
    select
		sum(time_taken)
			into :total_time
	from
		&profiler_output_name.;
	quit;

    /* Update each step in the output dataset with the time share.
	The time share is the time taken by the step as a percentage of
	the total time. This calculation is done only once, at the
	end of the last run. */
    data &profiler_output_name.;
    set &profiler_output_name.;
    time_share = (time_taken / &total_time.) * 100;
    run;

	data &profiler_output_name.;
    set &profiler_output_name.;
    format time_taken 8.3;
	format time_share 8.1;
    run;

%end;

/* If the macro parameter desc is not equal to 'END', this is not
the last run of the macro. */
%else %do;

/* Not the last run of the macro: Start a new step. */

	/* Store the description of the next step in profiler_step. The
	superq function is used to preserve leading and trailing blanks
	and to prevent macro execution or resolution. */
	%put profiler_step: &profiler_step.;

	%create_temp_tbl(desc=&desc., start_time=%sysfunc(datetime()), end_time=.);

    /* Add a row for the next step to the output dataset. The variables
	end_time, time_taken, and time_share are missing because the step
	is not complete yet. The eof option in the set statement creates
	a temporary variable named eof that is true only for the last
	observation. */
    data &profiler_output_name;
    set &profiler_output_name temp_tbl;
    run;

	%drop_temp_tbl;
%end;

%mend profilerSubsequent;

%macro profiler(desc=MY DESC,
				profiler_output_name=profiler_output,
				first_time=0, /*SET TO 1 FOR THE FIRST RUN */
				last_time=0   /*SET TO 1 FOR THE VERY LAST RUN*/
				);
/* Declare global macro variables. These variables are available across
the entire SAS session, not just within this macro. */
%global profiler_start_time profiler_end_time;

%init_global_variables(variables=desc profiler_start_time profiler_end_time profiler_step total_time time_taken);

/* Check if the macro variable profiler_start_time exists. This variable is
created when the macro runs for the first time. If the variable does not
exist, this is the first run of the macro. */
%put before start;
%if &first_time=1 %then %do;
  %if "&desc." ne "MY DESC" %then %do;
	  %start_step(desc=&desc., profiler_output_name=&profiler_output_name.);
  %end;
  %else %do;
    %start_step(desc=start, profiler_output_name=&profiler_output_name.);
  %end;
%end;

%put after start;
    
%put before subsequent;
/* If the macro variable profiler_start_time exists, this is not the first
run of the macro. */
%if &first_time ne 1 %then %do;
    /* Subsequent runs of the macro: Calculate the time taken for the previous
	step and add a row for the next step. */
	%profilerSubsequent(
		desc=&desc.,
		profiler_output_name=&profiler_output_name.,
		last_time=&last_time.
	);
%end;
%put after subsequent;
%mend profiler;
