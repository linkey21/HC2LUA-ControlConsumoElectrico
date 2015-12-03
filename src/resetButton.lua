--[[ControlConsumoElect
	Dispositivo virtual
	resetButton.lua
	por Antonio Maestre & Manuel Pascual
------------------------------------------------------------------------------]]

--[[----- CONFIGURACION DE USUARIO -------------------------------------------]]
energyDev = 544           -- ID del dispositivo de energia
propertyName = 'value'		-- propiedad del dispositivo para recuperar la energia
--[[----- FIN CONFIGURACION DE USUARIO ---------------------------------------]]

--[[----- NO CAMBIAR EL CODIGO A PARTIR DE AQUI ------------------------------]]

--[[----- CONFIGURACION AVANZADA ---------------------------------------------]]
local release = {name='ControlConsumoElect.resetButton', ver=0, mayor=0,
 minor=4}
local _selfId = fibaro:getSelfId()  -- ID de este dispositivo virtual
cceEstado = 'cceEstado'     -- nombre variable global para almacenar el estado
cceConsumo = 'cceConsumo'   -- nombre variable global para almacenar consumo
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
isVariable(varName)
	comprueba si existe una variable global dada(varName)
--]]
function isVariable(varName)
  -- comprobar si existe
  local valor, timestamp = fibaro:getGlobal(varName)
  if (valor and timestamp > 0) then return true end
  return false
end

--[[----------------------------------------------------------------------------
resetConsumo()
	inicializa la tabla de consumos
--]]
function resetConsumo()
  -- si no exite la variable global para almacenar consumos
  if not isVariable(cceConsumo) then
    -- intentar crear la variableGlobal
    local json = '{"name":"'..cceConsumo..'", "isEnum":0}'
    HC2 = Net.FHttp("127.0.0.1", 11111)
    HC2:POST("/api/globalVariables", json)
    fibaro:sleep(1000)
    -- comprobar que se ha creado la variableGlobal
    if not isVariable(cceConsumo) then
      _log(DEBUG, 'No se pudo declarar variable global '..cceConsumo)
      fibaro:abort()
    end
  end
  -- si no exite la variable global para almacenar estado
  if not isVariable(cceEstado) then
    -- intentar crear la variableGlobal
    local json = '{"name":"'..cceEstado..'", "isEnum":0}'
    HC2 = Net.FHttp("127.0.0.1", 11111)
    HC2:POST("/api/globalVariables", json)
    fibaro:sleep(1000)
    -- comprobar que se ha creado la variableGlobal
    if not isVariable(cceEstado) then
      _log(DEBUG, 'No se pudo declarar variable global '..cceEstado)
      fibaro:abort()
    end
  end

  -- vaciar variables globales
  local tablaConsumo, tablaEstado
  -- crear una tablas vacías
  tablaConsumo = {}
  tablaEstado = {consumoOrigen = {}}

  -- almacenar el consumoOrigen
  local consumo, timeStamp = fibaro:get(energyDev, propertyName)
  tablaEstado['consumoOrigen'].kWh = tonumber(consumo)
  tablaEstado['consumoOrigen'].timeStamp = tonumber(timeStamp)

  -- almacenar el id del VD en el estado para saber que ha sido iniciada
  tablaEstado['VDId'] = _selfId

  -- guardar las tablas en la variables globales
  fibaro:setGlobal(cceConsumo, json.encode(tablaConsumo))
  fibaro:setGlobal(cceEstado, json.encode(tablaEstado))

  return tablaEstado, tablaConsumo
end

--[[----------------------------------------------------------------------------
bisiesto(anno)
	devuelve true o false si es año(anno) bisiesto o no
--]]
function bisiesto(anno)
  if (anno % 4 == 0 and (anno % 100 ~= 0 or anno % 400 == 0)) then
    return true
	end
  return false
end

--[[----------------------------------------------------------------------------
getDiasMes(mes, anno)
	devuelve cuantos días tiene el mes(mes) del año(anno) indicados.
--]]
function getDiasMes(mes, anno)
  local diasDelMes = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}
  if bisiesto(anno) then diasDelMes[2] = 29 end
  return diasDelMes[mes]
end

--[[------- INICIA LA EJECUCION ----------------------------------------------]]
_log(INFO, release['name']..
' ver '..release['ver']..'.'..release['mayor']..'.'..release['minor'])
-- resetear y recuperar la tabla de consumo
local tablaEstado, tablaConsumo
tablaEstado, tablaConsumo = resetConsumo()

-- proponer como dia de inicio de ciclo el mismo dia del mes siguiente a la
-- fecha origen de ciclo actual
local dia, mes, anno, dias, segs, fecha, stamp
-- obtener fecha origen
stamp = os.time()
-- otener dia, mes y año de la fecha origen
dia = tonumber(os.date('%d', stamp))
mes = tonumber(os.date('%m', stamp))
anno = tonumber(os.date('%Y'))
-- averiguar los dias que tiene el mes
dias = getDiasMes(mes, anno)
-- averiguar los segundos que tiene el mes
segs = 86400 * dias
-- saltar un mes
fecha = os.date('%d/%m/%y', os.time({month = mes, day = dia,
 year = anno}) + segs)
 -- refrescar la etiqueta diaInicioCiclo
fibaro:call(_selfId, 'setProperty', 'ui.diaInicioCiclo.value', fecha)
_log(DEBUG, 'Fecha próximo ciclo: '..fecha)

-- invocar al boton de actualizacion de datos
fibaro:call(_selfId, "pressButton", "6")
--[[----- FIN DE LA EJECUCION ------------------------------------------------]]

--[[----- INFORME DE RESULTADOS ----------------------------------------------]]
_log(DEBUG, cceConsumo..' '..cceEstado)
_log(INFO, cceConsumo..': '..fibaro:getGlobalValue(cceConsumo))
_log(INFO, cceEstado..': '..fibaro:getGlobalValue(cceEstado))
--[[----- FIN INFORME DE RESULTADOS ------------------------------------------]]
--[[--------------------------------------------------------------------------]]
