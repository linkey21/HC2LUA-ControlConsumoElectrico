--[[ControlConsumoElect
	Dispositivo virtual
	updateButton.lua
	por Antonio Maestre & Manuel Pascual
------------------------------------------------------------------------------]]

--[[----- CONFIGURACION DE USUARIO -------------------------------------------]]
local potenciacontratadakw = 4.4                  -- potencia contratada
local preciokwhmercadolibre = 0.141422            --
local precioalquilerequipodia = 0.028644          -- alquiler de contador
local porcentajeIVA = 21                          -- % IVA
local porcentajeimpuestoelectricidad = 5.1127     -- % impuesto de electricidad
local preciokwhterminofijo = 0.115187             --
local pvpc = true                                 -- si se usa tarifa PVPC
local pvpcTipoTarifa = '20'                       -- '20', '20H', '20HS'
local porcentajeAjusteRecomendacion = 3           -- % por encima precio medio
local IDIconoRecomendadoSI = 1060                 -- icomo recomendar consumo
local IDIconoRecomendadoNO = 1059                 -- icono NO recomendar consumo
--[[----- FIN CONFIGURACION DE USUARIO ---------------------------------------]]

--[[----- NO CAMBIAR EL CODIGO A PARTIR DE AQUI ------------------------------]]

--[[----- CONFIGURACION AVANZADA ---------------------------------------------]]
local release = {name='ControlConsumoElect.updateButton', ver=0, mayor=0,
 minor=4}
local _selfId = fibaro:getSelfId()  -- ID de este dispositivo virtual
globalVarName = 'controlConsumo'    -- nombre de variable global almacen consumo
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
getConsumo(a, b, c)
	devuelve el consumo del mes, dia del mes u hora del dia del mes.
	si se pasa 1 argumento,   se considera el (mes)
	si se pasan 2 argumentos, se consideran (dia, mes)
	si se pasan 3 argumentos, se consideran (hora, dia, mes)
--]]
function getConsumo(a, b, c)
  local consumoTab = json.decode(fibaro:getGlobalValue(globalVarName))
  local clave = ''
  -- otener el consumo origen por si fuera necesario restarlo del total
  local consumoIni, unidadIni, claveIni = getConsumoOrigen()
  if not a then
   local clave = ' '
  elseif not b then
    clave = string.format('%.2d',a)
  elseif not c then
    clave= string.format('%.2d',b)..string.format('%.2d',a)
  else
    clave= string.format('%.2d',c)..string.format('%.2d',b)..
    string.format('%.2d',a)
  end
  local consumo = 0
  for key, value in pairs(consumoTab) do
    if (clave == string.sub(key, 1, #clave)) and (key ~= claveIni) then
      consumo = consumo + value.valor
      unidad = value.unidad
    end
    -- consumo = consumo + getConsumoDia(d,mes)
  end
  -- retirar el consumo inicial
  return consumo, unidad
end

--[[----------------------------------------------------------------------------
getConsumoOrigen()
	devuelve el consumo inicial valor, unidad, fecha mmddhh
--]]
function getConsumoOrigen()
  local consumoTab = json.decode(fibaro:getGlobalValue(globalVarName))
  -- ordenar la tabla para comparar tomar el primer valor
  local u = {}
  for k, v in pairs(consumoTab) do table.insert(u, { key = k, value = v }) end
  table.sort(u, function (a1, a2) return a1.key < a2.key; end)
  return u[1].value.valor, u[1].value.unidad, u[1].key
end

--[[----- INICIAR ------------------------------------------------------------]]
_log(INFO, release['name']..
' ver '..release['ver']..'.'..release['mayor']..'.'..release['minor'])

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
local iconoRecomendado = IDIconoRecomendadoSI
if (preciokwh > (precioMedioDia * (1 + porcentajeAjusteRecomendacion/100))) then
	recomendacion = 'Esperar'
  iconoRecomendado = IDIconoRecomendadoNO
end
_log(DEBUG, 'Precio medio día: '..precioMedioDia ..' €/kwh')
-- refrescar el log
fibaro:log('Precio medio:'..precioMedioDia..'€/kWh  Actual:'..
preciokwh..'€/kWh '..recomendacion)
-- refrescar icono recomendacion
fibaro:call(_selfId, 'setProperty', "currentIcon", iconoRecomendado)

-- obtener consumo origen
local consumoOrigen, unidad, clave
consumoOrigen, unidad, clave = getConsumoOrigen()
-- refrescar etiqueta de consumo origen
fibaro:call(_selfId, "setProperty",
 "ui.ActualOrigen.value",tostring(consumoOrigen).." "..unidad)

-- calcular consumo acumulado y potencia media de la ultima hora/fracion
local hora = tonumber(os.date("%H"))
local dia = tonumber(os.date("%d"))
local mes = tonumber(os.date("%m"))
local consumoActual = getConsumo(hora, dia, mes)
local tiempo = os.date('*t')
-- si el consumo de la hora actual es 0 se toma la hora anterior
if consumoActual == 0 then
  hora = hora - 1
  consumoActual = getConsumo(hora, dia, mes)
end
tiempo.min = 0;  tiempo.sec = 0; tiempo.hour = hora
tiempo = (os.time() - os.time(tiempo))
_log(DEBUG, 'Tiempo: '..tiempo..' seg.')
-- potencia = kWh*3600/t
local potenciaMedia = redondea(1000 * (consumoActual * 3600 / tiempo), 2)
_log(DEBUG, 'Potencia media: '.. potenciaMedia..' W')
_log(DEBUG, 'Consumo última hora: '..consumoActual)

-- refrescar etiqueta consumo ultima hora
fibaro:call(_selfId, "setProperty", "ui.UltimaHora.value",
 redondea(consumoActual, 2).." kWh / "..
 redondea(consumoActual*preciokwh, 2).." €")

 -- refrescar etiqueta potencia media
fibaro:call(_selfId, "setProperty", "ui.PotenciaMedia.value",
 potenciaMedia..' W')

-- calcular consumo acumulado del dia
consumoActual = getConsumo(tonumber(os.date("%d")), tonumber(os.date("%m")))
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
-- proceso para obtener los dias transcurridos desde el inicio de ciclo
-- obtener la fecha origen de ciclo
local consumo, unidad, clave, anno, diasDesdeInicio
consumo, unidad, clave = getConsumoOrigen()
dia = tonumber(string.sub(clave, 3, 4))
mes = tonumber(string.sub(clave, 1, 2))
anno = tonumber(os.date('%Y'))
-- obtener timestamp del día origen de ciclo
local timeOrigen = os.time({month = mes, day = dia, year = anno})
-- obtener timestamp actual
local timeAhora = os.time()
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
