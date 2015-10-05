--[[
%% properties
547 value
--]]

--[[ControlConsumoElect
	Escena
	controlConsumo.lua
	por Antonio Maestre & Manuel Pascual
------------------------------------------------------------------------------]]

--[[----- CONFIGURACION DE USUARIO -------------------------------------------]]
--[[----- FIN CONFIGURACION DE USUARIO ---------------------------------------]]

--[[----- NO CAMBIAR EL CODIGO A PARTIR DE AQUI ------------------------------]]

--[[----- CONFIGURACION AVANZADA ---------------------------------------------]]
local release = {name='ControlConsumoElect.controlConsumo', ver=2, mayor=0,
 minor=0}
globalVarName = 'controlConsumo'    -- nombre de variable global almacen consumo
OFF=1;INFO=2;DEBUG=3                -- referencia para el log
nivelLog = DEBUG                    -- nivel de log
--[[----- FIN CONFIGURACION AVANZADA -----------------------------------------]]

--[[
_log(level, log)
	funcion para operar el nivel de LOG
------------------------------------------------------------------------------]]
function _log(level, log)
  if log == nil then log = 'nil' end
  if nivelLog >= level then
    fibaro:debug(log)
  end
  return
end

--[[----------------------------------------------------------------------------
redondea(num, idp)
	--
--]]
function redondea(num, idp)
  local mult = 10^(idp or 0)
  return math.floor(num * mult + 0.5) / mult
end

--[[----------------------------------------------------------------------------
isEmptyVar(varName)
	comprueba si una variable global dada(varName) esta vacia
--]]
function isEmptyVar(varName)
  -- comprobar si esta vacia
  local valor, timestamp = fibaro:getGlobal(varName)
  if (not valor or valor == '0') then return true end
  return false
end

--[[----------------------------------------------------------------------------
getConsumo(consumoTab, stampIni, stampFin)
	devuelve el consumo desde el momento inicado hasta la actualidad o stampFin
--]]
function getConsumo(consumoTab, stampIni, stampFin)
  -- si no se indica el final se toma el momento actual
  if not stampFin then stampFin = os.time() end
  -- otener el consumo origen por si fuera necesario restarlo del total
  local consumoOrigen, stampOrigen = getConsumoOrigen()
  local consumo = 0
  for key, value in pairs(consumoTab) do
    local stampActual; stampActual = value.timeStamp
    if stampActual > stampIni and stampActual <= stampFin and
     stampActual ~= stampOrigen then
      consumo = consumo + value.kWh
    end
  end
  return consumo
end

--[[----------------------------------------------------------------------------
getConsumoOrigen(consumoTab)
	devuelve el consumo inicial valor, unidad, fecha mmddhh
--]]
function getConsumoOrigen(consumoTab)
  local estado; estado = consumoTab['estado']
  return  estado['consumoOrigen'].kWh
end

--[[----------------------------------------------------------------------------
setConsumo(timeStamp, valor)
	almacena el consumo
--]]
function setConsumo(globalVarName, timeStamp, valor)
  -- si no se indica el instante en el que se mide el consumo se toma el actual
  if not timeStamp then timeStamp = os.time() end
  local ctrlEnergia, consumo, estado
  -- recuperar la tabla desde la variable global
  ctrlEnergia = json.decode(fibaro:getGlobalValue(globalVarName))
  consumo = ctrlEnergia['consumo']
  estado = ctrlEnergia['estado']
  -- si no hay estado es que no se ha iniciado la tabla
  if not estado then
    -- guardar el consumo origen en la tabla de estado
    estado = {precio = getPrecio(), energia = getEnergia(),
     recomendado = recomendar(),
     consumoOrigen = {timeStamp = timeStamp, kWh = valor}}
  else
    -- guardar la diferencia consumo en la tabla de consumo
    consumo[#consumo + 1] = {timeStamp = timeStamp, kWh = valor}
  end
  -- grabar la tabla de control de energia
  ctrlEnergia['consumo'] = consumo
  ctrlEnergia['estado'] = estado
  -- guardar en la variable global
  fibaro:setGlobal(globalVarName, json.encode(consumoTab))
  end
  return 0
end

--[[----- COMIENZA LA EJECUCION ----------------------------------------------]]
-- averiguar ID del dispositivo que lanza la escena
local trigger = fibaro:getSourceTrigger()
-- si se inicia por cambio de consumo
local consumoAcumulado = 0
if trigger['type'] == 'property' then
  local deviceID = trigger['deviceID']
  local propertyName = trigger['propertyName']
  local consumoActual = tonumber(fibaro:getValue(deviceID, propertyName))
  _log(DEBUG, 'consumoActual: '.. consumoActual)
  local consumoAnterior = getConsumoOrigen() + getConsumo()
  _log(DEBUG, 'consumoAnterior: '.. consumoAnterior)
  consumoAcumulado = redondea(consumoActual - consumoAnterior, 3)
  _log(DEBUG, 'consumoAcumulado: '.. consumoAcumulado)
  -- almacenar consumo acumulado en la hora
  setConsumo(consumoAcumulado) -- la funcion se ancarga de acumular si procede
end
_log(DEBUG, fibaro:getGlobalValue(globalVarName))
--[[----- FIN DE LA EJECUCION ------------------------------------------------]]

--[[----- INFORME DE RESULTADOS ----------------------------------------------]]
_log(INFO, release['name']..
' ver '..release['ver']..'.'..release['mayor']..'.'..release['minor'])

_log(INFO, 'último consumo acumulado: '.. consumoAcumulado..' kWh')
--[[----- FIN INFORME DE RESULTADOS ------------------------------------------]]
--[[--------------------------------------------------------------------------]]
