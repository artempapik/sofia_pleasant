require 'crack'
require 'net/http'
require 'nokogiri'
require 'openssl'
require 'telegram/bot'
require 'uri'

TOKEN = '2003556781:AAGJRuQ7kEhcSlEYS5TSaZI6JwqDFtevVnI'
POEMS_URL = 'https://www.culture.ru/literature/poems'
HOROSCOPE_URL = 'https://ignio.com/r/export/utf/xml/daily/com.xml'
WEATHER_URL = 'https://community-open-weather-map.p.rapidapi.com/weather?q=%s,ua&lat=0&lon=0&callback=test&id=2172797&lang=ru&units=imperial&mode=xml'
WEATHER_TOKEN = '322872341amsh91f7c6576949217p10a086jsndcaed814811a'

@constants = {
  :compliment               => 'комплимент',
  :advice                   => 'совет',
  :rude                     => 'быконуть',
  :poem                     => 'стих',
  :horoscope                => 'гораскоп',
  :weather                  => 'погодо',
  :tomorrow_horoscope       => 'хочу на завтра',
  :after_tomorrow_horoscope => 'а можна на послезавтра?('
}

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
  'possible_argue_answers',
  'desire_answers',
  'possible_desire_answers'
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
@possible_argue_answers,
@desire_answers,
@possible_desire_answers = file_paths.map(&method(:read_file_and_split))

def get_html_document(url)
  html = Net::HTTP.get(URI url)
  Nokogiri::HTML html
end

def get_last_poem_page
  document = get_html_document POEMS_URL
  document.search('a.pagination_item.js-pagination-item')[-1].text.to_i
end

LAST_POEM_PAGE = get_last_poem_page

def get_random_poem
  document = get_html_document("#{POEMS_URL}?page=#{rand(1..LAST_POEM_PAGE + 1)}")

  poem_elements = document.search 'div.entity-cards_item.col'
  poem_element = poem_elements[rand(0..poem_elements.length)]

  poem_author = poem_element.search('a.card-heading_subtitle').text
  poem_title = poem_element.search('a.card-heading_title-link').text
  poem_text = poem_element.search('a.card-heading_description-link').text.split(/(?=[А-Я])/).join("\n")

  "<b>#{poem_author}</b>\n\n<code>#{poem_title}</code>\n\n#{poem_text}"
end

@ru_to_en_horoscope_sign = {
  'овен'     => 'aries',
  'телец'    => 'taurus',
  'близнецы' => 'gemini',
  'рак'      => 'cancer',
  'лев'      => 'leo',
  'дева'     => 'virgo',
  'весы'     => 'libra',
  'скорпион' => 'scorpio',
  'стрелец'  => 'sagittarius',
  'козерог'  => 'capricorn',
  'водолей'  => 'aquarius',
  'рыбы'     => 'pisces'
}

def get_horoscope(sign, day = 'today')
  document = get_html_document(HOROSCOPE_URL)
  xml = Crack::XML.parse(document.search('body').inner_html)
  horoscope = JSON.parse(xml.to_json)['horo']
  en_sign = @ru_to_en_horoscope_sign[sign]
  "<code>#{sign.upcase}</code>\n#{horoscope[en_sign][day]}"
end

@abbreviation_to_city = {
  'киев' => 'Kyiv',
  'львов' => 'Lviv',
  'ха' => 'Kharkiv',
  'адэса' => 'Odesa',
  'каменск' => 'Kamianske',
  'влн' => 'Vilniansk',
  'зп' => 'Zaporijia',
  'млт' => 'Melitopol'
}

def to_celsius(fahrenheit) = (fahrenheit - 32) / 1.8

def get_temp(response, type) = "<code>#{to_celsius(response['main']["temp_#{type}"]).round(1)}°C</code>"

class Fixnum
  def format_time = (self + 2).to_s.rjust(2, '0')
end

def get_daytime(response, type)
  daytime = Time.at(response['sys'][type])
  "<b>#{daytime.hour.format_time}:#{daytime.min.format_time}</b>"
end

def get_weather(abbreviation)
  url = URI WEATHER_URL % @abbreviation_to_city[abbreviation]

  http = Net::HTTP.new(url.host, url.port)
  http.use_ssl = true

  request = Net::HTTP::Get.new url
  request['x-rapidapi-key'] = WEATHER_TOKEN

  response = http.request request
  weather_response = JSON.parse(response.read_body[5..-2])

  city_name = abbreviation == 'влн' ? 'Вольнянск' : weather_response['name']
  sunrise = get_daytime(weather_response, 'sunrise')
  sunset = get_daytime(weather_response, 'sunset')
  description = weather_response['weather'].map { |weather| weather['description'] }.join(', ')
  wind_speed = weather_response['wind']['speed']
  temp_min = get_temp(weather_response, 'min')
  temp_max = get_temp(weather_response, 'max')

  city_name = "вы выбрали #{city_name})"
  sunrise = "восход у нас в #{sunrise} утра"
  sunset = "а закат в #{sunset} вечора"
  description = "как оно: <u>#{description}</u>"
  wind_speed = "скорость ветра при этом составляет <i>#{wind_speed} м/с</i>"
  temp_min = "ну само прохладно будет при #{temp_min}"
  temp_max = "а само тепло при #{temp_max}"
  goodbye = "хорошего вам дня <s>дотвидания</s>"

  "#{city_name}\n\n#{sunrise}, #{sunset}\n#{description}\n\n#{wind_speed}\n\n#{temp_min}\n#{temp_max}\n\n\n#{goodbye}"
end

def inline_tg_button(text) = Telegram::Bot::Types::InlineKeyboardButton.new(text: text, callback_data: text)

def get_inline_keyboard_markup(*texts)
  keyboard = texts.map(&method(:inline_tg_button))
  Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: keyboard)
end

def tg_button(text) = Telegram::Bot::Types::KeyboardButton.new(text: text)

def get_text_with_type_and_reply_markup_from_message(message)
  start_keyboard_markup = Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard: [
    [tg_button(@constants[:compliment]), tg_button(@constants[:advice])],
    [tg_button(@constants[:rude]),       tg_button(@constants[:poem])],
    [tg_button(@constants[:horoscope]),  tg_button(@constants[:weather])]
  ])

  horoscope_signs = @ru_to_en_horoscope_sign.keys
  cities = @abbreviation_to_city.keys

  case message

  when '/start'
    return @greeting, nil, Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard: [
      [tg_button(@constants[:compliment]), tg_button(@constants[:advice])],
      [tg_button(@constants[:rude]),       tg_button(@constants[:poem])],
      [tg_button(@constants[:horoscope]),  tg_button(@constants[:weather])]
    ])

  when @constants[:compliment]
    "#{@compliments.sample} #{@pleasant_smiles.sample}"

  when @constants[:advice]
    @advices.sample

  when @constants[:rude]
    return @rude_phrases.sample, @constants[:rude]

  when @constants[:poem]
    get_random_poem

  when @constants[:horoscope]
    return @horoscope_answers.sample, @constants[:horoscope], get_inline_keyboard_markup(*horoscope_signs)

  when *horoscope_signs
    @chosen_sign = message
    return get_horoscope(@chosen_sign), nil, get_inline_keyboard_markup(@constants[:tomorrow_horoscope])

  when @constants[:tomorrow_horoscope]
    return get_horoscope(@chosen_sign, 'tomorrow'), nil, get_inline_keyboard_markup(@constants[:after_tomorrow_horoscope])

  when @constants[:after_tomorrow_horoscope]
    return get_horoscope(@chosen_sign, 'tomorrow02')

  when @constants[:weather]
    return 'выбирай с хорошыми дорогами золотце', @constants[:weather], get_inline_keyboard_markup(*cities)

  when *cities
    return get_weather(message)

  when *@possible_yes_no_answers
    @yes_no_answers.sample

  when *@possible_smiles_answers
    @smiles_answers.sample

  when *@possible_love_answers
    @love_answers.sample

  when *@possible_argue_answers
    @argue_answers.sample

  when *@possible_desire_answers
    @desire_answers.sample

  when 'почему молчишь?'
    'ты что меня не слышишь?'

  when 'мне не говоришь'
    'что без меня не дышыш..'

  when 'кароче'
    'понятна'

  when 'тебе с ним приятно'
    'ему с тобой тоже?'

  when 'любовь'
    'диалоги'

  when 'повтор'
    'и обратно'

  when 'там где клен шумит'
    'над речной волной'

  when 'над речной волной'
    'гаварИли мы'

  when 'говорили мы'
    'о ЛЮЮЮЮЮЮБВИ    с та бой'

  when '/goodbye'
    text = "#{@sad_phrases.sample} #{@sad_smiles.sample}"
    remove_keyboard_markup = Telegram::Bot::Types::ReplyKeyboardRemove.new(remove_keyboard: true)
    return text, nil, remove_keyboard_markup

  else
    @unable_responses.sample

  end
end

def send_message(text, text_type, markup)
  message_to_delete = @bot.api.send_message chat_id: @chat_id, text: text, reply_markup: markup, parse_mode: 'html'
  @message_id_to_delete = message_to_delete['result']['message_id'] if text_type == @constants[:horoscope] or text_type == @constants[:weather]
  @bot.api.send_sticker chat_id: @chat_id, sticker: @rude_stickers.sample if text_type == @constants[:rude]
end

def run_bot
  Telegram::Bot::Client.run TOKEN do |bot|
    @bot = bot
  
    bot.listen do |message|
      message = message.attributes
      @chat_id = message[:chat][:id] if message[:chat]
  
      if @message_id_to_delete
        @bot.api.edit_message_reply_markup chat_id: @chat_id, message_id: @message_id_to_delete
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
