require 'discordrb'
require './lib/bcdice_wrap'

class UnsupportedDicebot < StandardError
end

class CommandError < StandardError
end

bot = Discordrb::Commands::CommandBot.new(
  token: ENV['BOT_TOKEN'],
  prefix: '!',
  ignore_bots: true
)

bot.instance_variable_set(:@env_table, {})
bot.class.define_method(:env) do |id|
  @env_table[id] ||= { system: 'DiceBot' }
  @env_table[id]
end

bot.class.define_method(:set_env) do |id, key, val|
  @env_table[id] ||= { system: 'DiceBot' }
  @env_table[id][key] = val
end

def make_bcdice(system, command)
  dicebot = BCDice::DICEBOTS[system]

  raise UnsupportedDicebot if dicebot.nil?

  raise CommandError if command.nil? || command.empty?

  bcdice = BCDiceMaker.new.newBcDice
  bcdice.setDiceBot(dicebot)
  bcdice.setMessage(command)
  bcdice.setDir('bcdice/extratables', system)
  bcdice.setCollectRandResult(true)
  bcdice
end

def diceroll(system, command)
  bcdice = make_bcdice(system, command)

  result, secret = bcdice.dice_command
  dices = bcdice.getRandResults.map { |dice| { faces: dice[1], value: dice[0] } }

  puts "DEBUG: #{[system, command]} #{[result, secret, dices]}"

  raise CommandError if result.nil? || result == '1'

  [result, secret, dices]
end

bot.command :roll do |event, *args|
  result, secret, _dices = diceroll(bot.env(event.channel.id)[:system], args.join(' '))
  msg = BCDice::DICEBOTS[bot.env(event.channel.id)[:system]].gameName + result

  if secret
    event.user.pm msg
    nil
  else
    msg
  end
end

bot.command :set_system do |event, system|
  bot.set_env(event.channel.id, :system, system)
  "set system #{system} (#{BCDice::DICEBOTS[system].gameName})"
end

bot.command :show_env do |event|
  bot.env(event.channel.id).to_s
end

bot.run