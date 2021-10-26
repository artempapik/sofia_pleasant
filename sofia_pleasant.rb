# frozen_string_literal: true

require 'telegram/bot'

token = '2003556781:AAGJRuQ7kEhcSlEYS5TSaZI6JwqDFtevVnI'

@greeting = IO.read 'greeting.txt'
@compliments = IO.readlines('compliments.txt').collect(&:strip)
@pleasant_smiles = IO.readlines('pleasant_smiles.txt').collect(&:strip)
@sad_phrases = IO.readlines('sad_phrases.txt').collect(&:strip)
@sad_smiles = IO.readlines('sad_smiles.txt').collect(&:strip)
@advices = IO.readlines('advices.txt').collect(&:strip)
@rude_phrases = IO.readlines('rude_phrases.txt').collect(&:strip)
@rude_stickers = IO.readlines('sticker_ids.txt').collect(&:strip)
@unable_responses = IO.readlines('unable_responses.txt').collect(&:strip)

def tg_button(text)
  Telegram::Bot::Types::KeyboardButton.new(text: text)
end

keyboard = [
  [
    tg_button('комплимент'),
    tg_button('совет'),
    tg_button('быконуть')
  ],
  [
    tg_button('попрощаться')
  ]
]

@markup = Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard: keyboard)

def send_message(text, is_rude: false)
  @bot.api.send_message chat_id: @chat_id, text: text, reply_markup: @markup
  @bot.api.send_sticker chat_id: @chat_id, sticker: @rude_stickers.sample if is_rude
end

# rubocop:disable Metrics/MethodLength

def get_text_from_message(message)
  case message
  when '/start'
    @greeting
  when 'комплимент'
    "#{@compliments.sample} #{@pleasant_smiles.sample}"
  when 'совет'
    @advices.sample
  when 'быконуть'
    @rude_phrases.sample
  when 'попрощаться'
    "#{@sad_phrases.sample} #{@sad_smiles.sample}"
  else
    @unable_responses.sample
  end
end

# rubocop:enable Metrics/MethodLength

Telegram::Bot::Client.run token do |bot|
  @bot = bot

  bot.listen do |message|
    @chat_id = message.chat.id
    message = message.text
    text = get_text_from_message message
    send_message text, is_rude: message == 'быконуть'
  end
end
