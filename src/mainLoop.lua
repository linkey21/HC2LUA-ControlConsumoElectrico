--[[ControlConsumoElect
	Dispositivo virtual
	mainLoop.lua
	por Antonio Maestre & Manuel Pascual
------------------------------------------------------------------------------]]

--[[----- CONFIGURACION DE USUARIO -------------------------------------------]]
--[[----- FIN CONFIGURACION DE USUARIO ---------------------------------------]]

--[[----- NO CAMBIAR EL CODIGO A PARTIR DE AQUI ------------------------------]]

--[[----- CONFIGURACION AVANZADA ---------------------------------------------]]
local release = {name='ControlConsumoElect.mainLoop', ver=0, mayor=0, minor=4}
local _selfId = fibaro:getSelfId()  -- ID de este dispositivo virtual
local diaCambioCiclo = fibaro:get(_selfId, 'ui.diaInicioCiclo.value')
diaCambioCiclo = tonumber(string.sub(diaCambioCiclo, 1, 2))
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
setEstado()
	configura el estado del dispositivo virtual
--]]
function setEstado(estado, mensaje)
  if estado then
    mensaje = 'RUNNING: '..mensaje
  else
    mensaje = 'STOPPED: '..mensaje
  end
  -- referscar etiqueta de estado
  fibaro:call(_selfId, 'setProperty', 'ui.lbStatus.value', mensaje)
  return estado
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
	comprueba si existe una variable global dada(varName)
--]]
function isEmptyVar(varName)
  -- comprobar si esta vacia
  local valor, timestamp = fibaro:getGlobal(varName)
  if (not valor or valor == '0') then return true end
  return false
end


--[[----- COMIENZA LA EJECUCION ----------------------------------------------]]
_log(INFO, release['name']..
' ver '..release['ver']..'.'..release['mayor']..'.'..release['minor'])
-- configurar el estado del dispositivo
estadoDispositivo = setEstado(true, 'Iniciando...')

-- esperar si no existe la variable local para almacenar consumos
while not isVariable(globalVarName) do
  fibaro:sleep(1000)
  -- refrescar la etiqueta status
  setEstado(false, 'Definir variable global')
end
-- cambiar el estado
setEstado(true, 'Arrancando...')
-- si la variable esta vacia
if isEmptyVar(globalVarName) then
  -- invocar al boton reset de datos para iciar el ciclo
  fibaro:call(_selfId, "pressButton", "5")
  -- esperar hasta que se haya iniciado el ciclo
  while isEmptyVar(globalVarName) do
    setEstado(false, 'Configurando variable global')
  end
end
-- TODO activar escena

--[[--------BUCLE DE CONTROL -------------------------------------------------]]
_log(DEBUG, "Iniciando...")
setEstado(true, '')
while true do
  --[[-------- ACTUALIZAR CONSUMO Y FACTURA VIRTUAL --------------------------]]
  -- invocar al boton de actualizacion de datos
  fibaro:call(_selfId, "pressButton", "6")

  --[[-CADA HORA --------------- ---------------------------------------------]]
    --if (tonumber(os.date("%M"))==0 and tonumber(os.date("%S"))==1) then
    --_log(DEBUG, 'actualización horaria')
  --end
  --[[- FIN CADA HORA --------------------------------------------------------]]

  --[[-CADA CICLO DE FACTUARCION ---------------------------------------------]]
  local mesOrigen = tonumber(string.sub(getOrigen(), 1, 2))
  local mesActual = tonumber(os.date("%m"))
  -- ajustar cambio de año
  if mesOrigen == 12 then mesOrigen = 0 end
  if (diaCambioCiclo == tonumber(os.date("%d"))) and
   (mesActual == mesOrigen + 1) then
    -- invocar al boton de reseteo de datos iniciar ciclo
    setEstado(true, 'reiniciando ciclo de facturación')
    fibaro:call(_selfId, "pressButton", "5")
    _log(DEBUG, 'reinicio de ciclo de facturación '..getOrigen())
  end
  --[[-FIN CICLO DE FACTUARCION ----------------------------------------------]]

  -- esperar hasta que la tabla de consumos sufra cambios para sincronizar el
  -- dispositivo virtual con el fisico
  local consumoStr = fibaro:getGlobalValue(globalVarName)
  local newConsumoStr = consumoStr
  _log(DEBUG, 'esperando...')
  setEstado(true, 'Esperando lecturas de consumo')
  while consumoStr == newConsumoStr do
    fibaro:sleep(1000)
    newConsumoStr = fibaro:getGlobalValue(globalVarName)
    -- durante la primera hora desde que se inicia el ciclo, la tabla no cambia
  end
  _log(DEBUG, 'actualizar')
  setEstado(true, '')
end
--[[--------------------------------------------------------------------------]]
