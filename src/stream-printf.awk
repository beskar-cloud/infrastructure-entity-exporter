#!/usr/bin/env gawk
# stream-printf.awk is tool formatting input string fmt with data comming to stdin parameters
#
# returns 1 in case of an error otherwise 0
#
# Example:
# * echo -e "Ann 1\nPatrick 13\nJoan 3 4" | gawk -v "fmt=Record: %s %d\n" -f stream-printf.awk
# Record: Ann 1
# Record: Patrick 13
# Record: Joan 3

BEGIN{
  #fmt="%s";
}

{
  switch(NF) {
    case 0:
      printf(fmt);
      break;
    case 1:
      printf(fmt, $1);
      break;
    case 2:
      printf(fmt, $1, $2);
      break;
    case 3:
      printf(fmt, $1, $2, $3);
      break;
    case 4:
      printf(fmt, $1, $2, $3, $4);
      break;
    case 5:
      printf(fmt, $1, $2, $3, $4, $5);
      break;
    default:
      exit(1);
  }
}
