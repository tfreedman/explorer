class ApplicationController < ActionController::Base
#  protect_from_forgery with: :exception

  def home
    @title = 'Home'
    @output = ApplicationController::cli(['getblockcount']).to_i

    @latest_blocks = Array.new
    blocks = @output - 6
    @output.downto(blocks).each do |n|
      block = ApplicationController::get_block(n)
      total_sent = 0
      block["tx"].each do |txid|
        transaction = get_transaction(txid)
        transaction["vout"].each do |vout|
          total_sent += vout["value"]
        end
      end
      block["total_sent"] = total_sent
      @latest_blocks << block
    end
    if ENV['COIN_NAME'] == 'Namecoin'
      @latest_transactions = JSON.parse(ApplicationController::cli(['name_filter', '^[i]?d/', '6']))
      @latest_transactions.each_with_index do |tx, index|
        @latest_transactions[index]["age"] = ApplicationController::get_block(@latest_transactions[index]["height"])["time"]
        details = get_transaction(@latest_transactions[index]["txid"])
        details["vout"].each do |vout|
          if vout["scriptPubKey"] && vout["scriptPubKey"]["nameOp"] && vout["scriptPubKey"]["nameOp"]["name"] == @latest_transactions[index]["name"]
            @latest_transactions[index]["operation"] = vout["scriptPubKey"]["nameOp"]["op"]
            break
          end
        end
      end
      @latest_transactions = @latest_transactions.sort_by {|k| k["age"]}.reverse
    end
  end

  def api
    @title = 'API'
  end

  # Dynamic routes start here

  def search
    query = params[:query]    
    if query.downcase.start_with?('d/') || query.downcase.start_with?('id/')
      redirect_to "/name/#{query}"
    elsif query.downcase.end_with?('.bit')
      redirect_to "/name/d/#{query[0..-5]}"
    elsif query.length == 64
      redirect_to "/tx/#{query}"
    elsif query.count('g-zG-Z') > 0
      redirect_to "/address/#{query}"
    elsif query.count('a-fA-F') > 0
      redirect_to "/block/#{query}"
    elsif query.count('a-fA-F') == 0
      redirect_to "/block/#{query}"
    else
      redirect_to '/404'
    end
  end

  def block
    @title = "Block #{params[:block]}"
    @output = ApplicationController::get_block(params[:block])

    @name_operations = Array.new
    if ENV['COIN_NAME'] == 'Namecoin'
      txids = @output["tx"]
      txids.each do |txid|
        details = get_transaction(txid)
        details["vout"].each do |vout|
          if vout["scriptPubKey"] && vout["scriptPubKey"]["nameOp"] && vout["scriptPubKey"]["nameOp"]["name"]
            @name_operations << vout["scriptPubKey"]["nameOp"]
            @name_operations[-1]["txid"] = txid
          end
        end
      end
    end

    @output["totals"] = {"output" => 0, "input" => 0}
    @output["tx"].each_with_index do |txid, index|
      @output["tx"][index] = get_transaction(txid, true, true)
      @output["totals"]["output"] += @output["tx"][index]["totals"]["output"]
      @output["totals"]["input"] += @output["tx"][index]["totals"]["input"]
    end
  end

  def transaction
    @title = "Transaction #{params[:transaction]}"
    @output = get_transaction(params[:transaction], true, true)
    @output["height"] = ApplicationController::get_block(@output["blockhash"])["height"]
  end

  def address
    @title = "Address #{params[:address]}"
    @address = Payment.where(address: params[:address]).order('id desc')

    @complete_data = Block.where(ended: true).count == ApplicationController::cli('getblockcount').to_i

    if @address
      @balance = 0
      @address.each do |a|
        @balance += a.credit if a.credit
        @balance -= a.debit if a.debit
        a.balance = @balance
      end
    end
  end

  def name
    @title = "Name #{params[:name]}"
    params[:type] = params[:type].downcase
    params[:name] = params[:name].downcase
    if params[:type] == 'd'
      @output = ApplicationController::cli(['name_show', 'd/' + params[:name]])
      @history = ApplicationController::cli(['name_history', 'd/' + params[:name]])
    elsif params[:type] == 'id'
      @output = ApplicationController::cli(['name_show', 'id/' + params[:name]])
      @history = ApplicationController::cli(['name_history', 'id/' + params[:name]])
    end
      
    if !@output.include?('name not found')
      @output = JSON.parse(@output)
      @history = JSON.parse(@history)

      @history.each_with_index do |transaction, index|
        @history[index]["time"] = ApplicationController::get_block(transaction["height"])["time"]
        details = get_transaction(transaction["txid"])
        details["vout"].each do |vout|
          if vout["scriptPubKey"] && vout["scriptPubKey"]["nameOp"] && vout["scriptPubKey"]["nameOp"]["name"]
            @history[index]["op"] = vout["scriptPubKey"]["nameOp"]["op"]
          end
        end
      end

      @history.reverse!
    else
      @output = nil
      @history = nil
    end
  end

  def tick
    if generate_address_index == :error
      render plain: "Another process is probably indexing already."
    else
      render plain: 'okay'
    end
  end

  def generate_address_index
    ActiveRecord::Base.logger.level = 2

    if File.exist?("indexer.lock")
      $lockfile = YAML.load_file('indexer.lock')
    else
      $lockfile = {last_block_time: 0, pid: Process.ppid, invalid_scan_time: 0}
    end

    begin
      Process.getpgid($lockfile[:pid])
    rescue Errno::ESRCH => e
      # Whatever process previously locked the lockfile is 100% dead, so we can take it over.
      $lockfile[:pid] = Process.ppid
    end

    if $lockfile && $lockfile[:pid] != Process.ppid
      puts "Another process is probably indexing already. Exiting..."
      return :error
    else
      puts "Loading block index..."
      total_blocks = ApplicationController::cli('getblockcount').to_i

      block_array = []

      Block.where(ended: false).find_each do |block|
          Payment.where(blockhash: block.blockhash).find_each do |payment|
              payment.destroy
          end
          block.destroy
      end

      if $lockfile[:invalid_scan_time] + 86400 < Time.now.to_i
        puts "Re-scanning #{InvalidTransaction.count} invalid transactions"
        ActiveRecord::Base.connection_pool.with_connection do
          results = index_transactions(InvalidTransaction.pluck(:transaction_id))
  
          puts "-  #{results[:valid_transactions].count} valid transactions found"
          puts "-  #{results[:invalid_transactions].count} invalid transactions stuck in pool"

          ActiveRecord::Base.transaction do
            InvalidTransaction.destroy_all
            Payment.import results[:payments]
            InvalidTransaction.import results[:invalid_transactions]
          end
        end
        $lockfile[:invalid_scan_time] = Time.now.to_i
        File.write('indexer.lock', $lockfile.to_yaml)
      end

      block_array = (1..total_blocks).to_a - Block.pluck(:height)
      puts "Indexing payments in #{block_array.count} blocks"

      Parallel.map(block_array, isolation: true) do |block|
        ActiveRecord::Base.connection_pool.with_connection do
          results = index_block(block)

          ActiveRecord::Base.transaction do
            Payment.import results[:payments]
            InvalidTransaction.import results[:invalid_transactions]
          end
          $lockfile[:last_block_time] = Time.now.to_i
          File.write('indexer.lock', $lockfile.to_yaml)
        end
      end
      puts "Done indexing all known blocks"
      $lockfile[:pid] = -1 #Not a real PID, so the re-indexer will treat this as a dead process and immediately run again
      File.write('indexer.lock', $lockfile.to_yaml)
    end
  end

  def index_block(height)
    if !Block.where(height: height, started: true, ended: true).first
      block_hash = ApplicationController::cli(['getblockhash', height.to_s]).strip
      b = Block.create(height: height, blockhash: block_hash, started: true)
      txids = JSON.parse(ApplicationController::cli(['getblock', block_hash]))["tx"]
      
      results = index_transactions(txids)

      b.update(ended: true)
      puts height
      return results
    end
  end

  def index_transactions(txids)
    payments = []
    valid_transactions = []
    invalid_transactions = []
    txids.each_with_index do |txid, index|
      begin
        tx = get_transaction(txid, true, false)

        tx["vin"].each_with_index do |vin, vin_index|
          if vin["prevTransaction"]
            if vin["coinbase"].nil?
              vout = vin_index.to_s + "#" + vin["vout"].to_s
            else
              vout = vin["vout"]
            end
            payments << Payment.new(address: vin["prevTransaction"]["vout"][vin["vout"]]["scriptPubKey"]["addresses"][0], txid: tx['txid'], debit: vin["prevTransaction"]["vout"][vin["vout"]]["value"], credit: 0, blockhash: tx["blockhash"], n: vout)
          end
        end

        tx["vout"].each do |vout|
          if vout["scriptPubKey"]["addresses"].nil?
            output_address = "Unknown"
          else
            output_address = vout["scriptPubKey"]["addresses"][0]
          end
          payments << Payment.new(address: output_address, txid: tx['txid'], debit: 0, credit: vout["value"], blockhash: tx["blockhash"], n: vout["n"])
        end
        valid_transactions << txid
      rescue StandardError => e
        puts "FAILED ON TXID #{txid} - #{e}"
        invalid_transactions << InvalidTransaction.new(transaction_id: txid)
      end
    end
    return {payments: payments, valid_transactions: valid_transactions, invalid_transactions: invalid_transactions}
  end

  def self.cli(command)
    require 'open3'
    stdout_and_stderr_str, status = Open3.capture2e({'rpcuser' => ENV['RPC_USER'], 'rpcpassword' => ENV['RPC_PASSWORD'], 'rpcport' => ENV['RPC_PORT'], 'rpcconnect' => ENV['RPC_CONNECT']}, ENV['CLI'], *command)
    return stdout_and_stderr_str
  end

  def get_transaction(txid, include_input_transactions = false, include_totals = false)
    output = JSON.parse(ApplicationController::cli(["getrawtransaction", txid, '1']))
    if include_input_transactions
      output["vin"].each_with_index do |vin, index|
        if vin["txid"]
          output["vin"][index]["prevTransaction"] = get_transaction(vin["txid"])
        end
      end
      if include_totals
        output["totals"] = {"output" => 0, "input" => 0}
        output["vin"].each do |vin|
          if vin["prevTransaction"]
            output["totals"]["input"] += vin["prevTransaction"]["vout"][vin["vout"]]["value"]
          end
        end
        output["vout"].each_with_index do |vout, index|
          output["totals"]["output"] += vout["value"]
        end
      end      
    end
    return output
  end

  def self.get_block(block)
    if block.to_s.count('a-fA-F') > 0
      JSON.parse(ApplicationController::cli(['getblock', block]))
    else
      hash = ApplicationController::cli(['getblockhash', block.to_s])
      JSON.parse(ApplicationController::cli(['getblock', hash]) 
      )
    end
  end

  # API Routes start here

  def api_getbestblockhash
    render plain: ApplicationController::cli('getbestblockhash')
  end

  def api_getblockchaininfo
    render json: ApplicationController::cli('getblockchaininfo')
  end

  def api_getblockcount
    render plain: ApplicationController::cli('getblockcount')
  end

  def api_getdifficulty
    render plain: ApplicationController::cli('getdifficulty')
  end

  def api_getmempoolinfo
    render json: ApplicationController::cli('getmempoolinfo')
  end

  def api_getinfo
    render json: ApplicationController::cli('getinfo')
  end

  def api_getmininginfo
    render json: ApplicationController::cli('getmininginfo')
  end

  def api_ping
    render json: ApplicationController::cli('ping')
  end

  def api_listbanned
    render json: ApplicationController::cli('listbanned')
  end

  def api_getpeerinfo
    render json: ApplicationController::cli('getpeerinfo')
  end

  def api_getnetworkinfo
    render json: ApplicationController::cli('getnetworkinfo')
  end

  def api_getchaintips
    render json: ApplicationController::cli('getchaintips')
  end

  def api_getnettotals
    render json: ApplicationController::cli('getnettotals')
  end

  def api_getconnectioncount
    render json: ApplicationController::cli('getconnectioncount')
  end

  def api_gettxoutsetinfo
    render json: ApplicationController::cli('gettxoutsetinfo')
  end

  def api_getblockhash
    render plain: ApplicationController::cli(['getblockhash', params[:index].to_s])
  end

  def api_getblock
    render json: ApplicationController::cli(['getblock', params[:hash]])
  end

  def api_getblockheader
    render json: ApplicationController::cli(['getblockheader', params[:hash]])
  end

  def api_getmempoolancestors
    render json: ApplicationController::cli(['getmempoolancestors', params[:txid]])
  end

  def api_getmempoolentry
    render json: ApplicationController::cli(['getmempoolentry', params[:txid]])
  end

  def api_getmempooldescendants
    render json: ApplicationController::cli(['getmempooldescendants', params[:txid]])
  end

  def api_getrawmempool
    render json: ApplicationController::cli('getrawmempool')
  end

  def api_namefilter
#    render json: ApplicationController::cli(['name_filter'])
  end

  def api_namehistory
    render json: ApplicationController::cli(['name_history', params[:name]])
  end

  def api_namepending
    render json: ApplicationController::cli(['name_pending', params[:name].to_s])
  end

  def api_nameshow
    render json: ApplicationController::cli(['name_show', params[:name]])
  end

  def api_getrawtransaction
    params[:verbose] = '0' if params[:verbose].nil?
    render plain: ApplicationController::cli(['getrawtransaction', params[:txid], params[:verbose]])
  end

  def api_sendrawtransaction
    render plain: ApplicationController::cli(['sendrawtransaction', params[:hexstring], params[:allowhighfees]])
  end

  def api_decoderawtransaction
    render json: ApplicationController::cli(['decoderawtransaction', params[:hexstring]])
  end

  def api_decodescript
    render json: ApplicationController::cli(['decodescript', params[:hex]])
  end

  def api_gettransactionsbyaddress
    transactions = []
    Payment.where(address: params[:address]).find_each do |a|
      transactions << {txid: a.txid, debit: a.debit, credit: a.credit}
    end

    render json: transactions
  end

  def api_utxo
    credits = []
    debits = []
    Payment.where(address: params[:address]).find_each do |a|
      if a.debit == 0
        credits << {txid: a.txid, debit: a.debit, credit: a.credit}
      elsif a.credit == 0
        debits << {txid: a.txid, debit: a.debit, credit: a.credit}
      end
    end

    inputs = []
    credits.each do |c|
      JSON.parse(ApplicationController::cli(['getrawtransaction', c[:txid], '1']))["vout"].each do |vout|
        vout["scriptPubKey"]["addresses"].each_with_index do |address, index|
          if address == params[:address]
            inputs << {vout: vout, txid: c[:txid]}
            break
          end
        end
      end
    end

    outputs = []
    debits.each do |d|
      JSON.parse(ApplicationController::cli(['getrawtransaction', d[:txid], '1']))["vin"].each do |vin|
        inputs.each do |i|
          if i[:txid] == vin["txid"] && i[:vout]["n"] == vin["vout"]
            outputs << vin
          end
        end
      end
    end

    unspent_outputs = []
    inputs.each do |i|
      was_spent = false
      outputs.each do |o|
        if o["txid"] == i[:txid] && o["vout"] == i[:vout]["n"]
          was_spent = true
        end
      end
      
      unspent_outputs << i if !was_spent
    end
    render json: unspent_outputs.to_json
  end

  def api_estimatefee
    render json: ApplicationController::cli(['estimatefee', params[:blocks]])
  end

  def api_estimatepriority
    render json: ApplicationController::cli(['estimatepriority', params[:blocks]])
  end

  def api_estimatesmartfee
    render json: ApplicationController::cli(['estimatesmartfee', params[:blocks]])
  end

  def api_estimatesmartpriority
    render json: ApplicationController::cli(['estimatesmartpriority', params[:blocks]])
  end
end
