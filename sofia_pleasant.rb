require 'net/http'
require 'nokogiri'
require 'telegram/bot'
require 'uri'

TOKEN = '2003556781:AAGJRuQ7kEhcSlEYS5TSaZI6JwqDFtevVnI'
POEMS_URL = 'https://www.culture.ru/literature/poems'
LAST_PAGE = 791

@greeting = IO.read 'greeting.txt'
@compliments = IO.readlines('compliments.txt').collect(&:strip)
@pleasant_smiles = IO.readlines('pleasant_smiles.txt').collect(&:strip)
@sad_phrases = IO.readlines('sad_phrases.txt').collect(&:strip)
@sad_smiles = IO.readlines('sad_smiles.txt').collect(&:strip)
@advices = IO.readlines('advices.txt').collect(&:strip)
@rude_phrases = IO.readlines('rude_phrases.txt').collect(&:strip)
@rude_stickers = IO.readlines('sticker_ids.txt').collect(&:strip)
@unable_responses = IO.readlines('unable_responses.txt').collect(&:strip)

def tg_button(text) = Telegram::Bot::Types::KeyboardButton.new(text: text)

@markup = Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard: [
  [tg_button('комплимент'), tg_button('совет')],
  [tg_button('быконуть'), tg_button('стих')]
])

def send_message(text, is_rude: false)
  @bot.api.send_message chat_id: @chat_id, text: text, reply_markup: @markup
  @bot.api.send_sticker chat_id: @chat_id, sticker: @rude_stickers.sample if is_rude
end

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
  when 'стих'
    html = Net::HTTP.get(URI "#{POEMS_URL}?page=#{rand(1..LAST_PAGE + 1)}")
    document = Nokogiri::HTML html

    poem_elements = document.search 'div.entity-cards_item.col'
    poem_element = poem_elements[rand(0..poem_elements.length)]

    poem_author = poem_element.search('a.card-heading_subtitle').text
    poem_title = poem_element.search('a.card-heading_title-link').text
    poem_text = poem_element.search('a.card-heading_description-link').text.split(/(?=[А-Я])/).join("\n")

    "#{poem_author}\n\n#{poem_title}\n\n#{poem_text}"
  when '/goodbye'
    "#{@sad_phrases.sample} #{@sad_smiles.sample}"
  else
    @unable_responses.sample
  end
end

Telegram::Bot::Client.run TOKEN do |bot|
  @bot = bot

  bot.listen do |message|
    @chat_id, message = message.chat.id, message.text
    text = get_text_from_message message
    send_message text, is_rude: message == 'быконуть'
  end
end
