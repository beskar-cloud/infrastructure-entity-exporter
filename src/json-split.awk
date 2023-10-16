#!/usr/bin/env gawk
# json-split.awk is tool splitting stream of concatenated json documents into file-names
# file-names are provided as file_names_str or file_names_file variables (gawk -v)

BEGIN{
  # input file names:
  # as string:
  #   file_names_str="a b c d e f";
  # from a file:
  #   file_names_file="file-names.lst";
  if (length(file_names_str) > 0) {
    split(file_names_str, file_names_arr);
  } else {
    if (length(file_names_file) > 0) {
      indx = 1;
      while ((getline i_line < file_names_file) > 0) {
        if (length(i_line) > 0) {
          file_names_arr[indx] = i_line;
          indx++;
        }
      }
      close(file_names_file)
    } else {
      exit(2);
    }
  }

  fsm = "";
  indx = 1;
  item = "";
}

{
  if (($0 == "}")&&(fsm=="in")) {
    fsm = "out";
    printf("%s\n%s", item, $0) > file_names_arr[indx];
    indx++;
  }

  if (fsm == "in") {
    item = sprintf("%s\n%s", item, $0);
  }

  if ($0 == "{") {
    fsm = "in";
    item = $0;
  }
}
