--[[ControlConsumoElect
	Dispositivo virtual
	resetButton.lua
	por Antonio Maestre & Manuel Pascual
------------------------------------------------------------------------------]]

--[[----- CONFIGURACION DE USUARIO -------------------------------------------]]
energyDev = 547           -- ID del dispositivo de energia
propertyName = 'value'		-- propiedad del dispositivo para recuperar la energia
--[[----- FIN CONFIGURACION DE USUARIO ---------------------------------------]]

--[[----- NO CAMBIAR EL CODIGO A PARTIR DE AQUI ------------------------------]]

--[[----- CONFIGURACION AVANZADA ---------------------------------------------]]
local release = {name='ControlConsumoElect.resetButton', ver=0, mayor=0,
 minor=3}
local _selfId = fibaro:getSelfId()  -- ID de este dispositivo virtual
globalVarName = 'consumoEnergia'    -- nombre de la variable global
OFF=1;INFO=2;DEBUG=3                -- referencia para el log
nivelLog = DEBUG                    -- nivel de log
--[[consumoTab
  tabla para almacenar consumos horarios, se usa el indice para almacenar
  la hora, dia y mes 'mmddhh' y una tabla con el valor y la unidad, ej.
  consumo de las 12 de la mañana del dia 17 de septiembre
  consumo['121709'] = {valor=0.1234, unidad=kWh'}
  --]]
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

--[[----------------------------------------------------------------------------
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

--[[----------------------------------------------------------------------------
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

--[[----------------------------------------------------------------------------
getOrigen()
	devuelve fecha origen en formato mmddhh
--]]
function getOrigen()
  local consumoTab = json.decode(fibaro:getGlobalValue(globalVarName))
  -- ordenar la tabla para compara tomar el primer valor
  local u = {}
  for k, v in pairs(consumoTab) do table.insert(u, { key = k, value = v }) end
  table.sort(u, function (a1, a2) return a1.key < a2.key; end)
  return u[1].key
end

--[[------- INICIA LA EJECUCION ----------------------------------------------]]
-- resetear la tabla de consumos
local status = resetConsumo()

-- proponer como dia de inicio de ciclo el mismo dias del mes siguiente a la
-- fecha origen de ciclo actual
-- obtener fecha origen
local clave; clave = getOrigen()
-- otener dia, mes y año de la fecha origen
local dia = tonumber(string.sub(clave, 3, 4))
local mes = tonumber(string.sub(clave, 1, 2))
local anno = tonumber(os.date('%Y'))
-- averiguar los dias que tiene el mes
local diasDelMes = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}
local dias = diasDelMes[tonumber(mes)]
-- averiguar los segundos que tiene el mes
local segs = 86400 * dias
-- saltar un mes
local fecha = os.date('%d/%m/%y', os.time({month = mes, day = dia,
 year = anno}) + segs)
 -- refrescar la etiqueta diaInicioCiclo
fibaro:call(_selfId, 'setProperty', 'ui.diaInicioCiclo.value', fecha)
_log(DEBUG, fecha)

-- invocar al boton de actualizacion de datos
fibaro:call(_selfId, "pressButton", "14")
--[[----- FIN DE LA EJECUCION ------------------------------------------------]]

--[[----- INFORME DE RESULTADOS ----------------------------------------------]]
_log(INFO, release['name']..
' ver '..release['ver']..'.'..release['mayor']..'.'..release['minor'])

_log(INFO, fibaro:getGlobalValue(globalVarName))
--[[----- FIN INFORME DE RESULTADOS ------------------------------------------]]
--[[--------------------------------------------------------------------------]]
