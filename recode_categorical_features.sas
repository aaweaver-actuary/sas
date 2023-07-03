/* 
This macro creates a new dataset where categorical values are replaced with corresponding 
integer values. It generates a lookup table for each categorical variable in the input dataset,
creates a new dataset where the original categorical values are replaced with the mapped integer values,
and finally creates a metadata table containing information needed to reconstruct the original dataset.

Arguments:
libname: Name of the library where the input dataset is stored.
dsname: Name of the input dataset to be processed.
outdsname: Name of the output dataset to be created.
outlibname: Name of the library where the output dataset will be created. Defaults to work.
*/

%macro recode_categorical_features(libname=, dsname=, outdsname=, outlibname=work);
    /* 
    The following PROC SQL step retrieves the names of all character-type columns in the input
    dataset, which are assumed to be categorical. The names are stored in a macro variable for 
    later use.
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

    /* Determine the number of categorical variables */
    %let nvars = %sysfunc(countw(&charvars));

    /* Process each categorical variable */
    %do i = 1 %to &nvars;
        /* Get the name of the i-th categorical variable */
        %let var = %scan(&charvars, &i);
        
        /* 
        Create a lookup table for the i-th categorical variable. The lookup table includes a 
        unique integer for each distinct value of the categorical variable.
        */
        proc sql;
            sysecho "creating lookup table for &i. / &nvars. %eval((100 * &i.)/&nvars.)%";
            create table &outlibname..lookup_&var as 
            select distinct &var, monotonic() as int_value
            from &libname..&dsname(keep=&var);
            /* Create an index to optimize lookup speed */
            create index &var on lookup_&var(&var);
        quit;
    %end;
    
    /* Create a copy of the original dataset that we'll modify */
    data &outlibname..&outdsname;
        sysecho "creating copy of original dataset";
        set &libname..&dsname;
        /* For each categorical variable, replace the original value with the integer mapping */
        %do i = 1 %to &nvars;
            %let var = %scan(&charvars, &i);
            if _n_ = 1 then do;
                sysecho "building hash map object";
                /* This block of code is only executed on the first iteration (i.e., when reading the first row of data) */
                /* It loads the lookup table into a hash object for fast lookup */
                declare hash h(dataset: "lookup_&var");
                h.defineKey("&var");
                h.defineData("int_value");
                h.defineDone();
            end;
            sysecho "mapping &i. / &nvars.";
            /* Look up the integer value for the current row and replace the original value */
            rc = h.find();
            if rc = 0 then &var = int_value; /* If the lookup is successful, replace the value */
        %end;
    run;
    
    /* Create a metadata table to aid in reconstructing the original dataset */
    data &outlibname..metadata;
        sysecho "building metadata table";
        length orig_col_name lookup_table_name int_id_col_name $32.;
        /* For each categorical variable, add a row to the metadata table */
        %do i = 1 %to &nvars;
            %let var = %scan(&charvars, &i);
            /* Store the original column name, lookup table name, and integer ID column name */
            orig_col_name = "&var";
            lookup_table_name = "lookup_&var";
            int_id_col_name = "int_value";
            output;
        %end;
    run;
%mend recode_categorical_features;
