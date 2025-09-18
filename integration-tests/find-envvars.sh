
# Despite the \s*'s around the '=' this misses the lines with spaces around '='
cat python/*.py | grep 'env_var' \
  | sed -nE -e 's/.*env_var=\"(.*)\".*$/\1/p' -e 's/.*env_var = \"(.*)\".*$/\1/p' \
  | sed 's/[",].*$//g' \
  | awk '{$1=$1};1' \
  | sort -u > pyVars.lst

cat README.md | grep '^| ' \
  | tail -n +2 \
  | cut -d'|' -f 2 \
  | sed -e 's/`//g' \
  | sed -nE -e 's/ (\w*)/\1/p' \
  | awk '{$1=$1};1' \
  | sort -u > readmeVars.lst


# This command shows the values that ONLY appear in the README
comm -2 -3 readmeVars.lst pyVars.lst

# This command shows the values that ONLY appear in the python scripts
comm -1 -3 readmeVars.lst pyVars.lst

# This command shows the values that appear in both places
comm -1 -2 readmeVars.lst pyVars.lst




