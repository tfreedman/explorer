Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

  get '/tick' => 'application#tick'
  get '/block/:block' => 'application#block', :constraints => { :block => /[A-Za-z0-9]+/ }
  get '/tx/:transaction' => 'application#transaction', :constraints => { :transaction => /[A-Za-z0-9]+/ }
  get '/address/:address' => 'application#address', :constraints => { :address => /[A-Za-z0-9]+/ }
  get '/name/:name' => 'application#name', :constraints => { :name => /.*/ }
  post '/search' => 'application#search', :constraints => { :query => /[A-Za-z0-9]+/ }

  get '/api' => 'application#api'
  get '/api/getbestblockhash' => 'application#api_getbestblockhash'
  get '/api/getblockchaininfo' => 'application#api_getblockchaininfo'
  get '/api/getdifficulty' => 'application#api_getdifficulty'
  get '/api/getmempoolinfo' => 'application#api_getmempoolinfo'
  get '/api/getinfo' => 'application#api_getinfo'
  get '/api/getmininginfo' => 'application#api_getmininginfo'
  get '/api/ping' => 'application#api_ping'
  get '/api/listbanned' => 'application#api_listbanned'
  get '/api/getpeerinfo' => 'application#api_getpeerinfo'
  get '/api/getnetworkinfo' => 'application#api_getnetworkinfo'
  get '/api/getchaintips' => 'application#api_getchaintips'
  get '/api/getblockcount' => 'application#api_getblockcount'
  get '/api/getnettotals' => 'application#api_getnettotals'
  get '/api/getconnectioncount' => 'application#api_getconnectioncount'
  get '/api/gettxoutsetinfo' => 'application#api_gettxoutsetinfo'

  get '/api/getblockhash/:index' => 'application#api_getblockhash', :constraints => { :index => /[0-9]+/ }
  get '/api/getblock/:hash' => 'application#api_getblock', :constraints => { :hash => /[A-Fa-f0-9]+/ }
  get '/api/getblockheader/:hash' => 'application#api_getblockheader', :constraints => { :hash => /[A-Fa-f0-9]+/ }
  get '/api/getmempoolancestors/:txid' => 'application#api_getmempoolancestors', :constraints => { :txid => /[A-Fa-f0-9]+/ }
  get '/api/getmempoolentry/:txid' => 'application#api_getmempoolentry', :constraints => { :txid => /[A-Fa-f0-9]+/ }
  get '/api/getmempooldescendants/:txid' => 'application#api_getmempooldescendants', :constraints => { :txid => /[A-Fa-f0-9]+/ }
  get '/api/getrawmempool' => 'application#api_getrawmempool'

  get '/api/name_history/:name' => 'application#api_namehistory', :constraints => { :name => /.*/ }
  get '/api/name_pending' => 'application#api_namepending'
  get '/api/name_pending/:name' => 'application#api_namepending', :constraints => { :name => /.*/ }
  get '/api/name_show/:name' => 'application#api_nameshow', :constraints => { :name => /.*/ }

  get '/api/getrawtransaction/:txid' => 'application#api_getrawtransaction'
  get '/api/getrawtransaction/:txid/:verbose' => 'application#api_getrawtransaction'

  post '/api/sendrawtransaction' => 'application#api_sendrawtransaction'
  post '/api/decoderawtransaction' => 'application#api_decoderawtransaction'
  post '/api/decodescript' => 'application#api_decodescript'

  get '/api/utxo/:address' => 'application#api_utxo'
  get '/api/gettransactionsbyaddress/:address' => 'application#api_gettransactionsbyaddress'

  get '/api/estimatefee/:blocks' => 'application#api_estimatefee'
  get '/api/estimatepriority/:blocks' => 'application#api_estimatepriority'
  get '/api/estimatesmartfee/:blocks' => 'application#api_estimatesmartfee'
  get '/api/estimatesmartpriority/:blocks' => 'application#api_estimatesmartpriority'

  get '/' => 'application#home'
end
