--[[
%% properties
544 value
--]]

--[[ControlConsumoElect
	Escena
	controlConsumo.lua
	por Manuel Pascual
------------------------------------------------------------------------------]]

--[[----- CONFIGURACION DE USUARIO -------------------------------------------]]
--[[----- FIN CONFIGURACION DE USUARIO ---------------------------------------]]

--[[----- NO CAMBIAR EL CODIGO A PARTIR DE AQUI ------------------------------]]

--[[----- CONFIGURACION AVANZADA ---------------------------------------------]]
local release = {name='ControlConsumoElect.controlConsumo', ver=2, mayor=1,
 minor=1}
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
  un campo determinado que ha sido recientemente actualizado, devuelve su valor
--]]
function isSetVar(varName, campo, timeStamp)
  -- comprobar si esta vacia
  local tabla, newTimeStamp
  tabla, newTimeStamp = fibaro:getGlobal(varName)
  -- si no hay variableGlobal false
  if (not tabla) or (newTimeStamp == 0) then return false end
  -- recuperar la tabla desde la variableGlobal
  tabla = json.decode(tabla)
  -- si la variable aún no ha actualizado el campo
  if (not tabla[campo]) or (tabla[campo] == 0) or
   (tabla[campo] == '')  then
    return false
  end
  -- si se pasa un timestamp, además comprobar que el valor ha sido actualizado
  -- despues del timestamp pasado, sino devolver falso.
  if timeStamp then
    if newTimeStamp < timeStamp then return false end
  end
  -- retornar el valor del campo
  return tabla[campo]
end

--[[----------------------------------------------------------------------------
getConsumo(stampIni, stampFin)
	devuelve el consumo desde el momento inicado hasta la actualidad o stampFin
--]]
function getConsumo(stampIni, stampFin)
  local tablaEstado, tablaConsumo, consumo, importe
  -- recuperar la tabla de consumos
  tablaConsumo = json.decode(fibaro:getGlobalValue(cceConsumo))
  -- recuperar la tabla de estado
  tablaEstado = json.decode(fibaro:getGlobalValue(cceEstado))
  consumo = 0; importe = 0
  -- si no se indica el principio del ambito
  if not stampIni then
    -- se devuelve el total, el importe y el último timeStamp
    local stampAnterior, stampActual
    stampAnterior = 0
    -- si no hay medidas de consumo hay un error
    -- tomar el último timeStamp
    for key, value in pairs(tablaConsumo) do
      if value['kWh'] then consumo = consumo + value['kWh'] end
      if value['EUR'] then importe = importe + value['EUR'] end
      if value['timeStamp'] then
        stampActual = value['timeStamp']
        if stampActual > stampAnterior then stampAnterior = stampActual end
      end
    end
    return consumo, importe, stampAnterior
  elseif stampIni == 0 then -- si se indica 0 como inicio del ambito
    -- devolver el consumo origen
    return  tablaEstado['consumoOrigen'].kWh
  end
  -- si no se indica el final se toma el momento actual
  if not stampFin then stampFin = os.time() end
  -- se devuelve el total del ambito indicado (stampIni, stampFin) e importe
  for key, value in pairs(tablaConsumo) do
    local stampActual = value.timeStamp
    if stampActual > stampIni and stampActual <= stampFin then
      consumo = consumo + value.kWh
      importe = importe + value.EUR
    end
  end
  return consumo, importe
end

--[[----------------------------------------------------------------------------
getEnergia(valor, timeStamp)
	devuelve la potencia media entre la lectura anterior y la recibida
--]]
function getEnergia(valor, timeStamp)
  local consumoAnterior, importe, stampAnterior, energia, lapso
  -- obtener el stamp de la lectura anterior
  consumoAnterior, importe, stampAnterior = getConsumo()
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
  euroterminoconsumo = consumo * precioKWh
  -- si no se indica el instante en el que se mide el consumo tomar el actual
  if not timeStamp then timeStamp = os.time() end
  -- guardar el consumo como consumo acumulado
  -- recuperar tabla de consumos
  tablaConsumo = json.decode(fibaro:getGlobalValue(cceConsumo))
  _log(DEBUG, #tablaConsumo..' registros leidos')
  -- compactar tabla de consumos
  tablaConsumo = compactarConsumos(tablaConsumo, timeStamp)
  _log(DEBUG, #tablaConsumo..' registros despues de compactar')
  -- guardar la diferencia de consumo en la tabla de consumo
  tablaConsumo[#tablaConsumo + 1] =
   {timeStamp = timeStamp, kWh = consumo, EUR = euroterminoconsumo}

  -- recuperar tabla de estado
  tablaEstado = json.decode(fibaro:getGlobalValue(cceEstado))
  -- guardar la potencia media en el estado
  tablaEstado['energia'] = getEnergia(consumo, timeStamp)

  -- guardar los consumos acumulados e importes en la tabla de estado
  local consumosAcumulados = {}

  -- calcular consumo acumulado de la ultima hora
  local consumoUltimaHora, importeUltimaHora
  -- restar los segundos de una hora o desde la horaActual:00 ?
  consumoUltimaHora, importeUltimaHora = getConsumo(os.time() - 3600, os.time())
  _log(DEBUG, 'Consumo última hora: '..consumoUltimaHora)
  consumosAcumulados.kWHora = consumoUltimaHora
  consumosAcumulados.eurHora = importeUltimaHora

  -- calcular consumo acumulado del dia
  -- restar los segundos de un dia 24h o calcular desde las 00:00h?
  --consumoActual = getConsumo(os.time() - 3600 * 24, os.time())
  local stampIni, consumoAcumuladoDia, importeAcumuladoDia
  stampIni = os.time({year = tonumber(os.date('%Y')),
  month = tonumber(os.date('%m')), day = tonumber(os.date('%d')),
   hour = 0, min = 0, sec = 0})
  _log(DEBUG, 'El día comenzó: '..os.date('%d-%m-%Y/%H:%M:%S', stampIni))
  consumoAcumuladoDia, importeAcumuladoDia = getConsumo(stampIni, os.time())
  _log(DEBUG, 'Consumo último día: '..consumoAcumuladoDia)
  consumosAcumulados.kWDia = consumoAcumuladoDia
  consumosAcumulados.eurDia = importeAcumuladoDia

  -- calcular consumo del ultimo ciclo
  local consumoUltimoCiclo, euroterminoconsumo
  consumoUltimoCiclo, euroterminoconsumo = getConsumo()
  _log(DEBUG, 'Consumo último ciclo: '..consumoUltimoCiclo)
  consumosAcumulados.kWCiclo = consumoUltimoCiclo
  consumosAcumulados.eurCiclo = euroterminoconsumo

  -- almacenar en las variables globales
  tablaEstado['consumosAcumulados'] = consumosAcumulados
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
_log(DEBUG, '------------- Comienza la ejecución --------------')
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
if fibaro:countScenes() > 1 then
  _log(INFO, fibaro:countScenes()..' escenas en ejecución')
  _log(DEBUG, 'Esperando por otra anotación')
  fibaro:sleep(5000)
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

--[[ GUARDAR CONSUMO ACUMULADO -----------------------------------------------]]
-- averiguar ID del dispositivo que lanza la escena
local trigger = fibaro:getSourceTrigger()
-- si se inicia por cambio de consumo en el dispositivo físico
local consumoAcumulado = 0
if trigger['type'] == 'property' then
  --[[ OBTENER PRECIO HORA -----------------------------------------------------]]
  local precioActual
  local timeStamp = os.time(); fibaro:sleep(1000)
  -- para actualizar precio se invoca al botón update del VD
  fibaro:call(VDId, "pressButton", "6")
  -- esperar hasta que el precio se haya actualizado, con el uso de timeStamp,
  -- nos aseguramos de que el campo se ha actualizado recientemente
  while not isSetVar(cceEstado, 'preciokwh', timeStamp) do
    _log(DEBUG, 'Esperando precio...')
    fibaro:sleep(1000)
  end
  precioActual = isSetVar(cceEstado, 'preciokwh')
  _log(DEBUG, 'Precio actual: '..precioActual)

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
  setConsumo(consumoAcumulado, precioActual)

  --[[----- INFORME DE RESULTADOS --------------------------------------------]]
  -- leer lecturas de consumo acumuladas en la variableGlobal
  local tablaConsumo = json.decode(fibaro:getGlobalValue(cceConsumo))
  _log(INFO, 'Lecturas acumuladas: '..#tablaConsumo)
  _log(INFO, 'Último consumo: '..
   os.date('%d/%m/%Y-%H:%M:%S',  tablaConsumo[#tablaConsumo].timeStamp)..' '..
   tablaConsumo[#tablaConsumo].kWh..'kWh')
  --[[----- FIN INFORME DE RESULTADOS ----------------------------------------]]
else
  _log(INFO, 'No hay nuevos consumos anotados')
end
--[[----- FIN DE LA EJECUCION ------------------------------------------------]]
_log(DEBUG, '--------------- Fin de la ejecución ----------------')
--[[--------------------------------------------------------------------------]]
