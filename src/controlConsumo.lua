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
local release = {name='ControlConsumoElect.controlConsumo', ver=2, mayor=1,
 minor=0}
cceEstado = 'cceEstado'     -- nombre variable global para almacenar el estado
cceConsumo = 'cceConsumo'   -- nombre variable global para almacenar consumos
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
	comprueba si exite la variableGlobal y si la tabla que contiene tiene definido
  un campo determinado devuelve su valor
--]]
function isSetVar(varName, campo)
  -- comprobar si esta vacia
  local tabla, timestamp
  tabla, timestamp = fibaro:getGlobal(varName)
  -- si no hay variableGlobal false
  if (not tabla) or (timestamp == 0) then return false end
  -- intentar recuperar la tabla desde la variableGlobal
  tabla = json.decode(tabla)
  -- si la variable aún no ha actualizado el campo
  if (not tabla) or (not tabla[campo]) or
   (tabla[campo] == 0) or (tabla[campo] == '')  then
    return false
  end
  -- retornar el valor del campo
  return tabla[campo]
end

--[[----------------------------------------------------------------------------
getConsumo(stampIni, stampFin)
	devuelve el consumo desde el momento inicado hasta la actualidad o stampFin
--]]
function getConsumo(stampIni, stampFin)
  local tablaEstado, tablaConsumo, consumo
  -- recuperar la tabla de consumos
  tablaConsumo = json.decode(fibaro:getGlobalValue(cceConsumo))
  -- recuperar la tabla de estado
  tablaEstado = json.decode(fibaro:getGlobalValue(cceEstado))
  consumo = 0
  -- si no se indica el principio del ambito
  if not stampIni then
    -- se devuelve el total y el último timeStamp
    local stampAnterior, stampActual
    -- si no hay medidas de consumo hay un error
    stampAnterior = 0
    -- tomar el último timeStamp
    for key, value in pairs(tablaConsumo) do
      if value['kWh'] then consumo = consumo + value['kWh'] end
      if value['timeStamp'] then
        stampActual = value['timeStamp']
        if stampActual > stampAnterior then stampAnterior = stampActual end
      end
    end
    return consumo, stampAnterior
  elseif stampIni == 0 then -- si se indica 0 como inicio del ambito
    -- devolver el consumo origen
    return  tablaEstado['consumoOrigen'].kWh
  end
  -- si no se indica el final se toma el momento actual
  if not stampFin then stampFin = os.time() end
  -- se devuelve el total del ambito indicado (stampIni, stampFin)
  for key, value in pairs(tablaConsumo) do
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
  local stampAnterior, energia, lapso
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
function setConsumo(consumo, precioKWh, timeStamp)
  local tablaConsumo, tablaEstado, euroterminoconsumo
  -- calcular el importe
  euroterminoconsumo = redondea(consumo * precioKWh, 3)
  -- si no se indica el instante en el que se mide el consumo tomar el actual
  if not timeStamp then timeStamp = os.time() end
  -- guardar el consumo como consumo acumulado
  -- recuperar tabla de consumos
  tablaConsumo = json.decode(fibaro:getGlobalValue(cceConsumo))
  _log(DEBUG, #consumo..' registros leidos')
  -- recuperar tabla de estado
  tablaEstado = json.decode(fibaro:getGlobalValue(cceEstado))
  -- compactar tabla de consumos
  tablaConsumo = compactarConsumos(tablaConsumo, timeStamp)
  _log(DEBUG, #tablaConsumo..' registros despues de compactar')
  -- guardar la diferencia de consumo en la tabla de consumo
  tablaConsumo[#tablaConsumo + 1] =
   {timeStamp = timeStamp, kWh = consumo, EUR = euroterminoconsumo}
  -- guardar la potencia media en el estado
  tablaEstado['energia'] = getEnergia(consumo, timeStamp)
  -- almacenar en las variables globales
  fibaro:setGlobal(cceEstado, json.encode(tablaEstado))
  fibaro:setGlobal(cceConsumo, json.encode(tablaConsumo))
  return 0
end

--[[----------------------------------------------------------------------------
compactarConsumos(consumo, timeStamp)
	compacta la tabla de consumos agrupando todos los registro anteriores a
  compactaHora horas
--]]
function compactarConsumos(consumo, timeStamp)
  _log(DEBUG, 'Compactando tabla de consumos...')
  local stampAcumulado, kWhAcumulado, importeAcumulado
  kWhAcumulado = 0
  importeAcumulado = 0
  -- Borrar elementos del array es un problema clásico  que se puede resolver
  -- fácilmente con un bucle hacia atrás
  for key = #consumo, 1, -1 do
    local value = consumo[key]
    if value['timeStamp'] and
     value.timeStamp < (timeStamp - compactaHora * 3600) then
      -- acumular kWh, importe y guardar timestamp
      kWhAcumulado = kWhAcumulado + value['kWh']
      importeAcumulado = importeAcumulado + value['EUR']
      stampAcumulado = value['timeStamp']
      -- eliminar registro acumulado
      _log(DEBUG, 'registro compactado')
      table.remove(consumo, key)
    end
  end
  -- guardar el registro del consumo e importe acumulados
  if kWhAcumulado > 0 then
    table.insert(consumo, {timeStamp = stampAcumulado, kWh = kWhAcumulado,
     EUR = importeAcumulado})
  end
  -- retornar tabla de consumos compactada
  return consumo
end

--[[----- COMIENZA LA EJECUCION ----------------------------------------------]]
_log(INFO, release['name']..
' ver '..release['ver']..'.'..release['mayor']..'.'..release['minor'])
_log(DEBUG, '---------- Comienza la ejecución ----------')
-- comprobar si existe la variable global y si no esperar hasta que esté
-- inicializada
while not isSetVar(cceEstado, 'VDId') do
  _log(DEBUG, 'Esperando reseteo...')
  fibaro:sleep(1000)
  -- si se inicia otra escena esta se suicida
  if fibaro:countScenes() > 1 then
    _log(DEBUG, 'terminado por nueva actividad')
    fibaro:abort()
  end
end
-- obtener el id del VD
local VDId
VDId = isSetVar(cceEstado, 'VDId')

-- si hay otra escena en ejecución esperar a que termine
while fibaro:countScenes() > 1 do
  _log(DEBUG, 'Esperando por otra anotación')
end

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
local precioActual
-- para actualizar precio se invoca al botón update del VD
fibaro:call(VDId, "pressButton", "6")
_log(DEBUG, 'Esperando precio...')
-- esperar para actualizar el precio
fibaro:sleep(5000)
precioActual = isSetVar(cceEstado, 'preciokwh')
if not precioActual then
  _log(INFO, 'ERROR: No se pudo obteber el preciokwh')
  fibaro:abort()
end
_log(DEBUG, 'Precio actual: '..precioActual)

--[[ GUARDAR CONSUMO ACUMULADO -----------------------------------------------]]
-- averiguar ID del dispositivo que lanza la escena
local trigger = fibaro:getSourceTrigger()
-- si se inicia por cambio de consumo en el dispositivo físico
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
end
--[[----- FIN DE LA EJECUCION ------------------------------------------------]]

--[[----- INFORME DE RESULTADOS ----------------------------------------------]]
-- leer lecturas de consumo acumuladas en la variableGlobal
local tablaConsumo = json.decode(fibaro:getGlobalValue(cceConsumo))
_log(DEBUG, 'Lecturas acumuladas: '..#tablaConsumo)
if #tablaConsumo > 0 then
  _log(DEBUG, 'Último consumo: '..
   os.date('%d/%m/%Y-%H:%M:%S',  tablaConsumo[#tablaConsumo].timeStamp)..' '..
   tablaConsumo[#tablaConsumo].kWh..'kWh')
 end
--[[----- FIN INFORME DE RESULTADOS ------------------------------------------]]
--[[--------------------------------------------------------------------------]]
