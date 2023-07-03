/* 
This helper macro truncates a given string to ensure that it fits within the 32-character 
limit for SAS macro variable names. It first tries to truncate the suffix "_PROGRESS_BAR_VAR", 
and if the combined string is still too long, it then truncates the base name.

Arguments:
base_name: The base name that might be truncated to fit within the limit.
*/
%macro truncate_name(base_name);
    /* Define the full suffix */
    %let full_suffix = _PROGRESS_BAR_VAR;

    /* Calculate the length of the base name and the full suffix */
    %let base_name_len = %length(&base_name);
    %let full_suffix_len = %length(&full_suffix);

    /* Initialize the actual suffix to the full suffix */
    %let suffix = &full_suffix;

    /* If the combined length of the base name and full suffix exceeds 32, then we need to truncate */
    %if &base_name_len + &full_suffix_len > 32 %then %do;
        /* Calculate the maximum length for the suffix */
        %let max_suffix_len = 32 - &base_name_len;

        /* If the maximum length for the suffix is greater than 0, truncate the suffix */
        %if &max_suffix_len > 0 %then
            %let suffix = %substr(&full_suffix, 1, &max_suffix_len);
        /* Else, the suffix should be empty and the base name should be truncated */
        %else %do;
            %let suffix = ;
            %let base_name = %substr(&base_name, 1, 32);
        %end;
    %end;

    /* Return the base name with the (possibly truncated) suffix */
    &base_name.&suffix
%mend truncate_name;


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
    %global %truncate_name(desc) %truncate_name(N) %truncate_name(bar_character) %truncate_name(progress_bar_width) %truncate_name(start_time);
    %let %truncate_name(desc) = &desc;
    %let %truncate_name(N) = &N;
    %let %truncate_name(bar_character) = &bar_character;
    %let %truncate_name(progress_bar_width) = &progress_bar_width;
    %let %truncate_name(start_time) = %sysfunc(datetime());
%mend progressInit;

/* 
This macro updates the progress bar after each iteration. It calculates the current progress 
ratio, the number of filled and empty slots in the progress bar, and the estimated time 
remaining based on the elapsed time and progress ratio. It then displays the updated progress 
bar and the estimated remaining time in hours, minutes, and seconds.

Arguments:
i: Current item number in the iteration.

Global variables used:
desc_PROGRESS_BAR_VAR: Description of the progress.
N_PROGRESS_BAR_VAR: Total number of items.
bar_character_PROGRESS_BAR_VAR: Character used to represent progress.
progress_bar_width_PROGRESS_BAR_VAR: Width of the progress bar.
start_time_PROGRESS_BAR_VAR: Start time of the iteration.
*/
%macro progressIter(i);
    %local current_progress ratio num_filled num_empty bar elapsed_time est_remaining_hours est_remaining_minutes est_remaining_seconds est_remaining;

    /* Calculate the ratio of progress */
    %let ratio = %sysevalf(&i / %truncate_name(N));

    /* Calculate the number of filled and empty slots in the progress bar */
    %let num_filled = %round(&ratio * %truncate_name(progress_bar_width));
    %let num_empty = %sysevalf(%truncate_name(progress_bar_width) - &num_filled);

    /* Build the progress bar */
    %let bar = %str(|) %repeat(%truncate_name(bar_character), &num_filled) %repeat(-, &num_empty) %str(|);

    /* Calculate elapsed time and estimate remaining time in seconds */
    %let elapsed_time = %sysevalf(%sysfunc(datetime()) - %truncate_name(start_time));
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
    sysecho "%truncate_name(desc) &est_remaining - &bar";
%mend progressIter;

