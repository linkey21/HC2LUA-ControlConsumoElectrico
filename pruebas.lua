--[[----------------------------------------------------------------------------
newGlobal(varName, seteo)
	crea una variable global
--]]
function newGlobal(varName, seteo)
  -- si no exite la variable se crea
  if not isVariable(varName) then
    _log(DEBUG, 'no existe variable global!')
    -- obtener IP y puerto
    local IPAddress = fibaro:getValue(_selfId, 'IPAddress')
    local TCPPort = fibaro:getValue(_selfId, 'TCPPort')
    if IPAddress == '' or TCPPort == 0 then
      fibaro:log('Configure IP:Port')
      _log(INFO,'Configure IP:Port' )
    end
    -- si no existe conexion previa
    if not tcpHC2 then
      -- obtener conexion TCP con el HC2
      tcpHC2 = Net.FHttp('localhost', 80)
    end
    -- validar sesion
    tcpHC2:setBasicAuthentication(usuarioHC2, claveHC2)
    -- enviar un POST para crear variable
    local response, status, errorCode
    --response, status, errorCode = tcpHC2:POST("/api/globalVariables", "name=" ..
    --varName.."&value=0?eadOnly=false?isEnum=false") -- .. "&value=0"
    response, status, errorCode = tcpHC2:GET('/api/globalVariables/')
    local jsonTable = json.decode(response)
    jsonTable[#jsonTable + 1] = {name = varName, value = '0', readOnly = false,
    isEnum = false}
    local json = json.encode(jsonTable)
    response, status, errorCode = tcpHC2:PUT('/api/globalVariables/', json)
    _log(DEBUG, 'response: '..response..' status: '..status..' errorCode: '
     ..errorCode)
     if (errorCode == 0 and tonumber(status) < 400) then
       -- si se ha pasado un valor(seteo)
       if seteo then
         -- parsear tipo
         if type(seteo) == 'table' then
           seteo = json.encode(seteo)
         elseif type(seteo) == 'number' then
           seteo = tostring(seteo)
         elseif type(seteo) == 'string' then
        else
          seteo = '0'
        end
        -- setear la variable
        fibaro:setGlobal(varName, json.encode(seteo))
       end
       return 0, seteo
     else
       return status, 'No se ha podido crear la variable global'
     end
  end
  return 1, 'La variable ya existe'
end

--[[----------------------------------------------------------------------------
formatConsumo()
	inserta un valor 0 en todos los posibles valores de la tabla de consumos
--]]
function formatConsumo()
  local consumoTab = {}
  for m = 1, 12 do
    local mes = string.format('%.2d',m)
    for d = 1, 31 do
      local dia = string.format('%.2d',d)
        for h = 1, 24 do
          local hora = string.format('%.2d',h)
          local indConsumo = mes..dia..hora
          consumoTab[indConsumo] = {valor = 0, unidad = 'kWh'}
        end
    end
  end
  fibaro:setGlobal(globalVarName, json.encode(consumo))
  return 0
end
