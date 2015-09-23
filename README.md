# HC2LUA-ControlConsumoElectrico
Control del consumo eléctrico para controlador domótico HC2, escrito en lenguaje LUA
Puesta en marcha
1.- Crear variable global para almacenar datos de consumo
2.- Configurar nombre de la VG en la escena ‘controlConsumo.lua’ y en los procesos ‘resetButton’, ‘updateButton’ y ‘mainLoop’
	globalVarName = ‘consumoEnergia’
3-. Configurar la propiedad para obtener consumo desde origen en la escena y en el proceso ‘resetButton’ 
	propertyName = 'energy'
	--[[
	%% properties
	512 energy
	--]]
3.- Iniciar ciclo de facturación
	lanzar proceso pulsando ‘resetButton’
4.- Iniciar escena controlConsumo (activar escena).
