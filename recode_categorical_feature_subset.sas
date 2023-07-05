/* 
This macro creates a new dataset where a subset of categorical values are replaced with corresponding 
integer values, based on a specified range. It generates a lookup table for each categorical variable 
in the input dataset within the given range, creates a new dataset where the original categorical values 
are replaced with the mapped integer values, and finally creates a metadata table containing information 
needed to reconstruct the original dataset.

The output dataset only includes the recoded categorical columns and the specified key columns. 
This functionality is useful for large datasets where processing all columns at once may not be 
feasible due to memory constraints and only a subset of columns are needed in the output.

Arguments:
libname: Name of the library where the input dataset is stored.
dsname: Name of the input dataset to be processed.
outdsname: Name of the output dataset to be created.
outlibname: Name of the library where the output dataset will be created. Defaults to 'work'.
start: Starting column index in the list of all character columns in the input dataset. This should be a positive integer.
end: Ending column index in the list of all character columns in the input dataset. This should be a positive integer 
     and should be greater than or equal to the starting index.
keyvars: A list of one or more column names that identify a transaction. These columns are included in the output dataset.

Example usage:
The following call to the macro recodes the first 10 categorical columns in the 'sales' dataset 
stored in the 'mylib' library. The output dataset, which is stored in the 'work' library and 
named 'sales_recoded', includes the recoded columns and the 'transaction_id' column:

    %recode_categorical_feature_subset(libname=mylib, dsname=sales, outdsname=sales_recoded, outlibname=work, start=1, end=10, keyvars=transaction_id);

The macro first collects all character columns in the 'sales' dataset. It then creates lookup tables 
for the first 10 columns and recodes the original categorical values to integer values in these columns. 
The 'sales_recoded' dataset includes the recoded columns and the 'transaction_id' column. Finally, the macro 
creates a 'metadata' dataset that includes information needed to reconstruct the original dataset.
*/

%macro recode_categorical_feature_subset(libname=, dsname=, outdsname=, outlibname=work, start=, end=, keyvars=);
    proc sql noprint;
        sysecho "collect all character columns";
        select name
        into :charvars separated by ' '
        from dictionary.columns
        where libname = upcase("&libname") 
            and memname = upcase("&dsname") 
            and type = 'char';
    quit;

    /* Determine the number of categorical variables */
    %let nvars = %sysfunc(countw(&charvars));

    /* Process each categorical variable in the specified range */
    %do i = &start %to &end;
        %let var = %scan(&charvars, &i);
        proc sql;
            sysecho "1. creating lookup tables - &i./&nvars. (%sysfunc(round(100*&i./&nvars., 0.1))%)";
            create table &outlibname..lookup_&var as 
            select distinct &var, monotonic() as int_value
            from &libname..&dsname(keep=&var);
            create index &var on lookup_&var(&var);
        quit;
    %end;

    data &outlibname..&outdsname;
        sysecho "creating copy of original dataset";
        /* Keep the key columns and the categorical variables to be recoded */
        set &libname..&dsname(keep=&keyvars &charvars);
        %do i = &start %to &end;
            %let var = %scan(&charvars, &i);
            if _n_ = 1 then do;
                sysecho "building hash map object";
                declare hash h(dataset: "lookup_&var");
                h.defineKey("&var");
                h.defineData("int_value");
                h.defineDone();
            end;
            sysecho "2. building mapping - &i./&nvars. (%sysfunc(round(100*&i./&nvars., 0.1))%)";
            rc = h.find();
            if rc = 0 then &var = int_value;
        %end;
    run;

    data &outlibname..metadata;
        sysecho "building metadata table";
        length orig_col_name lookup_table_name int_id_col_name $32.;
        %do i = &start %to &end;
            %let var = %scan(&charvars, &i);
            orig_col_name = "&var";
            lookup_table_name = "lookup_&var";
            int_id_col_name = "int_value";
            output;
        %end;
    run;
%mend recode_categorical_feature_subset;
