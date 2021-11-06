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

file_paths = [
  'compliments',
  'pleasant_smiles',
  'sad_phrases',
  'sad_smiles',
  'advices',
  'rude_phrases',
  'sticker_ids',
  'unable_responses',
  'yes_no_answers',
  'possible_yes_no_answers',
  'smiles_answers',
  'possible_smiles_answers',
  'love_answers',
  'possible_love_answers',
  'horoscope_answers',
  'argue_answers',
  'possible_argue_answers'
].map { |path| "#{path}.txt" }

def read_file_and_split(filename) = IO.readlines(filename).collect(&:strip)

@compliments,
@pleasant_smiles,
@sad_phrases,
@sad_smiles,
@advices,
@rude_phrases,
@rude_stickers,
@unable_responses,
@yes_no_answers,
@possible_yes_no_answers,
@smiles_answers,
@possible_smiles_answers,
@love_answers,
@possible_love_answers,
@horoscope_answers,
@argue_answers,
@possible_argue_answers = file_paths.map(&method(:read_file_and_split))

def get_random_poem
  document = get_html_document("#{POEMS_URL}?page=#{rand(1..LAST_POEM_PAGE + 1)}")

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

def get_horoscope(sign, day = 'today')
  document = get_html_document(HOROSCOPE_URL)
  xml = Crack::XML.parse(document.search('body').inner_html)
  horoscope = JSON.parse(xml.to_json)['horo']
  en_sign = @ru_to_en_horoscope_sign[sign]
  "#{sign.upcase}\n#{horoscope[en_sign][day]}"
end

def tg_button(text) = Telegram::Bot::Types::KeyboardButton.new(text: text)

def inline_tg_button(text) = Telegram::Bot::Types::InlineKeyboardButton.new(text: text, callback_data: text)

TEXT_TYPE = {
  :none => 0,
  :rude => 1,
  :horoscope => 2
}
  
def send_message(text, text_type, markup)
  message_to_delete = @bot.api.send_message chat_id: @chat_id, text: text, reply_markup: markup
  @message_id_to_delete = message_to_delete['result']['message_id'] if text_type == TEXT_TYPE[:horoscope]
  @bot.api.send_sticker chat_id: @chat_id, sticker: @rude_stickers.sample if text_type == TEXT_TYPE[:rude]
end

def get_start_keyboard_markup
  keyboard = [
    [tg_button('комплимент'), tg_button('совет')],
    [tg_button('быконуть'), tg_button('стих')],
    [tg_button('гараскоп')]
  ]
  Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard: keyboard)
end

def get_inline_keyboard_markup(text)
  keyboard = inline_tg_button(text)
  Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: keyboard)
end

def get_text_with_type_and_reply_markup_from_message(message)
  case message

  when '/start'
    return @greeting, TEXT_TYPE[:none], get_start_keyboard_markup

  when 'комплимент'
    "#{@compliments.sample} #{@pleasant_smiles.sample}"

  when 'совет'
    @advices.sample

  when 'быконуть'
    return @rude_phrases.sample, TEXT_TYPE[:rude]

  when 'стих'
    get_random_poem

  when 'гараскоп'
    keyboard = @ru_to_en_horoscope_sign.keys.map(&method(:inline_tg_button))
    markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: keyboard)
    return @horoscope_answers.sample, TEXT_TYPE[:horoscope], markup

  when *@ru_to_en_horoscope_sign.keys
    @chosen_sign = message
    return get_horoscope(message), TEXT_TYPE[:none], get_inline_keyboard_markup('хочу на завтра')

  when 'хочу на завтра'
    return get_horoscope(@chosen_sign, 'tomorrow'), TEXT_TYPE[:none], get_inline_keyboard_markup('а можна на послезавтра?(')

  when 'а можна на послезавтра?('
    return get_horoscope(@chosen_sign, 'tomorrow02'), TEXT_TYPE[:none], get_start_keyboard_markup

  when *@possible_yes_no_answers
    @yes_no_answers.sample

  when *@possible_smiles_answers
    @smiles_answers.sample

  when *@possible_love_answers
    @love_answers.sample

  when *@possible_argue_answers
    @argue_answers.sample

  when '/goodbye'
    text = "#{@sad_phrases.sample} #{@sad_smiles.sample}"
    markup = Telegram::Bot::Types::ReplyKeyboardRemove.new(remove_keyboard: true)
    return text, TEXT_TYPE[:none], markup

  else
    @unable_responses.sample

  end
end

def run_bot
  Telegram::Bot::Client.run TOKEN do |bot|
    @bot = bot
  
    bot.listen do |message|
      message = message.attributes
      @chat_id = message[:chat][:id] if message[:chat]
  
      if @message_id_to_delete
        @bot.api.edit_message_reply_markup(chat_id: @chat_id, message_id: @message_id_to_delete)
        @message_id_to_delete = nil
      end
  
      message = message[:text] || message[:data] || nil
  
      if @chat_id and message
        text, text_type, markup = get_text_with_type_and_reply_markup_from_message(message.downcase)
        send_message(text, text_type, markup)
      end
    end
  end
end

run_bot

# require 'uri'
# require 'net/http'
# require 'openssl'

# url = URI 'https://community-open-weather-map.p.rapidapi.com/weather?q=kamianske,ua&lat=0&lon=0&callback=test&id=2172797&lang=ru&units=imperial&mode=xml'

# http = Net::HTTP.new(url.host, url.port)
# http.use_ssl = true

# request = Net::HTTP::Get.new url
# request['x-rapidapi-key'] = '322872341amsh91f7c6576949217p10a086jsndcaed814811a'

# response = http.request request
# puts response.read_body
