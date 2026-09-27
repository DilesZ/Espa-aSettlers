# Art pipeline — Blender → glTF → Draco + KTX2 → R3F

## Reglas

- Solo licencias CC0/MIT/Apache (Quaternius, KayKit, Kenney). Prohibido NC/ND.
- Formato: `.glb` + compresión Draco/Meshopt + texturas KTX2/Basis + WebP para UI.
- Presupuestos Fase 00-01: atlas 512px + vertex color, 1 material por placeholder.

## Export Blender

1. Limpia: Apply Transforms, triangula solo si hace falta, 1 UV por mesh.
2. Materiales: Principled BSDF → `BaseColor/Metallic/Roughness/Normal`.
3. Export glTF 2.0 `.glb`: Y-up, +Z, comprime con Draco, incluye normales + AO bakeada.
4. Texturas: exporta PNG 1024 → convierte a KTX2 (`toktx --bc7` o `gltf-transform`).

## Optimiza

```bash
npx -y @gltf-transform/cli optimize entrada.glb salida.glb --compress draco --texture-compress ktx2
```

Verifica: `<5 s` importación, 4 mapas enlazados, sin errores consola.
Guarda en `public/assets/<fase>/` y documenta peso antes/después en el PR.
