%profiler(first_time=1);

data testhashes;
  length index 8 letter $1;
  if _n_ = 1 then do;
    declare hash h(dataset:'random_letters');
    h.definekey('letter');
    h.definedata('letter', 'index');
    h.definedone();
  end;

  do until (eof);
    set random_letters end=eof;
    rc = h.add();
  end;

  declare hiter hi('h');
  rc = hi.first();
  do until (eof2);
    set random_letters(keep=letter rename=(letter=_letter)) end=eof2;
    if _letter=letter then do;
      output;
      rc = hi.next();
    end;
  end;

  drop rc index _letter;

  id=monotonic();

run;

%profiler(desc=END);
