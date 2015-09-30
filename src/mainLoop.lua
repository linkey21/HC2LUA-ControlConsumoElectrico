--[[ControlConsumoElect
	Dispositivo virtual
	mainLoop.lua
	por Antonio Maestre & Manuel Pascual
------------------------------------------------------------------------------]]

--[[----- CONFIGURACION DE USUARIO -------------------------------------------]]
local diaCambioCiclo = '1'	-- dia del mes en que cambia el ciclo de facturacion
--[[----- FIN CONFIGURACION DE USUARIO ---------------------------------------]]

--[[----- NO CAMBIAR EL CODIGO A PARTIR DE AQUI ------------------------------]]

--[[----- CONFIGURACION AVANZADA ---------------------------------------------]]
local release = {name='ControlConsumoElect.mainLoop', ver=0, mayor=0, minor=3}
local _selfId = fibaro:getSelfId()  -- ID de este dispositivo virtual
local diaCambioCiclo = fibaro:get(_selfId, 'ui.diaInicioCiclo.value')
diaCambioCiclo = tonumber(string.sub(diaCambioCiclo, 1, 2))
globalVarName = 'consumoEnergia'    -- nombre de la variable global
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

--[[----- COMIENZA LA EJECUCION ----------------------------------------------]]
_log(INFO, release['name']..
' ver '..release['ver']..'.'..release['mayor']..'.'..release['minor'])

--[[--------BUCLE DE CONTROL -------------------------------------------------]]
_log(DEBUG, "Iniciando...")
while true do
  --[[-------- ACTUALIZAR CONSUMO Y FACTURA VIRTUAL --------------------------]]
  -- invocar al boton de actualizacion de datos
  fibaro:call(_selfId, "pressButton", "19")

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
    -- invocar al boton de reseteo de datos
    fibaro:call(_selfId, "pressButton", "18")
    _log(DEBUG, 'reinicio de ciclo de facturación '..getOrigen())
  end
  --[[-FIN CICLO DE FACTUARCION ----------------------------------------------]]

  -- esperar hasta que la tabla de consumos sufra cambios para sincronizar con
  -- el dispositivo virtual con el fisico
  local consumoStr = fibaro:getGlobalValue(globalVarName)
  local newConsumoStr = consumoStr
  _log(DEBUG, 'esperando...')
  while consumoStr == newConsumoStr do
    fibaro:sleep(1000)
    newConsumoStr = fibaro:getGlobalValue(globalVarName)
    -- durante la primera hora desde que se inicia el ciclo, la tabla no cambia
  end
  _log(DEBUG, 'actualizar')
end
--[[--------------------------------------------------------------------------]]
