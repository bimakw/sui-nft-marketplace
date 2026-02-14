# Sui NFT Marketplace

NFT marketplace on Sui with collection-based minting, fixed-price listings (2.5% fee), creator royalties, and English auctions.

## Building & Testing

```bash
sui move build
sui move test
```

## Modules

- **nft** — collections with max supply, attributes, royalties, Display standard
- **marketplace** — list/buy with platform fee and royalty distribution
- **auction** — time-based English auction with auto-refund

## License

MIT with attribution — see [LICENSE](LICENSE).
