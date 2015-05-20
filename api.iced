#!/usr/bin/env ./iced

Config = require('./config.json')
Act = require('./actions.iced')
Http = require('http')

toj = (obj) ->
  return JSON.stringify(obj)

fromj = (str) ->
  if ! str then return "Need JSON POST"
  try
    return JSON.parse(str)
  catch e
    return 'POST not in JSON format: '+e

get_body = (req, cb) ->
  inp = ''
  req.on 'data', (chunk) ->
    inp += chunk
  req.on 'end', () ->
    cb inp

doit = (req, res) ->
  await get_body req, defer inp
  res.writeHead 200, {'Content-Type': 'text/plain'}
  await do_body inp, defer err, out
  if err then  out = {error:1, reason:err}
  res.end toj(out)+'\n'

do_body = (inp, cb) ->
  obj = fromj(inp)
  if typeof obj != 'object' then cb obj; return
  if ! obj.action then cb 'No action requested'; return
  await Act.do_action obj, defer err, res
  if err then cb err
  else cb null, res

Http.createServer(doit).listen(Config.http.port, Config.http.host)


