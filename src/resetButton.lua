--[[ControlConsumoElect
	Dispositivo virtual
	resetButton.lua
	por Antonio Maestre & Manuel Pascual
------------------------------------------------------------------------------]]

--[[----- CONFIGURACION DE USUARIO -------------------------------------------]]
energyDev = 547           -- ID del dispositivo de energia
propertyName = 'value'		-- propiedad del dispositivo para recuperar la energia
usuarioHC2 = 'admin'      -- usuario para conectar al HC2
claveHC2 = 'MDA2011Adm&'  -- contraseña para del usuario de conexion
--[[----- FIN CONFIGURACION DE USUARIO ---------------------------------------]]

--[[----- NO CAMBIAR EL CODIGO A PARTIR DE AQUI ------------------------------]]

--[[----- CONFIGURACION AVANZADA ---------------------------------------------]]
local release = {name='ControlConsumoElect.resetButton', ver=0, mayor=0,
 minor=4}
local _selfId = fibaro:getSelfId()  -- ID de este dispositivo virtual
globalVarName = 'controlConsumo'    -- nombre de variable global almacen consumo
tcpHC2 =  false                     -- objeto que representa una conexion TCP
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
newGlobal(varName, seteo)
	crea una variable global
--]]
function newGlobal(varName, seteo)
  -- si no exite la variable se crea
  if not isVariable(varName) then
    _log(DEBUG, 'no existe variable global!')
    -- obtener IP y puerto
    local IPAddress = fibaro:getValue(_selfId, 'IPAddress')
    local TCPPort = fibaro:getValue(_selfId, 'TCPPort')
    if IPAddress == '' or TCPPort == 0 then
      fibaro:log('Configure IP:Port')
      _log(INFO,'Configure IP:Port' )
    end
    -- si no existe conexion previa
    if not tcpHC2 then
      -- obtener conexion TCP con el HC2
      tcpHC2 = Net.FHttp('localhost', 80)
    end
    -- validar sesion
    tcpHC2:setBasicAuthentication(usuarioHC2, claveHC2)
    -- enviar un POST para crear variable
    local response, status, errorCode
    --response, status, errorCode = tcpHC2:POST("/api/globalVariables", "name=" ..
    --varName.."&value=0?eadOnly=false?isEnum=false") -- .. "&value=0"
    response, status, errorCode = tcpHC2:GET('/api/globalVariables/')
    local jsonTable = json.decode(response)
    jsonTable[#jsonTable + 1] = {name = varName, value = '0', readOnly = false,
    isEnum = false}
    local json = json.encode(jsonTable)
    response, status, errorCode = tcpHC2:PUT('/api/globalVariables/', json)
    _log(DEBUG, 'response: '..response..' status: '..status..' errorCode: '
     ..errorCode)
     if (errorCode == 0 and tonumber(status) < 400) then
       -- si se ha pasado un valor(seteo)
       if seteo then
         -- parsear tipo
         if type(seteo) == 'table' then
           seteo = json.encode(seteo)
         elseif type(seteo) == 'number' then
           seteo = tostring(seteo)
         elseif type(seteo) == 'string' then
        else
          seteo = '0'
        end
        -- setear la variable
        fibaro:setGlobal(varName, json.encode(seteo))
       end
       return 0, seteo
     else
       return status, 'No se ha podido crear la variable global'
     end
  end
  return 1, 'La variable ya existe'
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
  -- comprobar si exite la variable global para almacenar consumos
  while not isVariable(globalVarName) do
    fibaro:sleep(1000)
    -- refrescar la etiqueta status
    local status = 'PARADO: definir variable global'
    fibaro:call(_selfId, 'setProperty', 'ui.lbStatus.value', status)
  end
  -- vaciar variable global
  fibaro:setGlobal(globalVarName, json.encode({}))
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
-- resetear la tabla de consumos
_log(INFO, 'reset de la tabla de consumo: '..resetConsumo())

-- proponer como dia de inicio de ciclo el mismo dia del mes siguiente a la
-- fecha origen de ciclo actual
local clave, dia, mes, anno, dias, segs, fecha
-- obtener fecha origen
clave = getOrigen()
-- otener dia, mes y año de la fecha origen
dia = tonumber(string.sub(clave, 3, 4))
mes = tonumber(string.sub(clave, 1, 2))
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
