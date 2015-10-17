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
isVariable(varName)
	comprueba si existe una variable global dada(varName)
--]]
function isVariable(varName)
  -- comprobar si existe
  local valor, timestamp = fibaro:getGlobal(varName)
  if (valor and  timestamp > 0) then return true end
  return false
end

--[[----------------------------------------------------------------------------
isEmptyVar(varName)
	comprueba si una variable global dada(varName) esta vacia
--]]
function isEmptyVar(varName)
  -- comprobar si esta vacia
  local valor, timestamp = fibaro:getGlobal(varName)
  if (valor == nil or not valor or valor == '0') then return true end
  return false
end

--[[----------------------------------------------------------------------------
getConsumo(stampIni, stampFin)
	devuelve el consumo desde el momento inicado hasta la actualidad o stampFin
--]]
function getConsumo(stampIni, stampFin)
  local consumoTab, consumo, ctrlEnergia
  -- intentar recuperar la tabla de control de energia desde la variable
  ctrlEnergia = json.decode(fibaro:getGlobalValue(globalVarName))
  consumoTab = ctrlEnergia['consumo']
  consumo = 0
  -- si no se indica el principio del ambito
  if not stampIni then
    -- se devuelve el total y el último timeStamp
    local stampAnterior, stampActual
    -- si no hay medidas de consumo hay un error
    stampAnterior = 0
    -- tomar el último timeStamp
    for key, value in pairs(consumoTab) do
      if value['kWh'] then consumo = consumo + value['kWh'] end
      if value['timeStamp'] then
        stampActual = value['timeStamp']
        if stampActual > stampAnterior then stampAnterior = stampActual end
      end
    end
    return consumo, stampAnterior
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

--[[----------------------------------------------------------------------------
getEnergia(valor, timeStamp)
	devuelve la potencia media entre la lectura anterior y la recibida
--]]
function getEnergia(valor, timeStamp)
  local consumoOrigen, stampAnterior, consumoLapso, energia, lapso
  -- obtener el stamp de la lectura anterior
  consumoAnterior, stampAnterior = getConsumo()
  lapso = timeStamp - stampAnterior
  energia = redondea (1000 * ((valor * 3600)/lapso), 3)
  _log(DEBUG, 'Energía: '..energia..' W')
  return energia
end


--[[----------------------------------------------------------------------------
setConsumo(valor, timeStamp)
	almacena el consumo
--]]
function setConsumo(valor, timeStamp)
  local ctrlEnergia, consumo, estado
  --si no se recive nada inicializar la variable
  if not valor then
    -- crear una tabla vacia
    ctrlEnergia = {}
    estado = {energia = 0,
     consumoOrigen = {timeStamp = os.time(), kWh = 0}}
    consumo = {}; consumo[#consumo + 1] = {}
  else
    -- si no se indica el instante en el que se mide el consumo tomar el actual
    if not timeStamp then timeStamp = os.time() end
    -- intentar recuperar la tabla de control de energia desde la variable
    ctrlEnergia = json.decode(fibaro:getGlobalValue(globalVarName))
    -- comprobar si la variable ya tiene el consumo en origien
    if (not ctrlEnergia['estado']['consumoOrigen']) or
    (ctrlEnergia['estado']['consumoOrigen'].kWh == 0) then
      -- guardar el valor como consumo origen
      estado = {energia = 0,
       consumoOrigen = {timeStamp = timeStamp, kWh = valor}}
      consumo = {} --; consumo[#consumo + 1] = {}
    else -- guardar el consumo como consumo acumulado
      -- tabla de consumos
      consumo = ctrlEnergia['consumo']
      -- tabla de estado
      estado = ctrlEnergia['estado']
      -- guardar la diferencia consumo en la tabla de consumo
      consumo[#consumo + 1] = {timeStamp = timeStamp, kWh = valor}
      -- guardar la potencia media en el estado
      estado['energia'] = getEnergia(valor, timeStamp)
    end
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
_log(DEBUG, 'COMIENZA LA EJECUCION')
-- la variable global no existe
if not isVariable(globalVarName) then
  fibaro:debug('Declarar variable global '..globalVarName)
  fibaro:abort()
end
-- si la variable global esta vacia inicializarla
if isEmptyVar(globalVarName) then
  setConsumo()
end
local trigger = fibaro:getSourceTrigger()
-- si se inicia por cambio de consumo
local consumoAcumulado = 0
if trigger['type'] == 'property' then
  local deviceID, propertyName, consumoActual, consumoAnterior, ctrlEnergia
  deviceID = trigger['deviceID']
  propertyName = trigger['propertyName']
  -- obtener el consumo desde el dispositivo físico
  consumoActual = tonumber(fibaro:getValue(deviceID, propertyName))
  _log(DEBUG, 'consumoActual: '.. consumoActual)
  -- calcular el cosumo anterior
  consumoAnterior = getConsumo() + getConsumo(0)
  _log(DEBUG, 'consumoAnterior: '.. consumoAnterior)
  consumoAcumulado = redondea(consumoActual - consumoAnterior, 3)
  _log(DEBUG, 'consumoAcumulado: '.. consumoAcumulado)
  -- almacenar consumo
  setConsumo(consumoAcumulado)
  _log(DEBUG, fibaro:getGlobalValue(globalVarName))
end
--[[----- FIN DE LA EJECUCION ------------------------------------------------]]

--[[----- INFORME DE RESULTADOS ----------------------------------------------]]
_log(INFO, release['name']..
' ver '..release['ver']..'.'..release['mayor']..'.'..release['minor'])

_log(INFO, 'último consumo acumulado: '.. consumoAcumulado..' kWh')
--[[----- FIN INFORME DE RESULTADOS ------------------------------------------]]
--[[--------------------------------------------------------------------------]]
