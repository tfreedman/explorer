class Address < ActiveRecord::Base
  attr_accessor :balance
  def date
    Time.at(JSON.parse(ApplicationController::cli(["getrawtransaction", self.txid, '1']))["time"])
  end

  def block
    ApplicationController::get_block(JSON.parse(ApplicationController::cli(["getrawtransaction", self.txid, '1']))["blockhash"])["height"]
  end
end
