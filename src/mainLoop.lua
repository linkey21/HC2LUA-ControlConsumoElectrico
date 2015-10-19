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
setEstado()
	configura el estado del dispositivo virtual
--]]
function setEstado(estado, mensaje)
  if estado then
    mensaje = 'OK - '..mensaje
  else
    mensaje = 'STOP - '..mensaje
  end
  -- referscar etiqueta de estado y log
  fibaro:call(_selfId, 'setProperty', 'ui.lbStatus.value', mensaje)
  fibaro:log(mensaje)
  return estado
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

  -- recuperar la tabla de consumo
  local ctrlEnergia, consumoTab, estadoTab
  ctrlEnergia = json.decode(fibaro:getGlobalValue(globalVarName))
  consumoTab = ctrlEnergia['consumo']
  estadoTab = ctrlEnergia['estado']

  --[[-CADA CICLO DE FACTUARCION ---------------------------------------------]]
  local mesOrigen, mesActual
  mesOrigen = tonumber(os.date('%m', estadoTab['consumoOrigen'].timeStamp))
  mesActual = tonumber(os.date("%m"))
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
  local consumo, newConsumo
  consumo = #consumoTab; newConsumo = consumo
  setEstado(true, 'Esperando lectura')
  _log(DEBUG, newConsumo..' Lecturas esperando...')
  while consumo == newConsumo do
    fibaro:sleep(1000)
    ctrlEnergia = json.decode(fibaro:getGlobalValue(globalVarName))
    newConsumo = #ctrlEnergia['consumo']
  end
  _log(DEBUG, 'actualizar')
  setEstado(true, '')
end
--[[--------------------------------------------------------------------------]]
