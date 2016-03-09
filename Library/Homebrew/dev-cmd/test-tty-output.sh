homebrew-test-tty-output() {
  echo "Testing TTY output:"
  echo "----------------------------------------"
  ohai [ohai] Test 0
  ohai "[ohai] Test 1"
  ohai <<EOS
[ohai] Test 2
    ... second line of Test 2.
EOS
  echo "----------------------------------------"
  oh1 "[oh1] Test 1"
  oh1 <<EOS
[oh1] Test 2
    ... second line of Test 2.
EOS
  echo "----------------------------------------"
  opoo "[opoo] Test 1"
  opoo <<EOS
[opoo] Test 2
    ... second line of Test 2.
EOS
  echo "----------------------------------------"
  onoe "[onoe] Test 1"
  onoe <<EOS
[onoe] Test 2
    ... second line of Test 2.
EOS
  echo "----------------------------------------"
  odie <<EOS
[odie] The End!
EOS
}
