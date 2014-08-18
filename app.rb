######
# note: to run use
#
#  e.g. ruby ./server.rb


class StarterApp < Sinatra::Base

#####################
# Models

include SportDb::Models


##############################################
# Controllers / Routing / Request Handlers

get '/' do

  ## self-docu in json
  endpoints = {
    list_events: {
      doc: 'list all events',
      url: '/events'
    },
    list_event_teams: {
      doc: 'list teams for an event',
      url: '/event/:key/teams'
    },
    list_event_rounds: {
      doc: 'list rounds for an event',
      url: '/event/:key/rounds'
    },
    list_event_games_for_round: {
      doc: 'list games for an event round',
      url: '/event/:key/round/:pos'
    }
  }

  json_or_jsonp( { endpoints: endpoints } )
end


get '/events' do
  events = []

  Event.order(:id).each do |ev|
    events << { key: ev.key, title: ev.title }
  end

  json_or_jsonp( events )
end


get '/event/:key/teams' do |key|
  # NB: change en.2012_13 or en.2012-13 to en.2012/13
  event = Event.find_by_key!( key.tr('_', '/').tr('-', '/') )

  teams = []
  event.teams.each do |t|
    teams << { key: t.key, title: t.title, code: t.code }
  end

  data = { event: { key: event.key, title: event.full_title }, teams: teams }

  json_or_jsonp( data )
end


get '/event/:key/rounds' do |key|
  # NB: change en.2012_13 to en.2012/13
  event = Event.find_by_key!( key.tr('_', '/').tr('-', '/') )

  rounds = []
  event.rounds.each do |r|
    rounds << { pos: r.pos, title: r.title,
                start_at: r.start_at.strftime('%Y/%m/%d'),
                end_at:   r.end_at.strftime('%Y/%m/%d') }
  end

  data = { event: { key: event.key, title: event.full_title }, rounds: rounds }

  json_or_jsonp( data )
end


get '/event/:key/round/:pos' do |key,pos|
  # NB: change en.2012_13 to en.2012/13
  event = Event.find_by_key!( key.tr('_', '/').tr('-', '/') )

  if pos =~ /\d+/
    round = Round.find_by_event_id_and_pos!( event.id, pos )
  else  # assume last from today's date (use last/today/etc. - must be non-numeric key)
    t_23_59 = Time.now.end_of_day
    round = Round.where( event_id: event.id ).where( 'start_at <= ?', t_23_59 ).order( 'pos' ).last
    if round.nil?   # assume all rounds in the future; display first upcoming one
      round = Round.where( event_id: event.id ).order('pos').first
    end
  end

  games = []
  round.games.each do |g|
    games << { team1_key: g.team1.key, team1_title: g.team1.title, team1_code: g.team1.code,
               team2_key: g.team2.key, team2_title: g.team2.title, team2_code: g.team2.code,
               play_at: g.play_at.strftime('%Y/%m/%d'),
               score1:   g.score1,   score2:   g.score2,
               score1ot: g.score1ot, score2ot: g.score2ot,
               score1p:  g.score1p,  score2p:  g.score2p
             }
  end

  data = { event: { key: event.key, title: event.full_title },
           round: { pos: round.pos, title: round.title,
                    start_at: round.start_at.strftime('%Y/%m/%d'),
                    end_at:   round.end_at.strftime('%Y/%m/%d')
                  },
           games: games }

  json_or_jsonp( data )
end


### helper for json or jsonp response (depending on callback para)

private
def json_or_jsonp( data )
  callback = params.delete('callback')
  response = ''

  ####
  # note: pretty print json
  json_str = JSON.pretty_generate( data )
  
  ## hack: for windows force utf-8   -- check if needed/works ???
  ##json_str = json_str.force_encoding( 'utf-8' )

  if callback
    content_type :js
    response = "#{callback}(#{json_str})"
  else
    content_type :json
    response = json_str
  end
  
  response
end

end # class StarterApp