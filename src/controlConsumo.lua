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
globalVarName = 'consumoEnergia'-- nombre de la variable global para almacenar
								-- consumo
--[[----- FIN CONFIGURACION DE USUARIO ---------------------------------------]]

--[[----- NO CAMBIAR EL CODIGO A PARTIR DE AQUI ------------------------------]]

--[[----- CONFIGURACION AVANZADA ---------------------------------------------]]
OFF=1;INFO=2;DEBUG=3  -- esto es una referencia para el log, no cambiar
nivelLog = DEBUG      -- nivel de log
release = {name='controlConsumo', ver=0, mayor=0, minor=2}
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
getConsumo(a, b, c)
	devuelve el consumo del mes, dia del mes u hora del dia del mes.
	si no se pasan parametros se vevuel el total acumulado
	si se pasa 1 argumento,   se considera el (mes)
	si se pasan 2 argumentos, se consideran (dia, mes)
	si se pasan 3 argumentos, se consideran (hora, dia, mes)
--]]
function getConsumo(a, b, c)
  local consumoTab = json.decode(fibaro:getGlobalValue(globalVarName))
  local clave = ''
  -- otener el consumo origen por si fuera necesario restarlo del total
  local consumoIni, unidadIni, claveIni = getConsumoOrigen()
  if not a then
   local clave = ' '
  elseif not b then
    clave = string.format('%.2d',a)
  elseif not c then
    clave= string.format('%.2d',b)..string.format('%.2d',a)
  else
    clave= string.format('%.2d',c)..string.format('%.2d',b)..
    string.format('%.2d',a)
  end
  local consumo = 0
  for key, value in pairs(consumoTab) do
    if (clave == string.sub(key, 1, #clave)) and (key ~= claveIni) then
      consumo = consumo + value.valor
      unidad = value.unidad
    end
    -- consumo = consumo + getConsumoDia(d,mes)
  end
  -- retirar el consumo inicial
  return consumo, unidad
end

--[[----------------------------------------------------------------------------
getConsumoOrigen()
	devuelve el consumo inicial valor, unidad, fecha mmddhh
--]]
function getConsumoOrigen()
  local consumoTab = json.decode(fibaro:getGlobalValue(globalVarName))
  -- ordenar la tabla para compara tomar el primer valor
  local u = {}
  for k, v in pairs(consumoTab) do table.insert(u, { key = k, value = v }) end
  table.sort(u, function (a1, a2) return a1.key < a2.key; end)
  return u[1].value.valor, u[1].value.unidad, u[1].key
end

--[[----------------------------------------------------------------------------
setConsumo(hora, dia, mes, valor)
	almacena el consumo horario.
	si se pasa 1 parametro lo almacena en la hora actual del sistema (valor)
	en otro caso debe recibir 4 parametros indicando (hora, dia, mes, valor)
	si la clave 'mesdiahora' exite el valor se acumula al anterior
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
  -- no grabar si la clave coincide con la del consumo en origen
  local valorOrg, unidadOrg, claveOrg = getConsumoOrigen()
  if indConsumo ~= claveOrg then
    -- si la clave ya existe, acumular el valor
    if consumoTab[indConsumo] then
      valor = valor + consumoTab[indConsumo].valor
    end
    -- grabar el valor en la tabla
    consumoTab[indConsumo] = {valor = valor, unidad = 'kWh'}
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
