require 'scraperwiki'
require 'mechanize'

class Mechanize::Form
  def postback target, argument
    self['__EVENTTARGET'], self['__EVENTARGUMENT'] = target, argument
    submit
  end
end


case ENV['MORPH_PERIOD']
  when 'lastmonth'
  	period = "LM"
  when 'thismonth'
  	period = "TM"
  when 'thisweek'
    period = "TW"
  else
    period = "TM"
  	ENV['MORPH_PERIOD'] = 'thismonth'
end
puts "Getting data in `" + ENV['MORPH_PERIOD'] + "`, changable via MORPH_PERIOD environment"

url         = 'https://ecouncil.cockburn.wa.gov.au/eProperty/P1/eTrack/eTrackApplicationSearchResults.aspx?Field=S&Period=' + period +'&r=P1.WEBGUEST&f=%24P1.ETR.SEARCH.S' + period
info_url    = 'https://ecouncil.cockburn.wa.gov.au/eProperty/P1/eTrack/eTrackApplicationDetails.aspx?r=P1.WEBGUEST&f=%24P1.ETR.APPDET.VIW&ApplicationId='
comment_url = 'mailto:customer@cockburn.wa.gov.au'

agent = Mechanize.new
page = agent.get(url)

if page.search("tr.pagerRow").empty?
  puts 'Nothing to scape'
  exit 0
end

while page.search("tr.pagerRow").search("td")[-1].inner_text == '...' do
  target, argument = page.search("tr.pagerRow").search("td")[-1].at('a')['href'].scan(/'([^']*)'/).flatten
  page = page.form.postback target, argument
end
totalPages = page.search("tr.pagerRow").search("td")[-1].inner_text.to_i

(1..totalPages).each do |i|
  puts "Scraping page " + i.to_s + " of " + totalPages.to_s

  if i == 1
    page = agent.get(url)
  else
    page = page.form.postback target, 'Page$' + i.to_s
  end

  results = page.search("tr.normalRow, tr.alternateRow")
  results.each do |result|
    record = {
      'council_reference' => result.search("td")[0].inner_text.to_s,
      'address'           => result.search("td")[3].inner_text.to_s,
      'description'       => result.search("td")[2].inner_text.to_s,
      'info_url'          => info_url + result.search("td")[0].inner_text.sub!("/", "%2f"),
      'comment_url'       => comment_url,
      'date_scraped'      => Date.today.to_s,
      'date_received'     => Date.parse(result.search("td")[1]).to_s
    }

    puts "Saving record " + record['council_reference'] + ", " + record['address']
    # puts record
    ScraperWiki.save_sqlite(['council_reference'], record)
  end
end
