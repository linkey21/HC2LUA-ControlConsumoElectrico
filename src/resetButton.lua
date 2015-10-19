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
globalVarName = 'consumoV2'    -- nombre de variable global almacen consumo
tcpHC2 =  false                     -- objeto que representa una conexion TCP
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
  if (valor and  timestamp > 0) then return true end
  return false
end

--[[----------------------------------------------------------------------------
resetConsumo()
	inicializa (vacia) la tabla de consumos y almacena el consumoOrigen
--]]
function resetConsumo()
  -- comprobar si exite la variable global para almacenar consumos
  if isVariable(globalVarName) then
    -- vaciar variable global
    local ctrlEnergia, consumo, estado
    -- crear una tabla vacia
    ctrlEnergia = {}
    estado = {recomendacion = 0, energia = 0,
     consumoOrigen = {timeStamp = os.time(), kWh = 0}}
    consumo = {}
    -- almacenar consumo actual como origen
    estado['consumoOrigen'].kWh =
     tonumber(fibaro:getValue(energyDev, propertyName))
    estado['consumoOrigen'].timeStamp = os.time()
    -- almacenar en la tabla de control de energia el estado y el consumo
    ctrlEnergia['consumo'] = consumo
    ctrlEnergia['estado'] = estado
    -- guardar en la variable global
    fibaro:setGlobal(globalVarName, json.encode(ctrlEnergia))
    return ctrlEnergia
  end
  _log(DEBUG, 'Declarar variable global '..globalVarName)
  fibaro:log('Declarar variable global '..globalVarName)
  return {}
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
--

-- resetear la tabla de consumos y recuperar la tabla de consumo
ctrlEnergia = resetConsumo()
local consumoTab, estadoTab
estadoTab = ctrlEnergia['estado']

-- proponer como dia de inicio de ciclo el mismo dia del mes siguiente a la
-- fecha origen de ciclo actual
local dia, mes, anno, dias, segs, fecha, stamp
-- obtener fecha origen
stamp = estadoTab['consumoOrigen'].timeStamp
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
_log(DEBUG, fecha)

-- invocar al boton de actualizacion de datos
fibaro:call(_selfId, "pressButton", "6")
--[[----- FIN DE LA EJECUCION ------------------------------------------------]]

--[[----- INFORME DE RESULTADOS ----------------------------------------------]]
_log(INFO, release['name']..
' ver '..release['ver']..'.'..release['mayor']..'.'..release['minor'])

_log(INFO, fibaro:getGlobalValue(globalVarName))
--[[----- FIN INFORME DE RESULTADOS ------------------------------------------]]
--[[--------------------------------------------------------------------------]]
