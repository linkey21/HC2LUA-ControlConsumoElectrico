--[[ControlConsumoElect
	Dispositivo virtual
	mainLoop.lua
	por Antonio Maestre & Manuel Pascual
------------------------------------------------------------------------------]]

--[[----- CONFIGURACION DE USUARIO -------------------------------------------]]
--[[----- FIN CONFIGURACION DE USUARIO ---------------------------------------]]

--[[----- NO CAMBIAR EL CODIGO A PARTIR DE AQUI ------------------------------]]

--[[----- CONFIGURACION AVANZADA ---------------------------------------------]]
local release = {name='ControlConsumoElect.mainLoop', ver=2, mayor=1, minor=0}
cceEstado = 'cceEstado'     -- nombre variable global para almacenar el estado
cceConsumo = 'cceConsumo'   -- nombre variable global para almacenar consumos
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

--[[----- COMIENZA LA EJECUCION ----------------------------------------------]]
_log(INFO, release['name']..
' ver '..release['ver']..'.'..release['mayor']..'.'..release['minor'])

local contador = 0
--[[--------BUCLE DE CONTROL -------------------------------------------------]]
local tablaEstado
while true do
  local mensaje = ''
  fibaro:log(mensaje)
  -- obtener mesaje de estado
  tablaEstado = json.decode(fibaro:getGlobalValue(cceEstado))
  local mensaje = tablaEstado.mensaje..' - '..tablaEstado.preciokwh..'€/kWh'
  -- referscar log
  fibaro:log(mensaje)
  -- parar 1 seg. para evitar problemas de rendimiento
  fibaro:sleep(1000)
  -- notificación de estado para watchdog
  fibaro:debug('ControlConsumo OK')
end
--[[--------------------------------------------------------------------------]]
