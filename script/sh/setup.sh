cast rpc anvil_impersonateAccount 0x58C37A622cdf8aCe54d8b25c58223f61d0d738aA
cast send 0x767FE9EDC9E0dF98E07454847909b5E959D7ca0E --from 0x58C37A622cdf8aCe54d8b25c58223f61d0d738aA "transfer(address,uint256)(bool)" 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 100000000000000000000
cast rpc anvil_impersonateAccount 0x55FE002aefF02F77364de339a1292923A15844B8
cast send 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48 --from 0x55FE002aefF02F77364de339a1292923A15844B8 "transfer(address,uint256)(bool)" 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 100000000

forge script script/SetupLocal.s.sol -f http://127.0.0.1:8545 -vvvv --broadcast --slow --skip-simulation
