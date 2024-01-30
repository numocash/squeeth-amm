# ⚡ QuadMaker

Smart contracts suite of QuadMaker, an automated market maker of quadratic options on Ethereum. 

![QuadMaker_Logo2](https://github.com/Numoen/QuadMaker/assets/44106773/1cf8fc8d-be7c-49bc-aaff-6c61fcfcd628)

## Installation

To install with [Foundry](https://github.com/foundry-rs/foundry):

```bash
forge install numoen/pmmp
```

## Local development

This project uses [Foundry](https://github.com/foundry-rs/foundry) as the development framework.

### Dependencies

```bash
forge install
```

### Compilation

```bash
forge build
```

### Test

```bash
forge test
```

### Local setup

In order to test third party integrations such as interfaces, it is possible to set up a forked mainnet with several positions open

```bash
sh anvil.sh
```

then, in a separate terminal,

```bash
sh setup.sh
```
