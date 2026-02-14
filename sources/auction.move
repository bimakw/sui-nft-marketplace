module sui_nft_marketplace::auction {
    use sui::object::{Self, UID, ID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::balance::{Self, Balance};
    use sui::clock::{Self, Clock};
    use sui::event;
    use sui::dynamic_object_field as dof;

    use sui_nft_marketplace::nft::CollectionNFT;

    const EAuctionNotStarted: u64 = 0;
    const EAuctionEnded: u64 = 1;
    const EAuctionNotEnded: u64 = 2;
    const EBidTooLow: u64 = 3;
    const ENotSeller: u64 = 4;
    const ENoBids: u64 = 5;
    const EAuctionActive: u64 = 6;

    const MIN_BID_INCREMENT_BPS: u64 = 500;

    public struct Auction has key {
        id: UID,
        nft_id: ID,
        seller: address,
        start_price: u64,
        current_bid: u64,
        highest_bidder: address,
        start_time: u64,
        end_time: u64,
        bid_balance: Balance<SUI>,
        finalized: bool,
    }

    public struct AuctionCreated has copy, drop {
        auction_id: ID,
        nft_id: ID,
        seller: address,
        start_price: u64,
        start_time: u64,
        end_time: u64,
    }

    public struct BidPlaced has copy, drop {
        auction_id: ID,
        bidder: address,
        amount: u64,
        previous_bidder: address,
        previous_bid: u64,
    }

    public struct AuctionFinalized has copy, drop {
        auction_id: ID,
        winner: address,
        final_price: u64,
    }

    public struct AuctionCancelled has copy, drop {
        auction_id: ID,
        nft_id: ID,
    }

    public entry fun create_auction(
        nft: CollectionNFT,
        start_price: u64,
        duration_ms: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let seller = tx_context::sender(ctx);
        let nft_id = object::id(&nft);
        let start_time = clock::timestamp_ms(clock);
        let end_time = start_time + duration_ms;

        let mut auction = Auction {
            id: object::new(ctx),
            nft_id,
            seller,
            start_price,
            current_bid: 0,
            highest_bidder: @0x0,
            start_time,
            end_time,
            bid_balance: balance::zero(),
            finalized: false,
        };

        dof::add(&mut auction.id, true, nft);

        event::emit(AuctionCreated {
            auction_id: object::id(&auction),
            nft_id,
            seller,
            start_price,
            start_time,
            end_time,
        });

        transfer::share_object(auction);
    }

    public entry fun place_bid(
        auction: &mut Auction,
        mut payment: Coin<SUI>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let current_time = clock::timestamp_ms(clock);
        let bidder = tx_context::sender(ctx);

        assert!(current_time >= auction.start_time, EAuctionNotStarted);
        assert!(current_time < auction.end_time, EAuctionEnded);
        assert!(!auction.finalized, EAuctionEnded);

        let bid_amount = coin::value(&payment);

        let min_bid = if (auction.current_bid == 0) {
            auction.start_price
        } else {
            auction.current_bid + (auction.current_bid * MIN_BID_INCREMENT_BPS) / 10000
        };

        assert!(bid_amount >= min_bid, EBidTooLow);

        let previous_bidder = auction.highest_bidder;
        let previous_bid = auction.current_bid;

        if (previous_bid > 0 && previous_bidder != @0x0) {
            let refund = coin::from_balance(
                balance::withdraw_all(&mut auction.bid_balance),
                ctx
            );
            transfer::public_transfer(refund, previous_bidder);
        };

        let bid_balance = coin::into_balance(coin::split(&mut payment, bid_amount, ctx));
        balance::join(&mut auction.bid_balance, bid_balance);

        auction.current_bid = bid_amount;
        auction.highest_bidder = bidder;

        if (coin::value(&payment) > 0) {
            transfer::public_transfer(payment, bidder);
        } else {
            coin::destroy_zero(payment);
        };

        event::emit(BidPlaced {
            auction_id: object::id(auction),
            bidder,
            amount: bid_amount,
            previous_bidder,
            previous_bid,
        });
    }

    public entry fun finalize(
        auction: &mut Auction,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let current_time = clock::timestamp_ms(clock);

        assert!(current_time >= auction.end_time, EAuctionNotEnded);
        assert!(!auction.finalized, EAuctionEnded);
        assert!(auction.current_bid > 0, ENoBids);

        auction.finalized = true;

        let payment = coin::from_balance(
            balance::withdraw_all(&mut auction.bid_balance),
            ctx
        );
        transfer::public_transfer(payment, auction.seller);

        let nft: CollectionNFT = dof::remove(&mut auction.id, true);

        event::emit(AuctionFinalized {
            auction_id: object::id(auction),
            winner: auction.highest_bidder,
            final_price: auction.current_bid,
        });

        transfer::public_transfer(nft, auction.highest_bidder);
    }

    public entry fun cancel_auction(
        auction: Auction,
        ctx: &TxContext
    ) {
        let sender = tx_context::sender(ctx);

        assert!(auction.seller == sender, ENotSeller);
        assert!(auction.current_bid == 0, EAuctionActive);
        assert!(!auction.finalized, EAuctionEnded);

        let Auction {
            mut id,
            nft_id,
            seller,
            start_price: _,
            current_bid: _,
            highest_bidder: _,
            start_time: _,
            end_time: _,
            bid_balance,
            finalized: _,
        } = auction;

        let nft: CollectionNFT = dof::remove(&mut id, true);
        balance::destroy_zero(bid_balance);

        event::emit(AuctionCancelled {
            auction_id: object::uid_to_inner(&id),
            nft_id,
        });

        object::delete(id);
        transfer::public_transfer(nft, seller);
    }

    public fun get_current_bid(auction: &Auction): u64 { auction.current_bid }
    public fun get_highest_bidder(auction: &Auction): address { auction.highest_bidder }
    public fun get_end_time(auction: &Auction): u64 { auction.end_time }
    public fun get_start_price(auction: &Auction): u64 { auction.start_price }
    public fun is_finalized(auction: &Auction): bool { auction.finalized }

    public fun get_min_next_bid(auction: &Auction): u64 {
        if (auction.current_bid == 0) {
            auction.start_price
        } else {
            auction.current_bid + (auction.current_bid * MIN_BID_INCREMENT_BPS) / 10000
        }
    }

    public fun is_active(auction: &Auction, clock: &Clock): bool {
        let current_time = clock::timestamp_ms(clock);
        current_time >= auction.start_time &&
        current_time < auction.end_time &&
        !auction.finalized
    }
}
