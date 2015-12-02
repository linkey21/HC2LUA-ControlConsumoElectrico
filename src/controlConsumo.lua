--[[
%% properties
544 value
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
globalVarName = 'consumoV2' -- nombre de variable global almacen consumo
compactaHora = 48           -- 48h
OFF=1;INFO=2;DEBUG=3        -- referencia para el log
nivelLog = DEBUG            -- nivel de log
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
isSetVar(varName)
	comprueba si exite la variableGlobal y si contiene un valor de estado y
  devuelve su valor
--]]
function isSetVar(varName, value)
  -- comprobar si esta vacia
  local valor, ctrlConsumo, timestamp
  valor, timestamp = fibaro:getGlobal(varName)
  -- si no hay variableGlobal false
  if (not valor) or (timestamp == 0) then return false end
  -- intentar recuperar la tabla de consumos desde la variableGlobal
  ctrlConsumo = json.decode(valor)
  -- si la variable aún ha actualizado el valor [value]
  if (not ctrlConsumo) or (not ctrlConsumo['estado'][value]) or
   (ctrlConsumo['estado'][value] == 0) then
    return false
  end
  -- retornar el valor de [value]
  return ctrlConsumo['estado'][value]
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
      if stampActual > stampIni and stampActual <= stampFin then
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
  -- si no se recibe nada inicializar la variable
  if not valor then
    -- crear una tabla vacia
    ctrlEnergia = {}
    estado = {recomendacion = 0, energia = 0,
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
      estado = {recomendacion = 0, energia = 0,
       consumoOrigen = {timeStamp = timeStamp, kWh = valor}}
      consumo = {} --; consumo[#consumo + 1] = {}
    else -- guardar el consumo como consumo acumulado

      -- tabla de consumos
      consumo = ctrlEnergia['consumo']
      _log(DEBUG, #consumo..' registros leidos')
      -- tabla de estado
      estado = ctrlEnergia['estado']
      -- compactar tabla de consumos
      consumo = compactarConsumos(consumo, timeStamp)
      _log(DEBUG, #consumo..' registros despues de compactar')
      -- guardar la diferencia de consumo en la tabla de consumo
      consumo[#consumo + 1] = {timeStamp = timeStamp, kWh = valor}
      -- guardar la potencia media en el estado
      estado['energia'] = getEnergia(valor, timeStamp)
    end
  end
  -- almacenar en la tabla de control de energia el estado y el consumo
  ctrlEnergia['consumo'] = consumo
  ctrlEnergia['estado'] = estado
  -- guardar en la variable global
  _log(DEBUG, #consumo..' registros antes de guardar')
  _log(DEBUG, json.encode(ctrlEnergia))
  fibaro:setGlobal(globalVarName, json.encode(ctrlEnergia))
  _log(DEBUG, 'Consumo almacenado: '..
   os.date('%d/%m/%Y-%H:%M:%S',  ctrlEnergia['consumo'][#consumo].timeStamp)..
   ' '..ctrlEnergia['consumo'][#consumo].kWh..'kWh')
  return 0
end

--[[----------------------------------------------------------------------------
compactarConsumos(consumo, timeStamp)
	compacta la tabla de consumos agrupando todos los registro anteriores a
  compactaHora horas
--]]
function compactarConsumos(consumo, timeStamp)
  _log(DEBUG, 'Compactando tabla de consumos...')
  local stampAcumulado, kWhAcumulado
  kWhAcumulado = 0
  -- Borrar elementos del array es un problema clásico  que se puede resolver
  -- fácilmente con un bucle hacia atrás
  for key = #consumo, 1, -1 do
    local value = consumo[key]
    if value['timeStamp'] and
     value.timeStamp < (timeStamp - compactaHora * 3600) then
      -- acumular kWh y guardar timestamp
      kWhAcumulado = kWhAcumulado + value['kWh']
      stampAcumulado = value['timeStamp']
      -- eliminar registro acumulado
      _log(DEBUG, 'registro compactado')
      table.remove(consumo, key)
    end
  end
  -- guardar el registro del consumo acumulado
  if kWhAcumulado > 0 then
    table.insert(consumo, {timeStamp = stampAcumulado, kWh = kWhAcumulado})
  end
  -- retornar tabla de consumos compactada
  return consumo
end

--[[----- COMIENZA LA EJECUCION ----------------------------------------------]]
_log(DEBUG, 'COMIENZA LA EJECUCION')
-- comprobar si existe la variable global y si no crearla
-- esperar hasta que la variable global esté inicializada
while not isSetVar(globalVarName, 'VDId') do
  _log(DEBUG, 'Esperando reseteo...')
  fibaro:sleep(1000)
  -- si se inicia otra escena esta se suicida
  if fibaro:countScenes() > 1 then
    _log(DEBUG, 'terminado por nueva actividad')
    fibaro:abort()
  end
end

-- si hay otra escena en ejecución esperar a que termine
while fibaro:countScenes() > 1 do
  _log(DEBUG, 'Esperando por otra anotación')
end

-- obtener el id del VD
local VDId
VDId = isSetVar(globalVarName, 'VDId')

--[[ CADA CICLO DE FACTUARCION -----------------------------------------------]]
local fechaFinCiclo
fechaFinCiclo = fibaro:get(VDId, 'ui.diaInicioCiclo.value')
_log(DEBUG, 'Próximo inicio de ciclo: '..fechaFinCiclo)
-- ajustar cambio de año
if (fechaFinCiclo == os.date('%d/%m/%y')) then
  -- invocar al boton de reseteo de datos iniciar ciclo
  fibaro:call(VDId, "pressButton", "5")
  -- esperar para que el ciclo se reinicie
  fibaro:sleep(5000)
  _log(DEBUG, 'próximo reinicio de ciclo: '..
   fibaro:get(VDId, 'ui.diaInicioCiclo.value'))
end

--[[ OBTENER PRECIO HORA -----------------------------------------------------]]
-- para obtener precio se invoca al botón update del VD
local precioActual
fibaro:call(VDId, "pressButton", "6")
--esperar hasta obtener el precio
while not isSetVar(globalVarName, 'preciokwh') do
  _log(DEBUG, 'Esperando precio...')
  fibaro:sleep(1000)
  -- si se inicia otra escena esta se suicida
  if fibaro:countScenes() > 1 then
    _log(DEBUG, 'terminado por nueva actividad')
    fibaro:abort()
  end
end
precioActual = isSetVar(globalVarName, 'precio')

--[[ GUARDAR CONSUMO ACUMULADO -----------------------------------------------]]
-- averiguar ID del dispositivo que lanza la escena
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

  -- obtener el cosumo anterior
  consumoAnterior = getConsumo() + getConsumo(0)
  _log(DEBUG, 'consumoAnterior: '.. consumoAnterior)

  -- calcular consumo acumulado
  consumoAcumulado = redondea(consumoActual - consumoAnterior, 3)
  _log(DEBUG, 'consumoAcumulado: '.. consumoAcumulado)

  -- almacenar consumo
  setConsumo(consumoAcumulado)
  --_log(DEBUG, fibaro:getGlobalValue(globalVarName))

  -- leer lecturas de consumo acumuladas en la variableGlobal
  ctrlEnergia = json.decode(fibaro:getGlobalValue(globalVarName))
  local consumo = ctrlEnergia.consumo
  _log(DEBUG, 'Lecturas acumuladas: '..#consumo)
  _log(DEBUG, 'Último consumo: '..
   os.date('%d/%m/%Y-%H:%M:%S',  ctrlEnergia['consumo'][#consumo].timeStamp)..
   ' '..ctrlEnergia['consumo'][#consumo].kWh..'kWh')
end
--[[----- FIN DE LA EJECUCION ------------------------------------------------]]

--[[----- INFORME DE RESULTADOS ----------------------------------------------]]
_log(INFO, release['name']..
' ver '..release['ver']..'.'..release['mayor']..'.'..release['minor'])

_log(INFO, 'último consumo acumulado: '.. consumoAcumulado..' kWh')
--[[----- FIN INFORME DE RESULTADOS ------------------------------------------]]
--[[--------------------------------------------------------------------------]]
