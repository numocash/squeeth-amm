deploy() {
  NETWORK=$1

	forge script script/Deploy.s.sol -f $NETWORK -vvvv --json --silent --broadcast --verify --slow
}

deploy $1