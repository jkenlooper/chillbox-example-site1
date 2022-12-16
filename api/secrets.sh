#!/usr/bin/env sh

set -o errexit

output_file="$1"
test -n "$output_file" || (echo "No output file argument was set." && exit 1)
test -w "$output_file" || (echo "Can't write to file $output_file" && exit 1)


# Change this script to prompt the user for secrets.

printf "\n\n%s\n\n" "Example of prompt for adding secrets. The input would normally be hidden, but these secrets are just for example purposes. Hit Ctrl-C to just use default answers."
# Put in the default answers in case the user doesn't want to bother answering.
cat <<SECRETS > "$output_file"
ANSWER1="Sir Lancelot of Camelot"
ANSWER2="To seek the Holy Grail."
ANSWER5="Blue"
SECRETS

printf "\n\n%s\n" "Stop."

typeit() {
  for w in $1; do
    chars="$(echo "$w" | sed 's/\(.\)/\1 /g')"
    for c in $chars; do
      printf "$c"
      sleep 0.1
    done
    printf " "
    sleep 0.1
  done
}

# Modified to use more inclusive speech.
typeit "Who would cross the Bridge of Death must answer me these questions three, ere the other side you will see."
printf "\n\n"

sleep 1
printf "\nWhat… "
sleep 1
typeit "is your name?"
printf "  "
read first_answer

printf "\nWhat… "
sleep 1
typeit "is your quest?"
printf "  "
read second_answer

printf "\nWhat… "
sleep 1
typeit "is your favourite colour?"
printf "  "
read fifth_answer

printf "\n\n"
typeit "Go on. Off you go."
printf "\n\n"

cat <<SECRETS > "$output_file"
ANSWER1="$first_answer"
ANSWER2="$second_answer"
ANSWER5="$fifth_answer"
SECRETS
