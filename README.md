# ⚡ Numo-0

### Access squared leverage on any token.

Smart contracts suite of Numo-0, an automated market maker that replicates "Squeeth" on the EVM -- an option-like derivative that squares returns. 

## Installation


```bash
forge install numoen/pmmp
```

## Local development

This project uses [Foundry](https://github.com/foundry-rs/foundry) as the development framework.

### Dependencies

```bash
forge install
```

```bash
npm install @openzeppelin/contracts
```

```bash
npm install create3-factory
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
