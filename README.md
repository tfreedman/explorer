# README

This is a MIT-licensed cryptocurrency block explorer, with support for Bitcoin/Dogecoin/Litecoin/etc. If it's a fork of Bitcoin, it will probably work out of the box.

Unlike other block explorers that are also brand new nodes, this one performs all lookups using JSON RPC calls to the original currency daemon. This means that there's no code for doing things like validating a block, validating transactions, or connecting to other users, making the probability of a hard fork (a difference in output or behaviour between bitcoind and my code) essentially zero. When you ask 'show me block #123456', this explorer will ask bitcoind for the block info, and rely on bitcoind to have accepted it / rejected it. If bitcoind returns data, this means that the block was valid and accepted, and this explorer will format the output.

This explorer also includes explicit support for Namecoin, which is a fork of Bitcoin with the ability to store arbitrary data in the blockchain, (usually .bit domain names). This explorer supports browsing and querying Namecoin data, provided that the configuration value for COIN_NAME is set to Namecoin.

## Database info:

Unfortunately, bitcoind doesn't support any means of querying an address, unless it's your own. Adding an address to bitcoind to get the balance takes a while, as it has to re-index the blockchain to find transactions corresponding to that address. This isn't acceptable, as most people want to check balances of specific addresses. Why it isn't included is beyond my comprehension, but whatever.

To work around this, we have to use our own database, and ask bitcoind about every block (and then in turn every single transaction in each block), writing down the inputs and outputs. When a user wants to find out the balance for a wallet, we can then query our index for transactions involving that address, and return the relevant rows. To do this, a copy of postgres (or any other database supported by ActiveRecord) is required, in addition to the LevelDB database used by bitcoind. Then you'll have to generate an index, which is a slow process taking multiple days. If data hasn't been indexed, a warning will show up on address lookup pages stating that the data it has is incomplete. The good news is that an initial index only has to be done once - subsequent updates are super fast, as only the latest block data has to be added.

Sample config/application.yml - replace values as necessary: 

COIN_NAME: 'Namecoin'
COIN_SYMBOL: 'NMC'
DAEMON_NAME: 'namecoind'
CLI: '/mnt/blockchains/namecoin/namecoin-0.13.99/bin/namecoin-cli'
RPC_USER: 'SAMPLE'
RPC_PASSWORD: 'SAMPLE'
RPC_PORT: 'SAMPLE'
SITE_TITLE_TEXT: 'My Namecoin Block Explorer'
SITE_HEADING: 'My Namecoin'
SITE_SUBTITLE: 'Block Explorer'
DATABASE_NAME: 'SAMPLE'
DATABASE_USERNAME: 'SAMPLE'
DATABASE_PASSWORD: 'SAMPLE'
DATABASE_HOST: 'SAMPLE'

BACKGROUND_COLOR_TOP: '#22cdd5'
BACKGROUND_COLOR_BOTTOM: '#052443'

TEXT_COLOR: '#052443'
TEXT_LINK_COLOR: '#22cdd5'

COINMARKETCAP_CURRENCY_ID: '3'
