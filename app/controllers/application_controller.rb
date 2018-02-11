class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception

  def home
    @title = 'Home'
    @output = ApplicationController::namecoin_cli('getinfo')
    @output = JSON.parse(@output)
  
    @latest_blocks = Array.new
    blocks = @output["blocks"] - 6
    @output["blocks"].downto(blocks).each do |n|
      block = JSON.parse(ApplicationController::namecoin_cli('getblock ' + ApplicationController::namecoin_cli('getblockhash ' + n.to_s)))
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
    @latest_transactions = JSON.parse(ApplicationController::namecoin_cli('name_filter "^d/" 10'))
  end

  def contact
    @title = 'Contact'
  end

  # Dynamic routes start here

  def block
    @title = "Block #{params[:block]}"
    if params[:block].to_s.count('a-fA-F') > 0
      @output = ApplicationController::namecoin_cli('getblock ' + params[:block])
    else
      @output = ApplicationController::namecoin_cli('getblock ' + ApplicationController::namecoin_cli('getblockhash ' + params[:block]))
    end

    if !@output.blank?
      @output = JSON.parse(@output)
    end
  end

  def transaction
    @title = "Transaction #{params[:transaction]}"
    @output = get_transaction(params[:transaction])
    @output["height"] = JSON.parse(ApplicationController::namecoin_cli('getblock ' + @output["blockhash"]))["height"]
  end

  def address
    #Come back to this later.
  end

  def name
    @title = "Name #{params[:name]}"
    params[:type] = params[:type].downcase
    if params[:type] == 'd'
      @output = JSON.parse(ApplicationController::namecoin_cli('name_show d/' + params[:name]))
      @history = JSON.parse(ApplicationController::namecoin_cli('name_history id/' + params[:name]))
    elsif params[:type] == 'id'
      @output = JSON.parse(ApplicationController::namecoin_cli('name_show id/' + params[:name]))
      @history = JSON.parse(ApplicationController::namecoin_cli('name_history id/' + params[:name]))
    end
    @history.reverse!
  end

  def self.namecoin_cli(command)
    x = "#{ENV['NAMECOIN_CLI']} -rpcuser=#{ENV['NAMECOIN_RPC_USER']} -rpcpassword=#{ENV['NAMECOIN_RPC_PASSWORD']} #{command} 2>&1"
    return `#{x}`
  end

  def get_transaction(txid)
    JSON.parse(ApplicationController::namecoin_cli("getrawtransaction #{txid} 1"))
  end
end
