--[[ControlConsumoElect
	Dispositivo virtual
	downDiaButton.lua
	por Manuel Pascual & Antonio Maestre
------------------------------------------------------------------------------]]

--[[----- CONFIGURACION DE USUARIO -------------------------------------------]]
--[[----- FIN CONFIGURACION DE USUARIO ---------------------------------------]]

--[[----- NO CAMBIAR EL CODIGO A PARTIR DE AQUI ------------------------------]]

--[[----- CONFIGURACION AVANZADA ---------------------------------------------]]
local release = {name='ControlConsumoElect.downDiaButton', ver=2, mayor=0,
 minor=0}
local _selfId = fibaro:getSelfId()  -- ID de este dispositivo virtual
local globalVarName = 'consumoV2'
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
local dia, mes, anno, fecha
-- obtener fecha desde la etiqueta
fecha = fibaro:get(_selfId, 'ui.diaInicioCiclo.value')
-- otener dia, mes y año de la fecha origen
dia = tonumber(string.sub(fecha, 1, 2))
mes = tonumber(string.sub(fecha, 4, 5))
anno = tonumber(string.sub(os.date('%Y'), 1, 2)..string.sub(fecha, 7, 8))
-- retorceder un dia para obtener nueva fecha
fecha = os.date('%d/%m/%y', os.time({month = mes, day = dia,
 year = anno}) - (24*60*60))
 -- refrescar la etiqueta diaInicioCiclo
fibaro:call(_selfId, 'setProperty', 'ui.diaInicioCiclo.value', fecha)

-- para otener estado de la recomendación recuperar la tabla de consumo
local recomendacion
ctrlEnergia = json.decode(fibaro:getGlobalValue(globalVarName))
recomendacion = ctrlEnergia['estado'].recomendacion
-- refrescar icono recomendacion
fibaro:call(_selfId, 'setProperty', "currentIcon", recomendacion)
--[[----- FIN DE LA EJECUCION ------------------------------------------------]]

--[[----- INFORME DE RESULTADOS ----------------------------------------------]]
_log(INFO, release['name']..
' ver '..release['ver']..'.'..release['mayor']..'.'..release['minor'])

_log(INFO, fecha)
--[[----- FIN INFORME DE RESULTADOS ------------------------------------------]]
