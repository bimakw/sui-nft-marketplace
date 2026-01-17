# Sui NFT Marketplace

A decentralized NFT marketplace built on Sui blockchain with collection management, fixed-price listings, and English auctions.

## Tech Stack

- **Language**: Move
- **Blockchain**: Sui Network
- **Features**: NFT minting, marketplace, auctions

## Modules

| Module | Description |
|--------|-------------|
| `nft` | NFT minting with collections, attributes, and royalties |
| `marketplace` | Fixed-price listings with fee distribution |
| `auction` | English auctions with time-based bidding |

## Features

- **Collection-based NFTs**: Create collections with max supply and royalties
- **Attributes Support**: Add metadata/traits to NFTs
- **Marketplace Fees**: 2.5% platform fee on sales
- **Royalty Distribution**: Creator royalties on secondary sales
- **English Auctions**: Time-based bidding with auto-refund
- **Display Standard**: Sui Display for wallet/explorer rendering

## Prerequisites

```bash
# Install Sui CLI
cargo install --locked --git https://github.com/MystenLabs/sui.git --branch devnet sui

# Setup wallet
sui client new-address ed25519
sui client faucet
```

## Quick Start

```bash
# Clone repository
git clone https://github.com/bimakw/sui-nft-marketplace.git
cd sui-nft-marketplace

# Build
sui move build

# Test
sui move test

# Deploy
sui client publish --gas-budget 100000000
```

## Usage

### Create Collection

```bash
sui client call --package $PACKAGE --module nft --function create_collection \
  --args "My Collection" "A cool NFT collection" 10000 500 \
  --gas-budget 10000000

# Args: name, description, max_supply, royalty_bps (500 = 5%)
```

### Mint NFT

```bash
sui client call --package $PACKAGE --module nft --function mint \
  --args $MINT_CAP $COLLECTION "NFT #1" "Description" "https://example.com/1.png" $RECIPIENT \
  --gas-budget 10000000
```

### List for Sale

```bash
sui client call --package $PACKAGE --module marketplace --function list \
  --args $MARKETPLACE $NFT 1000000000 \
  --gas-budget 10000000

# Price in MIST (1 SUI = 1_000_000_000 MIST)
```

### Buy NFT

```bash
sui client call --package $PACKAGE --module marketplace --function buy \
  --args $MARKETPLACE $LISTING $COLLECTION $COIN \
  --gas-budget 10000000
```

### Create Auction

```bash
sui client call --package $PACKAGE --module auction --function create_auction \
  --args $NFT 500000000 86400000 0x6 \
  --gas-budget 10000000

# Args: nft, start_price, duration_ms (86400000 = 24 hours), clock
```

### Place Bid

```bash
sui client call --package $PACKAGE --module auction --function place_bid \
  --args $AUCTION $COIN 0x6 \
  --gas-budget 10000000
```

### Finalize Auction

```bash
sui client call --package $PACKAGE --module auction --function finalize \
  --args $AUCTION 0x6 \
  --gas-budget 10000000
```

## Architecture

```
sui-nft-marketplace/
├── sources/
│   ├── nft.move         # NFT & Collection logic
│   ├── marketplace.move # Fixed-price marketplace
│   └── auction.move     # English auction
├── tests/
├── Move.toml
└── README.md
```

## Fee Structure

| Fee Type | Amount | Recipient |
|----------|--------|-----------|
| Marketplace Fee | 2.5% | Platform |
| Creator Royalty | Configurable | Collection Creator |

## Events

The contracts emit events for:
- `CollectionCreated` - New collection deployed
- `NFTMinted` - New NFT minted
- `ItemListed` - NFT listed for sale
- `ItemSold` - NFT purchased
- `BidPlaced` - New bid on auction
- `AuctionFinalized` - Auction completed

## Security Considerations

- NFTs stored using Dynamic Object Fields
- Automatic refund for outbid participants
- Time-based auction with clock verification
- Seller-only cancellation (no bids)
- Proper access control with capabilities

## Testing

```bash
# Run all tests
sui move test

# Run specific test
sui move test marketplace_tests

# With verbose output
sui move test -v
```

## License

MIT License with Attribution - See [LICENSE](LICENSE)

Copyright (c) 2024 Bima Kharisma Wicaksana
