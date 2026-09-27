# Nota GPU — Intel HD 620 (verificado 2026-09-27)

El .exe con Forward+/Vulkan crashea (`0xC0000005`) en ESTA máquina durante la
compilación de shaders: driver Intel 25.20.100.6373 de 2018 + Vulkan 1.1.85.
Sin errores de script, export limpio, y el mismo binario corre con
`--rendering-driver opengl3`. Causa ambiental, no del juego.

Recomendado: actualizar el driver Intel (gratis) o lanzar con
`espanasettlers.exe --rendering-driver opengl3`.
Requisito publicado: GPU con Vulkan y drivers actualizados.
