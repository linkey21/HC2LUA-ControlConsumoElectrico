
--[[Control de consumo
	VD Consumo
	boton reset resetButton.lua
	por Antonio Maestre & Manuel Pascual
--------------------------------------------------------------------------------]]
release = {name='controConsumo resetButton', ver=0, mayor=0, minor=2}

--[[----- CONFIGURACION DE USUARIO ---------------------------------------------]]
globalVarName = 'consumoEnergia'	-- nombre de la variable global
energyDev = 512				-- ID del dispositivo de energia
propertyName = 'energy'		-- propiedad del dispositivo para recuperar la energia
							-- acumulada en kWh
OFF=1;INFO=2;DEBUG=3		-- esto es una referencia para el log, no cambiar
nivelLog = DEBUG			-- nivel de log
--[[----- FIN CONFIGURACION DE USUARIO -----------------------------------------]]

--[[----- NO CAMBIAR EL CODIGO A PARTIR DE AQUI --------------------------------]]

--[[----- CONFIGURACION AVANZADA -----------------------------------------------]]
--[[consumoTab
  tabla para almacenar consumos horarios, se usa el indice para almacenar
  la hora, dia y mes 'mmddhh' y una tabla con el valor y la unidad, ej.
  consumo de las 12 de la mañana del dia 17 de septiembre
  consumo['121709'] = {valor=0.1234, unidad=kWh'}
  --]]
  -- obtener el ID de este dispositivo virtual
  local _selfId = fibaro:getSelfId();
--[[----- FIN CONFIGURACION AVANZADA -------------------------------------------]]

--[[
_log(level, log)
	funcion para operar el nivel de LOG
--------------------------------------------------------------------------------]]
function _log(level, log)
  if log == nil then log = 'nil' end
  local LOG = {}
  LOG[1]='OFF'; LOG[2]='INFO'; LOG[3]='DEBUG';
  if nivelLog >= level then
    fibaro:debug(log)
  end
  return
end

--[[------------------------------------------------------------------------------
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

--[[------------------------------------------------------------------------------
resetConsumo()
	inicializa (vacia) la tabla de consumos
--]]
function resetConsumo()
  local consumoTab = {}
  fibaro:setGlobal(globalVarName, json.encode(consumoTab))
  -- almacenar consumo actual
  local consumoActual = tonumber(fibaro:getValue(energyDev, propertyName))
  return setConsumo(consumoActual)
end

--[[------------------------------------------------------------------------------
setConsumo(hora, dia, mes, valor)
	almacena el consumo horario.
	si se pasa 1 parametro lo almacena en la hora actual del sistema (valor)
	en otro caso debe recibir 4 parametros indicando (hora, dia, mes, valor)
--]]
function setConsumo(a, b, c, d)
  local hora = 0
  local dia = 0
  local mes = 0
  local valor = 0
  if not a then return 1 -- error
  elseif not b then -- setear consumo actual
    hora = tonumber(os.date("%H"))
    dia = tonumber(os.date("%d"))
    mes = tonumber(os.date("%m"))
    valor = a
  elseif not c then return 2 -- error
  elseif not d then return 3 -- error
  else -- setear consumo hora
    hora = a
    dia = b
    mes = c
    valor = d
  end
  local consumoTab = json.decode(fibaro:getGlobalValue(globalVarName))
  local mes = string.format('%.2d',mes)
  local dia = string.format('%.2d',dia)
  local hora = string.format('%.2d',hora)
  local indConsumo = mes..dia..hora
  consumoTab[indConsumo] = {valor = valor, unidad = 'kWh'}
  fibaro:setGlobal(globalVarName, json.encode(consumoTab))
  return 0
end

--[[------- INICIA LA EJECUCION ------------------------------------------------]]
-- resetear la tabla de consumos 
local status = resetConsumo()
-- invocar al boton de actualizacion de datos
fibaro:call(_selfId, "pressButton", "14")
--[[----- FIN DE LA EJECUCION --------------------------------------------------]]

--[[----- INFORME DE RESULTADOS ------------------------------------------------]]
_log(INFO, release['name']..
' ver '..release['ver']..'.'..release['mayor']..'.'..release['minor'])

_log(INFO, fibaro:getGlobalValue(globalVarName))
--[[----- FIN INFORME DE RESULTADOS --------------------------------------------]]
--[[----------------------------------------------------------------------------]]
