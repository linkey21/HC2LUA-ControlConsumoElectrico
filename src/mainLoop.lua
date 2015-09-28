--[[ControlConsumoElect
	Dispositivo virtual
	mainLoop.lua
	por Antonio Maestre & Manuel Pascual
------------------------------------------------------------------------------]]

--[[----- CONFIGURACION DE USUARIO -------------------------------------------]]
globalVarName = 'consumoEnergia'-- nombre de la variable global para almacenar
								-- consumo
local diaCambioCiclo = '21'	-- dia del mes en que cambia el ciclo de facturacion
OFF=1;INFO=2;DEBUG=3		-- esto es una referencia para el log, no cambiar
nivelLog = DEBUG			-- nivel de log
--[[----- FIN CONFIGURACION DE USUARIO ---------------------------------------]]

--[[----- NO CAMBIAR EL CODIGO A PARTIR DE AQUI ------------------------------]]

--[[----- CONFIGURACION AVANZADA ---------------------------------------------]]
local release = {name='ControlConsumoElect.mainLoop', ver=0, mayor=0,
 minor=2}
-- obtener el ID de este dispositivo virtual
local _selfId = fibaro:getSelfId();
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
	devuelve el consumo inicial valor, unidad, fecha mmddhh
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
  fibaro:call(_selfId, "pressButton", "14")

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
  if (diaCambioCiclo == os.date("%d")) and
   (mesActual == mesOrigen + 1) then
    -- invocar al boton de reseteo de datos
    fibaro:call(_selfId, "pressButton", "15")
    _log(DEBUG, 'reinicio de ciclo de facturación '..getOrigen())
  end
  --[[-FIN CICLO DE FACTUARCION ----------------------------------------------]]

  fibaro:sleep(60*1000);
  _log(DEBUG, "bucle");
end
--[[--------------------------------------------------------------------------]]
