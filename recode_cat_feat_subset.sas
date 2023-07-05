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

    %recode_cat_feat_subset(libname=mylib, dsname=sales, outdsname=sales_recoded, outlibname=work, start=1, end=10, keyvars=transaction_id);

The macro first collects all character columns in the 'sales' dataset. It then creates lookup tables 
for the first 10 columns and recodes the original categorical values to integer values in these columns. 
The 'sales_recoded' dataset includes the recoded columns and the 'transaction_id' column. Finally, the macro 
creates a 'metadata' dataset that includes information needed to reconstruct the original dataset.
*/

%macro recode_cat_feat_subset(libname=, dsname=, outdsname=, outlibname=work, start=, end=, keyvars=);
    /* 
    Use PROC SQL to retrieve all character-type columns in the dataset, which are typically the categorical features.
    These names are stored in a macro variable, charvars.
    */
    proc sql noprint;
        sysecho "collect all character columns";
        select name
        into :charvars separated by ' '
        from dictionary.columns
        where libname = upcase("&libname") 
            and memname = upcase("&dsname") 
            and type = 'char';
    quit;

    /* Calculate the number of categorical features retrieved */
    %let nvars = %sysfunc(countw(&charvars));

    /* Loop through the range of categorical features specified by start and end */
    %do i = &start %to &end;
        /* Get the name of the current feature */
        %let var = %scan(&charvars, &i);

        /* 
        Use PROC SQL to create a lookup table for each feature. The lookup table maps each distinct category in the feature 
        to a unique integer, which is calculated by the monotonic() function.
        We also create an index on the lookup table for fast lookup operations in the subsequent data step.
        */
        proc sql;
            sysecho "1. creating lookup tables - &i./&nvars. (%sysfunc(round(100*(&i. - &start. + 1)/(&end. - &start. + 1)., 0.1))%)";
            create table &outlibname..lookup_&var as 
            select distinct &var, monotonic() as int_value
            from &libname..&dsname(keep=&var);
            create index &var on lookup_&var(&var);
        quit;
    %end;

    /* Create a new dataset that will contain the recoded features and the transaction identifiers */
    data &outlibname..&outdsname;
        sysecho "creating copy of original dataset";
        /* We only keep the key variables and the features to be recoded */
        set &libname..&dsname(keep=&keyvars &charvars);

        /* Loop through the categorical features again */
        %do i = &start %to &end;
            %let var = %scan(&charvars, &i);
            /* 
            When reading the first row of data, load the lookup table for the current feature into a hash object.
            This allows fast lookup operations when replacing the original categorical values with integers.
            */
            if _n_ = 1 then do;
                sysecho "building hash map object";
                declare hash h(dataset: "lookup_&var");
                h.defineKey("&var");
                h.defineData("int_value");
                h.defineDone();
            end;
            /* Replace the original categorical value with the corresponding integer */
            sysecho "2. building mapping - &i./&nvars. (%sysfunc(round(100*(&i. - &start. + 1)/(&end. - &start. + 1)., 0.1))%)";
            rc = h.find();
            if rc = 0 then &var = int_value;
        %end;
    run;

    /* Create a metadata table for bookkeeping */
    data &outlibname..metadata;
        sysecho "building metadata table";
        length orig_col_name lookup_table_name int_id_col_name $32.;
        /* 
        For each recoded feature, store the name of the original column, the name of the lookup table, 
        and the name of the column in the lookup table that contains the integer values.
        */
        %do i = &start %to &end;
            %let var = %scan(&charvars, &i);
            orig_col_name = "&var";
            lookup_table_name = "lookup_&var";
            int_id_col_name = "int_value";
            output;
        %end;
    run;
%mend recode_cat_feat_subset;
