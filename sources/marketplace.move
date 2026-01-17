/*
 * Copyright (c) 2024 Bima Kharisma Wicaksana
 * GitHub: https://github.com/bimakw
 *
 * Licensed under MIT License with Attribution Requirement.
 * See LICENSE file for details.
 */

/// Marketplace Module - Decentralized NFT marketplace on Sui.
/// Supports listings, purchases, and royalty distribution.
module sui_nft_marketplace::marketplace {
    use sui::object::{Self, UID, ID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::event;
    use sui::dynamic_object_field as dof;

    use sui_nft_marketplace::nft::{Self, CollectionNFT, Collection};

    /// Error codes
    const ENotOwner: u64 = 0;
    const EInsufficientPayment: u64 = 1;
    const EListingNotActive: u64 = 2;
    const EInvalidPrice: u64 = 3;

    /// Marketplace fee in basis points (250 = 2.5%)
    const MARKETPLACE_FEE_BPS: u64 = 250;

    /// Marketplace state
    public struct Marketplace has key {
        id: UID,
        fee_recipient: address,
        total_volume: u64,
        total_listings: u64,
    }

    /// Listing object that holds the NFT
    public struct Listing has key, store {
        id: UID,
        nft_id: ID,
        seller: address,
        price: u64,
        collection_id: ID,
    }

    /// Events
    public struct ItemListed has copy, drop {
        listing_id: ID,
        nft_id: ID,
        seller: address,
        price: u64,
        collection_id: ID,
    }

    public struct ItemSold has copy, drop {
        listing_id: ID,
        nft_id: ID,
        seller: address,
        buyer: address,
        price: u64,
    }

    public struct ItemDelisted has copy, drop {
        listing_id: ID,
        nft_id: ID,
        seller: address,
    }

    public struct PriceUpdated has copy, drop {
        listing_id: ID,
        old_price: u64,
        new_price: u64,
    }

    /// Initialize marketplace
    fun init(ctx: &mut TxContext) {
        let marketplace = Marketplace {
            id: object::new(ctx),
            fee_recipient: tx_context::sender(ctx),
            total_volume: 0,
            total_listings: 0,
        };

        transfer::share_object(marketplace);
    }

    /// List NFT for sale
    public entry fun list(
        marketplace: &mut Marketplace,
        nft: CollectionNFT,
        price: u64,
        ctx: &mut TxContext
    ) {
        assert!(price > 0, EInvalidPrice);

        let seller = tx_context::sender(ctx);
        let nft_id = object::id(&nft);
        let collection_id = nft::collection_id(&nft);

        let mut listing = Listing {
            id: object::new(ctx),
            nft_id,
            seller,
            price,
            collection_id,
        };

        // Store NFT in listing using dynamic object field
        dof::add(&mut listing.id, true, nft);

        marketplace.total_listings = marketplace.total_listings + 1;

        event::emit(ItemListed {
            listing_id: object::id(&listing),
            nft_id,
            seller,
            price,
            collection_id,
        });

        transfer::share_object(listing);
    }

    /// Purchase listed NFT
    public entry fun buy(
        marketplace: &mut Marketplace,
        listing: Listing,
        collection: &Collection,
        mut payment: Coin<SUI>,
        ctx: &mut TxContext
    ) {
        let buyer = tx_context::sender(ctx);
        let payment_amount = coin::value(&payment);

        assert!(payment_amount >= listing.price, EInsufficientPayment);

        // Calculate fees
        let price = listing.price;
        let marketplace_fee = (price * MARKETPLACE_FEE_BPS) / 10000;
        let royalty_fee = (price * nft::royalty_bps(collection)) / 10000;
        let seller_amount = price - marketplace_fee - royalty_fee;

        // Split and distribute payments
        let marketplace_coin = coin::split(&mut payment, marketplace_fee, ctx);
        transfer::public_transfer(marketplace_coin, marketplace.fee_recipient);

        if (royalty_fee > 0) {
            let royalty_coin = coin::split(&mut payment, royalty_fee, ctx);
            transfer::public_transfer(royalty_coin, nft::collection_name(collection)); // In real impl, use creator address
        };

        let seller_coin = coin::split(&mut payment, seller_amount, ctx);
        transfer::public_transfer(seller_coin, listing.seller);

        // Return excess payment
        if (coin::value(&payment) > 0) {
            transfer::public_transfer(payment, buyer);
        } else {
            coin::destroy_zero(payment);
        };

        // Extract and transfer NFT
        let Listing { id, nft_id, seller, price: _, collection_id: _ } = listing;
        let nft: CollectionNFT = dof::remove(&mut id, true);

        marketplace.total_volume = marketplace.total_volume + price;

        event::emit(ItemSold {
            listing_id: object::uid_to_inner(&id),
            nft_id,
            seller,
            buyer,
            price,
        });

        object::delete(id);
        transfer::public_transfer(nft, buyer);
    }

    /// Cancel listing and reclaim NFT
    public entry fun delist(
        listing: Listing,
        ctx: &TxContext
    ) {
        let sender = tx_context::sender(ctx);
        assert!(listing.seller == sender, ENotOwner);

        let Listing { mut id, nft_id, seller, price: _, collection_id: _ } = listing;
        let nft: CollectionNFT = dof::remove(&mut id, true);

        event::emit(ItemDelisted {
            listing_id: object::uid_to_inner(&id),
            nft_id,
            seller,
        });

        object::delete(id);
        transfer::public_transfer(nft, sender);
    }

    /// Update listing price
    public entry fun update_price(
        listing: &mut Listing,
        new_price: u64,
        ctx: &TxContext
    ) {
        let sender = tx_context::sender(ctx);
        assert!(listing.seller == sender, ENotOwner);
        assert!(new_price > 0, EInvalidPrice);

        let old_price = listing.price;
        listing.price = new_price;

        event::emit(PriceUpdated {
            listing_id: object::id(listing),
            old_price,
            new_price,
        });
    }

    /// View functions
    public fun get_price(listing: &Listing): u64 { listing.price }
    public fun get_seller(listing: &Listing): address { listing.seller }
    public fun get_nft_id(listing: &Listing): ID { listing.nft_id }
    public fun total_volume(marketplace: &Marketplace): u64 { marketplace.total_volume }
    public fun total_listings(marketplace: &Marketplace): u64 { marketplace.total_listings }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }
}
