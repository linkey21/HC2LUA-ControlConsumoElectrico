--[[
%% properties
512 energy
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
globalVarName = 'consumoV2'    -- nombre de variable global almacen consumo
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
  if (not valor or valor == nil or valor == '0') then return true end
  return false
end

--[[----------------------------------------------------------------------------
getConsumo(consumoTab, stampIni, stampFin)
	devuelve el consumo desde el momento inicado hasta la actualidad o stampFin
--]]
function getConsumo(stampIni, stampFin)
  -- intentar recuperar la tabla de conrol de energia desde la variable
  ctrlEnergia = json.decode(fibaro:getGlobalValue(globalVarName))
  local consumoTab, consumo
  consumoTab = ctrlEnergia['consumo']
  consumo = 0
  -- si no se indica el principio del ambito
  if not stampIni then
    -- se devuelve el total
    for key, value in pairs(consumoTab) do
        consumo = consumo + value.kWh
    end
    return consumo
  elseif stampIni == 0 then -- si se indica 0 como inicio del ambito
    -- devolver el consumo origen
    return  ctrlEnergia['estado']['consumoOrigen'].kWh
  end
  -- si no se indica el final se toma el momento actual
  if not stampFin then stampFin = os.time() end
  -- se devuelve el total del ambito indicado (stampIni, stampFin)
  for key, value in pairs(consumoTab) do
    local stampActual; stampActual = value.timeStamp
      if stampActual > stampIni and stampActual <= stampFin and
        stampActual ~= stampOrigen then
        consumo = consumo + value.kWh
      end
  end
  return consumo
end

function getPrecio()
  --
  return 0
end

function getEnergia()
  --
  return 0
end

function recomendar()
  --
  return false
end



--[[----------------------------------------------------------------------------
setConsumo(timeStamp, valor)
	almacena el consumo
--]]
function setConsumo(valor, timeStamp)
  local ctrlEnergia, consumo, estado
  --si no se recive nada es que hay que inicializar la variable
  if not valor then
    -- crear una tabla vacia
    ctrlEnergia = {consumo = {}, estado = {}}
    -- guardar el consumo como origen en la tabla de estado
    estado = {precio = getPrecio(), energia = getEnergia(),
     recomendado = recomendar(),
     consumoOrigen = {timeStamp = timeStamp, kWh = valor}}
    consumo = {}
  else
    -- si no se indica el instante en el que se mide el consumo se toma el actual
    if not timeStamp then timeStamp = os.time() end
    -- recuperar la tabla desde la variable global
    ctrlEnergia = json.decode(fibaro:getGlobalValue(globalVarName))
    -- tabla de consumos
    consumo = ctrlEnergia['consumo']
    -- tabla de estado
    estado = ctrlEnergia['estado']
    -- guardar la diferencia consumo en la tabla de consumo
    consumo[#consumo + 1] = {timeStamp = timeStamp, kWh = valor}
  end
  -- almacenar en la tabla de control de energia el estado y el consumo
  ctrlEnergia['consumo'] = consumo
  ctrlEnergia['estado'] = estado
  -- guardar en la variable global
  fibaro:setGlobal(globalVarName, json.encode(ctrlEnergia))
  return 0
end

--[[----- COMIENZA LA EJECUCION ----------------------------------------------]]
-- averiguar ID del dispositivo que lanza la escena
local trigger = fibaro:getSourceTrigger()
-- si se inicia por cambio de consumo
local consumoAcumulado = 0
if trigger['type'] == 'property' then
  local deviceID, propertyName, consumoActual, consumoAnterior, ctrlEnergia
  deviceID = trigger['deviceID']
  propertyName = trigger['propertyName']
  consumoActual = tonumber(fibaro:getValue(deviceID, propertyName))
  _log(DEBUG, 'consumoActual: '.. consumoActual)
  -- si la variable global esta vacia
  if isEmptyVar(globalVarName) then
    -- iniciar la tabla
    _log(DEBUG, 'variable vacia')
    setConsumo()
  else -- si existe
    -- calcular el cosumo anterior
    consumoAnterior = getConsumo() + getConsumo(0)
    _log(DEBUG, 'consumoAnterior: '.. consumoAnterior)
    consumoAcumulado = redondea(consumoActual - consumoAnterior, 3)
    _log(DEBUG, 'consumoAcumulado: '.. consumoAcumulado)
    -- almacenar consumo
    setConsumo(consumoAcumulado)
  end
  _log(DEBUG, fibaro:getGlobalValue(globalVarName))
end
--[[----- FIN DE LA EJECUCION ------------------------------------------------]]

--[[----- INFORME DE RESULTADOS ----------------------------------------------]]
_log(INFO, release['name']..
' ver '..release['ver']..'.'..release['mayor']..'.'..release['minor'])

_log(INFO, 'último consumo acumulado: '.. consumoAcumulado..' kWh')
--[[----- FIN INFORME DE RESULTADOS ------------------------------------------]]
--[[--------------------------------------------------------------------------]]
