
--[[Control de consumo
	VD Consumo
	boton actualizarFactura.lua
	por Antonio Maestre & Manuel Pascual
--------------------------------------------------------------------------------]]
release = {name='controlConsumo updateButton', ver=0, mayor=0, minor=2}

--[[----- CONFIGURACION DE USUARIO ---------------------------------------------]]
globalVarName = 'consumoEnergia'-- nombre de la variable global para almacenar consumo
local preciokwhterminofijo=0.115188;
local pvpc=true
local pvpcTipoTarifa = '20'				-- '20', '20H', '20HS'
local potenciacontratadakw=4.6;
local preciokwhmercadolibre=0.12;
local precioalquilerequipodia=0.027616;
local porcentajeIVA=21;
local porcentajeimpuestoelectricidad=5.11269632;
--[[----- FIN CONFIGURACION DE USUARIO -----------------------------------------]]

--[[----- NO CAMBIAR EL CODIGO A PARTIR DE AQUI --------------------------------]]

--[[----- CONFIGURACION AVANZADA -----------------------------------------------]]
-- obtener el ID de este dispositivo virtual
OFF=1;INFO=2;DEBUG=3		-- esto es una referencia para el log, no cambiar
nivelLog = DEBUG			-- nivel de log
local _selfId = fibaro:getSelfId();
--[[----- FIN CONFIGURACION AVANZADA -------------------------------------------]]


--[[
_log(level, log)
	funcion para operar el nivel de LOG
--------------------------------------------------------------------------------]]
function _log(level, log)
  if log == nil then log = 'nil' end
  local LOG = {}
  LOG[1]='OFF'; LOG[2]='INFO'; LOG[3]='DEBUG';
  if nivelLog >= level then
    fibaro:debug(log)
  end
  return
end

--[[----------------------------------------------------------------------------
redondea(num, idp)
	--
--]]
function redondea(num, idp)
  local mult = 10^(idp or 0)
  return math.floor(num * mult + 0.5) / mult
end

--[[----------------------------------------------------------------------------
getPreciohora(hora)
	--
--]]
function getPreciohora(hora)
  local cnomys = Net.FHttp("pvpc.cnomys.es")
  
  -- Discover available APIs and corresponding information
  payload = '/hora'
  response, status, errorCode = cnomys:GET(payload)
  if tonumber(status) == 200 then
    local jsonTable = json.decode(response)
    if (jsonTable.estado == true) then
      for key, value in pairs(normalizaPrecioHoraTab(jsonTable.datos)) do
        if value.hora == hora then
          return 0, value.precio
        end
      end 
    else
      return 1, jsonTable['razon_error']
    end
  else
    return 1, errorCode
  end
  return 1,'La hora no corresponde con la actual'
end

--[[-----------------------------------------------------------------------------
normalizaPrecioHoraTab(precioHoraTab)
	--
--]]
function normalizaPrecioHoraTab(precioHoraTab)
  local preciosTab = {}
  for key, value in pairs(precioHoraTab) do
    if value then
      preciosTab[#preciosTab + 1] = {hora = key, precio = value[pvpcTipoTarifa]}
    end
  end
  return preciosTab
end

--[[-----------------------------------------------------------------------------
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

--[[-----------------------------------------------------------------------------
getConsumoOrigen()
	devuelve el consumo inicial valor, unidad, fecha mmddhh
--]]
function getConsumoOrigen()
  local consumoTab = json.decode(fibaro:getGlobalValue(globalVarName))
  -- ordenar la tabla para compara tomar el primer valor
  local u = {}
  for k, v in pairs(consumoTab) do table.insert(u, { key = k, value = v }) end
  table.sort(u, function (a1, a2) return a1.key < a2.key; end)
  return u[1].value.valor, u[1].value.unidad, u[1].key
end

--[[----- INICIAR ----------------------------------------------------------]]
-- obtener el precio kWh 
local preciokwh = preciokwhmercadolibre --TODO se puede obtener de una web?.
if pvpc then
  -- obtener el precio para esta hora
  status, preciokwh = getPreciohora(os.date("%H"))
  -- si no se puede obtener informar del error y tomar precio 0
  if status ~= 0 then
    _log(INFO, 'Error: '..preciokwh)
    preciokwh = preciokwhmercadolibre
  else
    preciokwh = tonumber(preciokwh)
  end
end
_log(DEBUG, 'Precio: '..preciokwh..' kWh')
fibaro:log('Precio: '..preciokwh..' kWh')
  
-- obtener consumo origen y refrescar etiqueta de consumo origen
fibaro:call(_selfId, "setProperty",
 "ui.ActualOrigen.value",tostring(getConsumoOrigen()) .. " kWh")
   
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
  
--[[------- ACTUALIZAR FACTURA VIRTUAL -------------------------------------]]
-- calcular precio termino fijo 
local euroterminofijopotenciames = potenciacontratadakw *
 preciokwhterminofijo * (tonumber(os.date("%d")))
fibaro:call(_selfId, "setProperty", "ui.TerminoFijo.value",
 redondea(euroterminofijopotenciames, 2) .. " €")
   
-- calcula el precio del consumo mes
local euroterminoconsumo = getConsumo(tonumber(os.date('%m'))) * preciokwh
fibaro:call(_selfId, "setProperty", "ui.TerminoConsumo.value",
 redondea(euroterminoconsumo, 2) .. " €")
    
-- calcular precio impuesto electricidad
local impuestoelectricidad = (euroterminofijopotenciames+euroterminoconsumo) *
 porcentajeimpuestoelectricidad/100;
fibaro:call(_selfId, "setProperty", "ui.ImpuestoElectricidad.value",
 redondea(impuestoelectricidad, 2) .. " €")
 
-- calcular precio alquiler equipo
local euroalquilerequipos = precioalquilerequipodia *
 (tonumber(os.date("%d")));
fibaro:call(_selfId, "setProperty", "ui.AlquilerEquipos.value",
 redondea(euroalquilerequipos, 2) .. " €")
    
-- calcular el IVA
local IVA = (euroterminofijopotenciames + euroterminoconsumo +
 impuestoelectricidad + euroalquilerequipos) * porcentajeIVA/100
fibaro:call(_selfId, "setProperty", "ui.IVA.value", redondea(IVA,2) .. " €")
    
-- calcular TOTAL
local Total = euroterminofijopotenciames+euroterminoconsumo +
 impuestoelectricidad + euroalquilerequipos+IVA
fibaro:call(_selfId, "setProperty", "ui.Total.value", 
redondea(Total,2) .. " €")
--[[----- FIN DE LA EJECUCION --------------------------------------------------]]

--[[----- INFORME DE RESULTADOS ------------------------------------------------]]
_log(INFO, release['name']..
' ver '..release['ver']..'.'..release['mayor']..'.'..release['minor'])

--[[----- FIN INFORME DE RESULTADOS --------------------------------------------]]
--[[----------------------------------------------------------------------------]]