--[[ControlConsumoElect
	Dispositivo virtual
	updateButton.lua
	por Antonio Maestre & Manuel Pascual
------------------------------------------------------------------------------]]

--[[----- CONFIGURACION DE USUARIO -------------------------------------------]]
local potenciacontratadakw = 4.4                  -- potencia contratada
local preciokwhmercadolibre = 0.141422            -- precio kWh mercado libre
local precioalquilerequipodia = 0.028644          -- alquiler de contador
local porcentajeIVA = 21                          -- % IVA
local porcentajeimpuestoelectricidad = 5.1127     -- % impuesto de electricidad
local preciokwhterminofijo = 0.115187             -- percio kWh termino fijo
local pvpc = true                                 -- si se usa tarifa PVPC
local pvpcTipoTarifa = '20'                       -- '20', '20H', '20HS'
local porcentajeAjusteRecomendacion = 3           -- % por encima precio medio
local iDIconoRecomendadoSI = 1060                 -- icomo recomendar consumo
local iDIconoRecomendadoNO = 1059                 -- icono NO recomendar consumo
--[[----- FIN CONFIGURACION DE USUARIO ---------------------------------------]]

--[[----- NO CAMBIAR EL CODIGO A PARTIR DE AQUI ------------------------------]]

--[[----- CONFIGURACION AVANZADA ---------------------------------------------]]
local release = {name='ControlConsumoElect.updateButton', ver=0, mayor=0,
 minor=4}
local _selfId = fibaro:getSelfId()  -- ID de este dispositivo virtual
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
redondea(num, idp)
  devuelve el numero (num) redondeado a (idp) decimales
--]]
function redondea(num, idp)
  local mult = 10^(idp or 0)
  return math.floor(num * mult + 0.5) / mult
end

--[[----------------------------------------------------------------------------
getPVPC(tipo)
	devuelve el valor del pecio valuntario para pequeño consumidor de la hora o
	del dia.
	tipo = 'dia'/'hora'
--]]
function getPVPC(tipo)
  -- solo se puede recibir como parametro 'hora' o 'dia'
  if (tipo ~='dia' and tipo ~='hora') then
    return 1, 'solo se admite dia/hora'
  end
  local payload = '/'..tipo
  -- si el tipo es hora, se toma la hora actual si no el dia de hoy
  if tipo == 'hora' then tipo = os.date('%H') else tipo = 'hoy' end
  local cnomys = Net.FHttp("pvpc.cnomys.es")
  response, status, errorCode = cnomys:GET(payload)
  if tonumber(status) == 200 then
    local jsonTable = json.decode(response)
    if (jsonTable.estado == true) then
      for key, value in pairs(normalizaPVPCTab(jsonTable.datos)) do
        if value.clave == tipo then
          return 0, value.precio
        end
      end
    else
      if jsonTable['razon_error'] then return 1, jsonTable['razon_error'] end
      return 1, 'error desconocido'
    end
  else
    return 1, errorCode
  end
  return 1, 'dia/hora no corresponde con el actual'
end

--[[-----------------------------------------------------------------------------
normalizaPVPCTab(precioTab)
  -- recive una tabla de precio de cada hora representados por el indice y
  -- devuelve una tabla con el formato {clave, precio} con los precios del tipo
  -- de tarifa declarada en la variable pvpcTipoTarifa
--]]
function normalizaPVPCTab(precioTab)
  local preciosTab = {}
  for key, value in pairs(precioTab) do
    if value then
      preciosTab[#preciosTab + 1] = {clave = key, precio = value[pvpcTipoTarifa]}
    end
  end
  return preciosTab
end

--[[----------------------------------------------------------------------------
getConsumo(stampIni, stampFin)
	devuelve el consumo desde el momento inicado hasta la actualidad o stampFin
--]]
function getConsumo(stampIni, stampFin)
  local consumoTab, consumo, ctrlEnergia
  -- intentar recuperar la tabla de control de energia desde la variable
  ctrlEnergia = json.decode(fibaro:getGlobalValue(globalVarName))
  consumoTab = ctrlEnergia['consumo']
  consumo = 0
  -- si no se indica el principio del ambito
  if not stampIni then
    -- se devuelve el total y el último timeStamp
    local stampAnterior, stampActual
    -- si no hay medidas de consumo hay un error
    stampAnterior = 0
    -- tomar el último timeStamp
    for key, value in pairs(consumoTab) do
      if value['kWh'] then consumo = consumo + value['kWh'] end
      if value['timeStamp'] then
        stampActual = value['timeStamp']
        if stampActual > stampAnterior then stampAnterior = stampActual end
      end
    end
    return consumo, stampAnterior
  elseif stampIni == 0 then -- si se indica 0 como inicio del ambito
    -- devolver el consumo origen
    return  ctrlEnergia['estado']['consumoOrigen'].kWh
  end
  -- si no se indica el final se toma el momento actual
  if not stampFin then stampFin = os.time() end
  -- se devuelve el total del ambito indicado (stampIni, stampFin)
  for key, value in pairs(consumoTab) do
    local stampActual; stampActual = value.timeStamp
      if stampActual > stampIni and stampActual <= stampFin and
        stampActual ~= stampOrigen then
        consumo = consumo + value.kWh
      end
  end
  return consumo
end

--[[----- INICIAR ------------------------------------------------------------]]
_log(INFO, release['name']..
' ver '..release['ver']..'.'..release['mayor']..'.'..release['minor'])

-- recuperar la tabla de consumo
ctrlEnergia = json.decode(fibaro:getGlobalValue(globalVarName))
local consumoTab, estadoTab
consumoTab = ctrlEnergia['consumo']
estadoTab = ctrlEnergia['estado']

-- obtener el precio kWh
local preciokwh = preciokwhmercadolibre -- TODO se puede obtener de una web?.
local precioMedioDia = 0
if pvpc then
  -- obtener el precio para esta hora
  status, preciokwh = getPVPC('hora')
  -- si no se puede obtener precio
  if status ~= 0 then
    -- informar del error
    _log(INFO, 'Error al obtener precio hora: '..preciokwh)
    --  y tomar precio anterior
    preciokwh = tonumber(string.sub(fibaro:get(_selfId, 'ui.PrecioHora.value'),
     1, 7))
  else
    preciokwh = tonumber(preciokwh)
  end
  -- obtener precio medio del día
  status, precioMedioDia = getPVPC('dia')
  -- si no se puede obtener precio medio dia
  if status ~= 0 then
    -- informar del error
    _log(INFO, 'Error al obtener precio medio día: '..precioMedioDia)
    --  y tomar precio hora no recomendable
    precioMedioDia = preciokwh * (1 + porcentajeAjusteRecomendacion/100)
  else
    precioMedioDia = tonumber(precioMedioDia)
  end
end
-- refrescar etiqueta de precio hora
fibaro:call(_selfId, "setProperty", "ui.PrecioHora.value",preciokwh..' €/kWh')
_log(DEBUG, 'Precio hora: '..preciokwh..' €/kWh')

-- calcular recomendacion consumo
local recomendacion = 'Aprovechar'
local iconoRecomendado = iDIconoRecomendadoSI
if (preciokwh > (precioMedioDia * (1 + porcentajeAjusteRecomendacion/100))) then
	recomendacion = 'Esperar'
  iconoRecomendado = iDIconoRecomendadoNO
end
_log(DEBUG, 'Precio medio día: '..precioMedioDia ..' €/kwh')
-- refrescar el log
fibaro:log('Precio medio:'..precioMedioDia..'€/kWh  Actual:'..
preciokwh..'€/kWh '..recomendacion)
-- refrescar icono recomendacion
fibaro:call(_selfId, 'setProperty', "currentIcon", iconoRecomendado)

-- obtener consumo origen
local consumoOrigen
consumoOrigen = estadoTab['consumoOrigen'].kWh
-- refrescar etiqueta de consumo origen
fibaro:call(_selfId, 'setProperty',
 'ui.ActualOrigen.value',tostring(consumoOrigen)..' kWh')

-- obtener potencia media
local potenciaMedia; potenciaMedia = estadoTab['energia']
_log(DEBUG, 'Potencia media: '.. potenciaMedia..' W')
-- refrescar etiqueta potencia media
fibaro:call(_selfId, "setProperty", "ui.PotenciaMedia.value",
potenciaMedia..' W')

-- comienza el calculo de consumos
local consumoActual
-- calcular consumo acumulado de la ultima hora
-- restar los segundos de una hora o desde la horaActual:00 ?
consumoActual = getConsumo(os.time() - 3600, os.time())
_log(DEBUG, 'Consumo última hora: '..consumoActual)
-- refrescar etiqueta consumo ultima hora
fibaro:call(_selfId, "setProperty", "ui.UltimaHora.value",
 redondea(consumoActual, 2).." kWh / "..
 redondea(consumoActual*preciokwh, 2).." €")

-- calcular consumo acumulado del dia
-- restar los segundos de un dia 24h o calcular desde las 00:00h?
consumoActual = getConsumo(os.time() - 3600 * 24, os.time())
_log(DEBUG, 'Consumo último día: '..consumoActual)
-- refrescar etiqueta consumo del ultimo dia
fibaro:call(_selfId, "setProperty", "ui.Ultimas24H.value",
 redondea(consumoActual, 2).. " kWh / "..
 redondea(consumoActual*preciokwh, 2).." €")

-- calcular consumo del ultimo ciclo
consumoActual = getConsumo()
_log(DEBUG, 'Consumo último ciclo: '..consumoActual)
-- refrescar etiqueta consumo ultimo mes
fibaro:call(_selfId, "setProperty", "ui.UltimoMes.value",
 redondea(consumoActual, 2).." kWh / "..
 redondea(consumoActual*preciokwh, 2).." €")

--[[------- ACTUALIZAR FACTURA VIRTUAL ---------------------------------------]]
local timeOrigen, timeAhora, diasDesdeInicio
-- obtener timestamp del origen de ciclo
timeOrigen = estadoTab['consumoOrigen'].timeStamp
-- obtener timestamp actual
timeAhora = os.time()
-- calcular dias transcurridos desde inicio de ciclo
diasDesdeInicio = math.floor((timeAhora - timeOrigen) / (24*60*60)) + 1
_log(DEBUG, 'Dias desde inicio de ciclo: '..diasDesdeInicio)
-- FIN proceso

-- calcular precio termino fijo
local euroterminofijopotenciames = potenciacontratadakw * preciokwhterminofijo
 * diasDesdeInicio
 _log(DEBUG, 'Precio termino fijo: '..euroterminofijopotenciames)
 -- refrescar etiqueta precio termino fijo
fibaro:call(_selfId, "setProperty", "ui.TerminoFijo.value",
 redondea(euroterminofijopotenciames, 2) .. " €")

 -- calcular consumo del ultimo ciclo y precio
local euroterminoconsumo = getConsumo() * preciokwh
_log(DEBUG, 'Precio termino consumo: '..euroterminoconsumo)
-- refrescar etiqueta precio termino consumo
fibaro:call(_selfId, "setProperty", "ui.TerminoConsumo.value",
 redondea(euroterminoconsumo, 2) .. " €")

-- calcular precio impuesto electricidad
local impuestoelectricidad = (euroterminofijopotenciames+euroterminoconsumo) *
 porcentajeimpuestoelectricidad/100
 _log(DEBUG, 'Precio impuesto electricidad: '..impuestoelectricidad)
 -- refrescar etiqueta precio impuesto electricidad
fibaro:call(_selfId, "setProperty", "ui.ImpuestoElectricidad.value",
 redondea(impuestoelectricidad, 2) .. " €")

-- calcular precio alquiler equipo
local euroalquilerequipos = precioalquilerequipodia * diasDesdeInicio
_log(DEBUG, 'Precio alquiler equipo: '..euroalquilerequipos)
-- refrescar etiqueta precio alquiler equipo
fibaro:call(_selfId, "setProperty", "ui.AlquilerEquipos.value",
 redondea(euroalquilerequipos, 2) .. " €")

-- calcular el IVA
local IVA = (euroterminofijopotenciames + euroterminoconsumo +
 impuestoelectricidad + euroalquilerequipos) * porcentajeIVA/100
 _log(DEBUG, 'IVA: '..IVA)
 -- refrescar etiqueta IVA
fibaro:call(_selfId, "setProperty", "ui.IVA.value", redondea(IVA,2) .. " €")

-- calcular TOTAL
local Total = euroterminofijopotenciames+euroterminoconsumo +
 impuestoelectricidad + euroalquilerequipos+IVA
 _log(DEBUG, 'Total factura: '..Total)
 -- refrescar etiqueta total factura
fibaro:call(_selfId, "setProperty", "ui.Total.value",
redondea(Total,2) .. " €")
--[[----- FIN DE LA EJECUCION ------------------------------------------------]]

--[[----- INFORME DE RESULTADOS ----------------------------------------------]]
--[[----- FIN INFORME DE RESULTADOS ------------------------------------------]]
--[[--------------------------------------------------------------------------]]
