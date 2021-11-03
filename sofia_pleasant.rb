require 'crack'
require 'net/http'
require 'nokogiri'
require 'telegram/bot'
require 'uri'

TOKEN = '2003556781:AAGJRuQ7kEhcSlEYS5TSaZI6JwqDFtevVnI'
POEMS_URL = 'https://www.culture.ru/literature/poems'
HOROSCOPE_URL = 'https://ignio.com/r/export/utf/xml/daily/com.xml'

def get_html_document(url)
  html = Net::HTTP.get(URI url)
  Nokogiri::HTML html
end

def get_last_poem_page
  document = get_html_document POEMS_URL
  document.search('a.pagination_item.js-pagination-item')[-1].text.to_i
end

LAST_POEM_PAGE = get_last_poem_page

@greeting = IO.read 'greeting.txt'
@compliments = IO.readlines('compliments.txt').collect(&:strip)
@pleasant_smiles = IO.readlines('pleasant_smiles.txt').collect(&:strip)
@sad_phrases = IO.readlines('sad_phrases.txt').collect(&:strip)
@sad_smiles = IO.readlines('sad_smiles.txt').collect(&:strip)
@advices = IO.readlines('advices.txt').collect(&:strip)
@rude_phrases = IO.readlines('rude_phrases.txt').collect(&:strip)
@rude_stickers = IO.readlines('sticker_ids.txt').collect(&:strip)
@unable_responses = IO.readlines('unable_responses.txt').collect(&:strip)

def get_poem
  document = get_html_document "#{POEMS_URL}?page=#{rand(1..LAST_POEM_PAGE + 1)}"

  poem_elements = document.search 'div.entity-cards_item.col'
  poem_element = poem_elements[rand(0..poem_elements.length)]

  poem_author = poem_element.search('a.card-heading_subtitle').text
  poem_title = poem_element.search('a.card-heading_title-link').text
  poem_text = poem_element.search('a.card-heading_description-link').text.split(/(?=[А-Я])/).join("\n")

  "#{poem_author}\n\n#{poem_title}\n\n#{poem_text}"
end

@ru_to_en_horoscope_sign = {
  'овен' => 'aries',
  'телец' => 'taurus',
  'близнецы' => 'gemini',
  'рак' => 'cancer',
  'лев' => 'leo',
  'дева' => 'virgo',
  'весы' => 'libra',
  'скорпион' => 'scorpio',
  'стрелец' => 'sagittarius',
  'козерог' => 'capricorn',
  'водолей' => 'aquarius',
  'рыбы' => 'pisces'
}

def get_horoscope(sign)
  document = get_html_document HOROSCOPE_URL
  xml = Crack::XML.parse(document.search('body').inner_html)
  horoscope = JSON.parse(xml.to_json)['horo']
  en_sign = @ru_to_en_horoscope_sign[sign]
  horoscope[en_sign]['today']
end

def tg_button(text) = Telegram::Bot::Types::KeyboardButton.new(text: text)

def inline_tg_button(text) = Telegram::Bot::Types::InlineKeyboardButton.new(text: text, callback_data: text)
  
def send_message(text, is_rude: false, is_goroscope: false)
  if is_goroscope
    keyboard = []
    for key in @ru_to_en_horoscope_sign.keys
      keyboard.push(inline_tg_button key)
    end
    markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: keyboard)
  else
    markup = Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard: [
      [tg_button('комплимент'), tg_button('совет')],
      [tg_button('быконуть'), tg_button('стих')],
      [tg_button('гараскоп')]
    ])
  end
  
  @bot.api.send_message chat_id: @chat_id, text: text, reply_markup: markup
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
    get_poem
  when 'гараскоп'
    "выбирите ваш знак (может это страстный телец?)\nя не подсказываю если че."
  when '/goodbye'
    "#{@sad_phrases.sample} #{@sad_smiles.sample}"
  else
    @unable_responses.sample
  end
end

Telegram::Bot::Client.run TOKEN do |bot|
  @bot = bot

  bot.listen do |message|
    @chat_id = message.chat.id if message.attributes[:chat]

    if @chat_id
      message = message.attributes[:text] ? message.text : message.data

      text = @ru_to_en_horoscope_sign.keys.include? message ?
        get_horoscope(message) :
        get_text_from_message(message)
      send_message text, is_rude: message == 'быконуть', is_goroscope: message == 'гараскоп'
    end
  end
end
