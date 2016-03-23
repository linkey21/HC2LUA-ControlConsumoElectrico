--[[
%% autostart
%% properties
%% globals
--]]

-- Scene   : getPVPC
-- Author  : Manuel Pascual
-- Version : 1.0
-- Date    : Marzo 2016
------------------------------------------------------------------------------]]

--[[----- CONFIGURACION DE USUARIO -------------------------------------------]]
local token = ''
--[[----- FIN CONFIGURACION DE USUARIO ---------------------------------------]]

function getPVPC()
  local postURL = "https://api.esios.ree.es/indicators/1013"
  local httpClient = net.HTTPClient()
  httpClient:request(postURL, {
      success = function(response)
      if response.status == 200 then
          local indicators = json.decode(response.data)
          local indicator = indicators.indicator
          local values = indicator.values
          local PVPC = {}
          for key, value in pairs(values) do
            --fibaro:debug(value.datetime..' '..value.value)
            table.insert(PVPC, {hour=string.sub(value.datetime, 12,13),
             value=value.value})
          end
          fibaro:setGlobal('PVPC', json.encode(PVPC))
      else
          fibaro:debug('Error : '..json.encode(response))
      end
    end,
    error = function(err)
     fibaro:debug('Error : '..err)
    end,
    options = {
      method = "GET",
      headers = {
        ["Content-Type"] = 'application/json',
        ["Accept"] = 'application/json; application/vnd.esios-api-v1+json',
        ["Host"] = 'api.esios.ree.es',
        ["Authorization"] = 'Token token="'.. token.. '"',
        ["Cookie"] = ''
      }
      --data = postData,
      --timeout = 10000
    }
  })

  -- control watchdog
  fibaro:debug('getPVPC OK')

  --[[
  averiguar el timeStamp de las 00:01h del días siguiente y restar del timeStamp
  actual, esperar ese tiempo para iniciar la siguiente actualización]]
  local tT = os.date('*t', os.time() + 24*60*60)
  local stampIni = os.time({year = tonumber(tT.year), month = tonumber(tT.month),
  day = tonumber(tT.day), hour = 0, min = 1, sec = 0})
  local delay = (stampIni - os.time()) * 1000
  setTimeout(function()
    if isVariable('PVPC', true) then getPVPC() end
  end, delay)

end

function isVariable(varName, create)
  -- comprobar si existe
  local valor, timestamp = fibaro:getGlobal(varName)
  -- si existe devolver el contenido
  if (valor and timestamp > 0) then return valor end
  -- si no existe
  if create then
    local json = '{"name":"'..varName..'", "isEnum":0}'
    local postURL = 'http://127.0.0.1:11111/api/globalVariables'
    local httpClient = net.HTTPClient()
    httpClient:request(postURL, {
      success = function(response)
        fibaro:debug('response : '..response.data)
        getPVPC()
      end,
      error = function(err)
       fibaro:debug('Error : '..err)
      end,
      options = {
        method = "POST",
        data = json
      }
    })
  end
  return false
end

-- bucle principal
-- si la variable global existe la actualiza si no la crea y actualiza
setTimeout(function()
  if isVariable('PVPC', true) then getPVPC() end
end, 1)
