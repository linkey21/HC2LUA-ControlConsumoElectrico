--[[ControlConsumoElect
	Dispositivo virtual
	downDiaButton.lua
	por Manuel Pascual & Antonio Maestre
------------------------------------------------------------------------------]]

--[[----- CONFIGURACION DE USUARIO -------------------------------------------]]
--[[----- FIN CONFIGURACION DE USUARIO ---------------------------------------]]

--[[----- NO CAMBIAR EL CODIGO A PARTIR DE AQUI ------------------------------]]

--[[----- CONFIGURACION AVANZADA ---------------------------------------------]]
local release = {name='ControlConsumoElect.downDiaButton', ver=0, mayor=0,
 minor=4}
local _selfId = fibaro:getSelfId()  -- ID de este dispositivo virtual
--[[----- FIN CONFIGURACION AVANZADA -----------------------------------------]]

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
--[[----- FIN DE LA EJECUCION ------------------------------------------------]]

--[[----- INFORME DE RESULTADOS ----------------------------------------------]]
_log(INFO, release['name']..
' ver '..release['ver']..'.'..release['mayor']..'.'..release['minor'])

_log(INFO, fecha)
--[[----- FIN INFORME DE RESULTADOS ------------------------------------------]]
