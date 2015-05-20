
Config = require('./config.json')

Mysql = require('mysql')

closeDb = () ->
  if Db Db.end process.exit()
  else process.exit()
process.on 'SIGINT', closeDb
process.on 'SIGTERM', closeDb

Db = Mysql.createPool Config.db


do_action = (req, cb) ->
  res = {}
  res.error = 0
  if req.action == 'get'
    await do_action_get req, defer err, d
    if err then cb err; return
    res.data = d
    cb null, res; return
  cb "Action not implemented: "+req.action

do_action_get = (req, cb) ->
  data = {}
  if ! req.what then cb 'What to get not specified'; return
  if typeof req.what != 'object' then cb 'What must be an array of objects'; return
  if req.what.constructor != Array then req.what = [req.what]
  i = 0
  for what in req.what
    await do_action_get_what what, defer err, d
    if err then cb err+'; what #'+(i+1); return
    data[what.name] = d
    i += 1
    if i == 20 then break
  cb null, data

Allowed_from = {games:'game as g left join gameblob as b on g.id=b.id', current:'tempgame as g', players:'player as p', online:'session as s left join player as p on s.id=p.id'}
Allowed_select = {
  games:{id:'g.id',wusername:'g.wusername',busername:'g.busername'}, 
  current:{}, 
  players:{}, 
  online:{}
}

do_action_get_what = (what, cb) ->
  if typeof what != 'object' then cb "element of 'what' is not an object"; return
  if what.name == undefined then cb "'name' not given"; return
  if typeof what.name != 'string' then cb "'name' is not a string"; return
  if what.name.match ///\W/// then cb "'name' contains non alpha numerics: "+what.name; return
# last_game
  if what.name == 'last_game'
    await get_last_game what, defer err, d
    if err then cb err; return
    cb null, d; return
# recent games
  if what.name == 'recent_games'
    await get_recent_games what, defer err, d
    if err then cb err; return
    cb null, d; return
# recent games
  if what.name 
    await get_custom_games what, defer err, d
    if err then cb err; return
    cb null, d; return
  cb 'Not yet implemented: '+what.name

get_last_game = (what, cb) ->
  try
    await Db.query 'select wusername, busername from game order by endts desc limit 1', defer err, rows, fields
    if err
      cb err
      return
    cb null, {wusername:rows[0].wusername, busername:rows[0].busername}
  catch e
    cb e


Allowed_from = {games:'game',live_games:'tempgame',players:'player'}
Select_from = {games:"id,wplayerid,bplayerid,wusername,busername,wfname,bfname,wtitle,btitle,wcountry,bcountry,wrating,brating,wtype,btype,event,site,timecontrol,startts,endts,result,termination,plycount,mode,rated,commcount,commts,commusername,postal,wratingk,bratingk,tempid,eventgame,eventid,corrupt,adjtcs",    live_games:"id,wplayerid,bplayerid,wusername,busername,wfname,bfname,wtitle,btitle,wcountry,bcountry,wrating,brating,wtype,btype,event,site,timecontrol,startts,endts,createdts,result,termination,plycount,mode,gameid,rated,schts,postal,turn,turnts,minrating,maxrating,eventid,eventgame,adjtcs",    players:"id,username,referrer,promocode,fname,title,type,country,createdts,lastlogints,rating,ratingk,playernum,timezone,gamesplayed,autopostal,autopostalmax,autopostaldiff"}

 
get_recent_games = (what, cb) ->
  what.limit = parseNumber what.limit, [20, 1, 100]
  what.offset = parseNumber what.offset, [0, 0, null]
  what.players = ''+what.players
  what.postal = ''+what.postal
  players = switch what.players
    when 'h*' then "(wtype='h' or btype='h')"
    when 'hh' then "(wtype='h' and btype='h')"
    when 'hb' then "((wtype='h' and btype='b') or (wtype='b' and btype='h'))"
    when 'bb' then "(wtype='b' and btype='b')"
    when 'b*' then "(wtype='b' or btype='b')"
    else ""
  postal = switch what.postal
    when 'i' then "postal=0"
    when 'p' then "postal=1"
    else ""
  where = ""
  if players then where += " and #{players}"
  if postal then where += " and #{postal}"
  where = where.replace(/^\sand\s/, '')
  if where then where = "where "+where
  orderby = "order by endts desc"
  limit = "limit "+what.limit
  offset = "offset "+what.offset
  q = "select #{Select_games} from game #{where} #{orderby} #{limit} #{offset}"
  try
    await Db.query q, defer err, rows, fields
    if err
      cb err
      return
    cb null, rows
  catch e
    cb e


get_custom_games = (what, cb) ->
  what.limit = parseNumber what.limit, [20, 1, 100]
  what.offset = parseNumber what.offset, [0, 0, null]
  what.from = parseString what.from
  from = Allowed_from[what.from]
  if ! from then cb "'from' has invalid value: "+what.from; return
  order = parseString what.order
  where = parseString what.where
  order = order.replace(/[;]/g, '')
  where = where.replace(/[;]/g, '')
  if where then where = "where "+where
  if order then order = "order by "+order
  limit = "limit "+what.limit
  offset = "offset "+what.offset
  select = Select_from[what.from]
  q = "select #{select} from #{from} #{where} #{order} #{limit} #{offset}"
  try
    await Db.query q, defer err, rows, fields
    if err
      cb err  + ' ['+q+']'
      return
    cb null, rows
  catch e
    cb e + ' ['+q+']'

parseNumber = (a, b) ->
  def=b[0]; min=b[1]; max=b[2]
  if def == undefined then def=0
  a = parseFloat(a) || +a || def
  if min && a<min then a=min
  if max && a>max then a=max
  return a

parseString = (a, b) ->
  if ! b then b = ''
  if ! a then return b
  return ''+a
 
exports.do_action = do_action

