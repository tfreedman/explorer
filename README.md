# README

This is a MIT-licensed cryptocurrency block explorer, with support for Bitcoin/Dogecoin/Litecoin/etc. If it's a fork of Bitcoin, it will probably work out of the box.

Unlike other block explorers that are also brand new nodes, this one performs all lookups using JSON RPC calls to the original currency daemon. This means that there's no code for doing things like validating a block, validating transactions, or connecting to other users, making the probability of a hard fork (a difference in output or behaviour between bitcoind and my code) essentially zero. When you ask 'show me block #123456', this explorer will ask bitcoind for the block info, and rely on bitcoind to have accepted it / rejected it. If bitcoind returns data, this means that the block was valid and accepted, and this explorer will format the output.

This explorer also includes explicit support for Namecoin, which is a fork of Bitcoin with the ability to store arbitrary data in the blockchain, (usually .bit domain names). This explorer supports browsing and querying Namecoin data, provided that the configuration value for COIN_NAME is set to Namecoin.

## Setup:

I strongly recommend following https://www.digitalocean.com/community/tutorials/how-to-install-ruby-on-rails-with-rvm-on-ubuntu-16-04, which covers getting started with Ruby, Rails, and RVM. RVM will keep you from running into dependency hell, because the exact version of Ruby that I was using when I developed this will be automatically invoked by RVM. You can use a different distro of Linux if you want, but I can't help you with it if you run into any problems. Once everything has been installed, you should be able to clone this repository, cd into the folder, and run:

```
gem install bundler
bundler install
```

To determine if you've gotten it (mostly) set up correctly, you should be able to run ```rails c```, and get dropped into a console. If you get any errors, something isn't installed correctly - the biggest culprits tend to be gems that require native extensions (generally, C libraries and a compiler) before installing. If you get an error for one of these, I suggest googling it - the solution almost always consists of apt-getting some library, then running ```bundle install``` again. Afterwards, you should also be able to browse to the home page (after running ```rails s```, to actually launch a web server), search for a transaction / block, and more. You won't be able to search by address for a while, until the explorer has finished indexing all relevant transactions - this process can take several days or weeks to complete, depending on the cryptocurrency, but most other functionality will work just fine.

To create the database, you'll need to run ```rails db:structure:load```. This will create an empty database for you, along with the indexes required to do fast searches by address, UTXO, and more. Ensure that you've set up a config/application.yml file (from below) before running this command, otherwise it won't have a DB to actually write to.

Once it's running, you'll need to have it index the blockchain, in order to browse /address/ pages, or use the UTXO / balance APIs. Since the initial index will take a while, I suggest running:

```rails c```

```
x = ApplicationController.new
while true do
  begin
    x.generate_address_index
  rescue Parallel::DeadWorker, Parallel::UndumpableException
    ActiveRecord::Base.establish_connection
    File.delete('indexer.lock')
  end
  sleep(10)
end
```

This will effectively tell it to run as fast as it can, indexing every block it knows about, and restart in case of any failure whatsoever. Afterwards, when the initial sync is complete, I suggest creating a service to automatically run the file 'indexer' - it's a bash script that will just loop infinitely and scan any new blocks that have come in.

The indexer ensures that new blocks are automatically indexed as they come in, and old blocks are automatically indexed when the site notices that they're missing. It is perfectly fine if the process of indexing is interrupted, as relaunching the indexer will delete any incomplete work (half-finished blocks) before attempting that block again.

If you don't want to keep a terminal open to run the site (```rails s```, on port 3000), I suggest setting up Phusion Passenger and Nginx, which seems to be the preferred way to run Rails sites (https://www.phusionpassenger.com/library/install/nginx/install/oss/xenial/).

## Missing Transactions:

The indexer is designed to go block-by-block, look at every transaction within each block, and write down each payment that was made within each transaction. Occasionally, a transaction will be encountered that can not be decoded - these can happen for a few reasons:

- A bug in the explorer
- A bug in the daemon
- Unsupported transaction format (SegWit support is coming soon)
- JSON RPC errors

The TXID of an invalid transaction is recorded, so that it can be re-checked later on (and indexing can continue on the remaining valid transactions). The indexer currently doesn't attempt to re-check invalid transactions when it attempts re-indexing again, but it will shortly.

If a transaction is marked as invalid, that just means that the explorer cannot use it in the separate indexes it maintains. If that transaction pays to another transaction which is accepted by the explorer, that transaction will be recorded, because the explorer doesn't rely on historical transactions to validate new transactions.

## Database info:

Unfortunately, bitcoind doesn't support any means of querying an address, unless it's your own. Adding an address to bitcoind to get the balance takes a while, as it has to re-index the blockchain to find transactions corresponding to that address. This isn't acceptable, as most people want to check balances of specific addresses. Why it isn't included is beyond my comprehension, but whatever.

To work around this, we have to use our own database, and ask bitcoind about every block (and then in turn every single transaction in each block), writing down the inputs and outputs. When a user wants to find out the balance for a wallet, we can then query our index for transactions involving that address, and return the relevant rows. To do this, a copy of postgres (or any other database supported by ActiveRecord) is required, in addition to the LevelDB database used by bitcoind. Then you'll have to generate an index, which is a slow process taking multiple days. If data hasn't been indexed, a warning will show up on address lookup pages stating that the data it has is incomplete. The good news is that an initial index only has to be done once - subsequent updates are super fast, as only the latest block data has to be added.

## Configuration Options:

All of the explorer's configuration options are set in config/application.yml - these include the path to the daemon (and username/password/port), cosmetic options (colors), and the site name itself.

Notably missing from this file are any configuration options for the cryptocurrency daemon itself. If you're looking to change settings for that, I suggest launching the daemon with the -conf parameter, which tells it to open a file to read settings instead of expecting them on the command line. For example, launching Namecoin with:

```/mnt/blockchains/namecoin/namecoin-0.13.99/bin/namecoind -conf=/home/ubuntu/.namecoin/namecoin.conf```

Tells it to read the configuration options for namecoind from that file, where we can do things like set it to testnet, change the port, add additional indexes, and change the data directory. By making changes here (and not to the explorer's source code), we don't have to worry about code change conflicts. Here's a sample namecoin.conf configuration:

```$ cat ~/.namecoin/namecoin.conf
rpcuser=XXX
rpcpassword=YYY
rpcport=ZZZZ
txindex=1
daemon=1
namehistory=1
datadir=/mnt/blockchains/namecoin/data
rpcthreads=8
rpcworkqueue=160
rpctimeout=300
```

And here's a sample ```config/application.yml``` - replace values as necessary: 

- COIN_NAME: 'Namecoin'
- COIN_SYMBOL: 'NMC'
- DAEMON_NAME: 'namecoind'
- CLI: '/mnt/blockchains/namecoin/namecoin-0.13.99/bin/namecoin-cli'
- RPC_USER: 'XXX'
- RPC_PASSWORD: 'YYY'
- RPC_PORT: 'ZZZZ'
- SITE_TITLE_TEXT: 'My Namecoin Block Explorer'
- SITE_HEADING: 'My Namecoin'
- SITE_SUBTITLE: 'Block Explorer'
- DATABASE_NAME: 'SAMPLE'
- DATABASE_USERNAME: 'SAMPLE'
- DATABASE_PASSWORD: 'SAMPLE'
- DATABASE_HOST: 'SAMPLE'
- BACKGROUND_COLOR_TOP: '#22cdd5'
- BACKGROUND_COLOR_BOTTOM: '#052443'
- TEXT_COLOR: '#052443'
- TEXT_LINK_COLOR: '#22cdd5'
- COINMARKETCAP_CURRENCY_ID: '3'
