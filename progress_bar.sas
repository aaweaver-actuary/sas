/* 
This macro initializes the variables necessary for the creation and updating of a progress bar 
in SAS. The macro takes the description of the progress, total number of items to iterate over, 
the character used to represent progress, and the width of the progress bar. It creates global 
variables for these parameters, along with a global variable for the start time of the iteration.

Arguments:
desc: Description of the progress.
N: Total number of items to iterate over.
bar_character: Character used to represent progress. Defaults to "=".
progress_bar_width: Width of the progress bar. Defaults to 50.
*/
%macro progressInit(desc, N, bar_character= =, progress_bar_width=50);
    %global PROGRESS_BAR_VARIABLE_desc PROGRESS_BAR_VARIABLE_N PROGRESS_BAR_VARIABLE_bar_character PROGRESS_BAR_VARIABLE_progress_bar_width PROGRESS_BAR_VARIABLE_start_time;
    %let PROGRESS_BAR_VARIABLE_desc = &desc;
    %let PROGRESS_BAR_VARIABLE_N = &N;
    %let PROGRESS_BAR_VARIABLE_bar_character = &bar_character;
    %let PROGRESS_BAR_VARIABLE_progress_bar_width = &progress_bar_width;
    %let PROGRESS_BAR_VARIABLE_start_time = %sysfunc(datetime());
%mend progressInit;

/* 
This macro updates the progress bar after each iteration. It calculates the current progress 
ratio, the number of filled and empty slots in the progress bar, and the estimated time 
remaining based on the elapsed time and progress ratio. It then displays the updated progress 
bar and the estimated remaining time in hours, minutes, and seconds.

Arguments:
i: Current item number in the iteration.

Global variables used:
PROGRESS_BAR_VARIABLE_desc: Description of the progress.
PROGRESS_BAR_VARIABLE_N: Total number of items.
PROGRESS_BAR_VARIABLE_bar_character: Character used to represent progress.
PROGRESS_BAR_VARIABLE_progress_bar_width: Width of the progress bar.
PROGRESS_BAR_VARIABLE_start_time: Start time of the iteration.
*/
%macro progressIter(i);
    %local current_progress ratio num_filled num_empty bar elapsed_time est_remaining_hours est_remaining_minutes est_remaining_seconds est_remaining;

    /* Calculate the ratio of progress */
    %let ratio = %sysevalf(&i / &&PROGRESS_BAR_VARIABLE_N);

    /* Calculate the number of filled and empty slots in the progress bar */
    %let num_filled = %round(&ratio * &&PROGRESS_BAR_VARIABLE_progress_bar_width);
    %let num_empty = %sysevalf(&&PROGRESS_BAR_VARIABLE_progress_bar_width - &num_filled);

    /* Build the progress bar */
    %let bar = %str(|) %repeat(&&PROGRESS_BAR_VARIABLE_bar_character, &num_filled) %repeat(-, &num_empty) %str(|);

    /* Calculate elapsed time and estimate remaining time in seconds */
    %let elapsed_time = %sysevalf(%sysfunc(datetime()) - &&PROGRESS_BAR_VARIABLE_start_time);
    %let est_remaining = %sysevalf(&elapsed_time / &ratio - &elapsed_time);

    /* Convert estimated remaining time from seconds to hours, minutes, and seconds for display */
    %let est_remaining_hours = %int(%sysevalf(&est_remaining / 3600));
    %let est_remaining_minutes = %int(%sysevalf((&est_remaining - &est_remaining_hours * 3600) / 60));
    %let est_remaining_seconds = %round(%sysevalf(&est_remaining - &est_remaining_hours * 3600 - &est_remaining_minutes * 60));

    /* Conditionally display the estimated remaining time in hours, minutes, and seconds */
    %let est_remaining = (est. ;
    %if &est_remaining_hours > 0 %then %do;
        %let est_remaining = &est_remaining &est_remaining_hours hours ;
    %end;
    %if &est_remaining_minutes > 0 %then %do;
        %let est_remaining = &est_remaining &est_remaining_minutes min. ;
    %end;
    %let est_remaining = &est_remaining &est_remaining_seconds sec. remaining) ;

    /* Display the progress bar and estimated remaining time */
    %sysecho "&&PROGRESS_BAR_VARIABLE_desc &est_remaining - &bar";
%mend progressIter;
