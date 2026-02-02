/*
 * Copyright (c) 2025 Bima Kharisma Wicaksana
 * GitHub: https://github.com/bimakw
 *
 * Licensed under MIT License with Attribution Requirement.
 * See LICENSE file for details.
 */

/// NFT Module - ERC-721 equivalent for Sui blockchain.
/// Supports minting, transfers, and collection management.
module sui_nft_marketplace::nft {
    use sui::object::{Self, UID, ID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::event;
    use sui::url::{Self, Url};
    use sui::package;
    use sui::display;
    use std::string::{Self, String};

    /// One-Time-Witness for Display
    public struct NFT has drop {}

    /// NFT object
    public struct CollectionNFT has key, store {
        id: UID,
        name: String,
        description: String,
        image_url: Url,
        collection_id: ID,
        token_id: u64,
        creator: address,
        attributes: vector<Attribute>,
    }

    /// NFT Attribute (trait)
    public struct Attribute has store, copy, drop {
        key: String,
        value: String,
    }

    /// Collection metadata
    public struct Collection has key {
        id: UID,
        name: String,
        description: String,
        creator: address,
        total_supply: u64,
        max_supply: u64,
        royalty_bps: u64, // Basis points (100 = 1%)
    }

    /// Mint capability for a collection
    public struct MintCap has key, store {
        id: UID,
        collection_id: ID,
    }

    /// Events
    public struct NFTMinted has copy, drop {
        nft_id: ID,
        collection_id: ID,
        token_id: u64,
        creator: address,
        recipient: address,
    }

    public struct NFTTransferred has copy, drop {
        nft_id: ID,
        from: address,
        to: address,
    }

    public struct NFTBurned has copy, drop {
        nft_id: ID,
        owner: address,
    }

    public struct CollectionCreated has copy, drop {
        collection_id: ID,
        name: String,
        creator: address,
        max_supply: u64,
    }

    /// Error codes
    const EMaxSupplyReached: u64 = 0;
    const ENotMintCap: u64 = 1;

    /// Initialize display template
    fun init(otw: NFT, ctx: &mut TxContext) {
        let keys = vector[
            string::utf8(b"name"),
            string::utf8(b"description"),
            string::utf8(b"image_url"),
            string::utf8(b"creator"),
            string::utf8(b"collection"),
        ];

        let values = vector[
            string::utf8(b"{name}"),
            string::utf8(b"{description}"),
            string::utf8(b"{image_url}"),
            string::utf8(b"{creator}"),
            string::utf8(b"Collection #{token_id}"),
        ];

        let publisher = package::claim(otw, ctx);
        let mut display = display::new_with_fields<CollectionNFT>(
            &publisher, keys, values, ctx
        );

        display::update_version(&mut display);
        transfer::public_transfer(publisher, tx_context::sender(ctx));
        transfer::public_transfer(display, tx_context::sender(ctx));
    }

    /// Create a new collection
    public entry fun create_collection(
        name: vector<u8>,
        description: vector<u8>,
        max_supply: u64,
        royalty_bps: u64,
        ctx: &mut TxContext
    ) {
        let creator = tx_context::sender(ctx);

        let collection = Collection {
            id: object::new(ctx),
            name: string::utf8(name),
            description: string::utf8(description),
            creator,
            total_supply: 0,
            max_supply,
            royalty_bps,
        };

        let mint_cap = MintCap {
            id: object::new(ctx),
            collection_id: object::id(&collection),
        };

        event::emit(CollectionCreated {
            collection_id: object::id(&collection),
            name: collection.name,
            creator,
            max_supply,
        });

        transfer::share_object(collection);
        transfer::transfer(mint_cap, creator);
    }

    /// Mint NFT from collection
    public entry fun mint(
        mint_cap: &MintCap,
        collection: &mut Collection,
        name: vector<u8>,
        description: vector<u8>,
        image_url: vector<u8>,
        recipient: address,
        ctx: &mut TxContext
    ) {
        assert!(mint_cap.collection_id == object::id(collection), ENotMintCap);
        assert!(collection.total_supply < collection.max_supply, EMaxSupplyReached);

        collection.total_supply = collection.total_supply + 1;
        let token_id = collection.total_supply;

        let nft = CollectionNFT {
            id: object::new(ctx),
            name: string::utf8(name),
            description: string::utf8(description),
            image_url: url::new_unsafe_from_bytes(image_url),
            collection_id: object::id(collection),
            token_id,
            creator: collection.creator,
            attributes: vector::empty(),
        };

        event::emit(NFTMinted {
            nft_id: object::id(&nft),
            collection_id: object::id(collection),
            token_id,
            creator: collection.creator,
            recipient,
        });

        transfer::public_transfer(nft, recipient);
    }

    /// Mint with attributes
    public entry fun mint_with_attributes(
        mint_cap: &MintCap,
        collection: &mut Collection,
        name: vector<u8>,
        description: vector<u8>,
        image_url: vector<u8>,
        attr_keys: vector<vector<u8>>,
        attr_values: vector<vector<u8>>,
        recipient: address,
        ctx: &mut TxContext
    ) {
        assert!(mint_cap.collection_id == object::id(collection), ENotMintCap);
        assert!(collection.total_supply < collection.max_supply, EMaxSupplyReached);

        collection.total_supply = collection.total_supply + 1;
        let token_id = collection.total_supply;

        let mut attributes = vector::empty<Attribute>();
        let len = vector::length(&attr_keys);
        let mut i = 0;

        while (i < len) {
            let key = string::utf8(*vector::borrow(&attr_keys, i));
            let value = string::utf8(*vector::borrow(&attr_values, i));
            vector::push_back(&mut attributes, Attribute { key, value });
            i = i + 1;
        };

        let nft = CollectionNFT {
            id: object::new(ctx),
            name: string::utf8(name),
            description: string::utf8(description),
            image_url: url::new_unsafe_from_bytes(image_url),
            collection_id: object::id(collection),
            token_id,
            creator: collection.creator,
            attributes,
        };

        event::emit(NFTMinted {
            nft_id: object::id(&nft),
            collection_id: object::id(collection),
            token_id,
            creator: collection.creator,
            recipient,
        });

        transfer::public_transfer(nft, recipient);
    }

    /// Transfer NFT
    public entry fun transfer_nft(
        nft: CollectionNFT,
        recipient: address,
        ctx: &TxContext
    ) {
        let sender = tx_context::sender(ctx);

        event::emit(NFTTransferred {
            nft_id: object::id(&nft),
            from: sender,
            to: recipient,
        });

        transfer::public_transfer(nft, recipient);
    }

    /// Burn NFT
    public entry fun burn(nft: CollectionNFT, ctx: &TxContext) {
        let sender = tx_context::sender(ctx);

        event::emit(NFTBurned {
            nft_id: object::id(&nft),
            owner: sender,
        });

        let CollectionNFT {
            id,
            name: _,
            description: _,
            image_url: _,
            collection_id: _,
            token_id: _,
            creator: _,
            attributes: _,
        } = nft;

        object::delete(id);
    }

    /// View functions
    public fun name(nft: &CollectionNFT): String { nft.name }
    public fun description(nft: &CollectionNFT): String { nft.description }
    public fun image_url(nft: &CollectionNFT): Url { nft.image_url }
    public fun token_id(nft: &CollectionNFT): u64 { nft.token_id }
    public fun creator(nft: &CollectionNFT): address { nft.creator }
    public fun collection_id(nft: &CollectionNFT): ID { nft.collection_id }

    public fun collection_name(collection: &Collection): String { collection.name }
    public fun collection_creator(collection: &Collection): address { collection.creator }
    public fun total_supply(collection: &Collection): u64 { collection.total_supply }
    public fun max_supply(collection: &Collection): u64 { collection.max_supply }
    public fun royalty_bps(collection: &Collection): u64 { collection.royalty_bps }
}
