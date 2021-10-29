require 'telegram/bot'
require 'nokogiri'
require 'httparty'

# rubocop:disable Style/MutableConstant

TOKEN = '2003556781:AAGJRuQ7kEhcSlEYS5TSaZI6JwqDFtevVnI'
POEMS_URL = 'https://www.culture.ru/literature/poems'

# rubocop:enable Style/MutableConstant

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

def tg_button(text)
  Telegram::Bot::Types::KeyboardButton.new(text: text)
end

keyboard = [
  [
    tg_button('комплимент'),
    tg_button('совет')
  ],
  [
    tg_button('быконуть'),
    tg_button('стих')
  ]
  # [
  #   tg_button('поприветствовать'),
  #   tg_button('попрощаться')
  # ]
]

@markup = Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard: keyboard)

def send_message(text, is_rude: false)
  @bot.api.send_message chat_id: @chat_id, text: text, reply_markup: @markup
  @bot.api.send_sticker chat_id: @chat_id, sticker: @rude_stickers.sample if is_rude
end

# rubocop:disable Metrics/MethodLength
# rubocop:disable Metrics/AbcSize
# rubocop:disable Metrics/CyclomaticComplexity

def get_text_from_message(message)
  case message
  when '/start', 'поприветствовать'
    @greeting
  when 'комплимент'
    "#{@compliments.sample} #{@pleasant_smiles.sample}"
  when 'совет'
    @advices.sample
  when 'быконуть'
    @rude_phrases.sample
  when 'стих'
    response = HTTParty.get("#{POEMS_URL}?page=#{rand(1..LAST_PAGE + 1)}")
    html = response.body if response.code == 200
    document = Nokogiri::HTML(html)

    poem_elements = document.search('div.entity-cards_item.col')
    poem_element = poem_elements[rand(0..poem_elements.length)]

    poem_author = poem_element.search('a.card-heading_subtitle').text
    poem_title = poem_element.search('a.card-heading_title-link').text

    poem_text = ''
    poem_element.search('a.card-heading_description-link').text.split(/(?=[А-Я])/).each do |text_fragment|
      poem_text << "#{text_fragment}\n"
    end

    "#{poem_author}\n\n#{poem_title}\n\n#{poem_text}"
  when 'попрощаться'
    "#{@sad_phrases.sample} #{@sad_smiles.sample}"
  else
    @unable_responses.sample
  end
end

# rubocop:enable Metrics/MethodLength
# rubocop:enable Metrics/AbcSize
# rubocop:enable Metrics/CyclomaticComplexity

Telegram::Bot::Client.run TOKEN do |bot|
  @bot = bot

  bot.listen do |message|
    @chat_id = message.chat.id
    message = message.text
    text = get_text_from_message message
    send_message text, is_rude: message == 'быконуть'
  end
end
