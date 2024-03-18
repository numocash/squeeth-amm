# ⚡ PowerMaker2

![banner](images/Banner.png)

Smart contracts suite of PowerMaker2, an automated market maker implementaion of the capped power-4 invariant for replicating power perpetuals raised to the fourth power on the EVM.

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
