# CaptureLine

[简体中文](../../README.md) · [English](README.en.md) · Español

CaptureLine organiza capturas y grabaciones de macOS en una cuerda en la parte superior de la pantalla. Permite copiar, arrastrar y abrir imágenes y vídeos.

Es una versión derivada de [Tendedero](https://github.com/alejandrobujan/tendedero), creado por **Alejandro Buján**. La idea de la cuerda y la implementación original proceden de Tendedero. Esta versión se mantiene de forma independiente y no está afiliada ni respaldada por su autor. Consulta [CREDITS.md](../../CREDITS.md) y [LICENSE](../../LICENSE).

## Funciones

- Capturas del sistema y grabaciones MOV, MP4 y M4V.
- Portadas asíncronas. Un clic copia el archivo; doble clic o pulsación prolongada abre el reproductor predeterminado.
- Copia y marcado de imágenes, arrastre, animaciones y restauración al reiniciar.
- La gestión de capturas y grabaciones guarda los archivos directamente en la carpeta interna, sin pasar por el Escritorio. Los ajustes previos se restauran al cerrar normalmente o desactivar la opción.
- La cuerda se puede desplegar en otros escritorios, aplicaciones, pantalla completa y Organizador Visual. Lleva el cursor al borde superior o pulsa **Control+Opción+T**. Al alejarte se oculta.
- Funciona localmente, sin cuenta, estadísticas ni subida de archivos.

## Uso y compilación

Requiere macOS 14 o posterior. El script genera una aplicación universal para Apple silicon e Intel.

El repositorio contiene código fuente. Descarga un ZIP de la aplicación si hay uno en [Releases](https://github.com/zlw13089391715-creator/CaptureLine/releases); si no, compílala con Xcode o Command Line Tools:

```sh
git clone https://github.com/zlw13089391715-creator/CaptureLine.git
cd CaptureLine
bash scripts/build-app.sh
open build/CaptureLine.app
swift scripts/check-strings.swift
bash scripts/check-recordings.sh
```

El script puede usar un SDK macOS 26 instalado; `SDKROOT` permite elegir uno compatible. Xcode completo puede ser necesario si faltan complementos de macros de SwiftUI. Se usa Developer ID si está disponible, o una firma local provisional. El script no realiza la notarización de Apple; los paquetes locales aún no están notarizados.

Coloca CaptureLine.app en Aplicaciones, cierra Tendedero o una instancia anterior y activa la gestión de capturas y grabaciones. Usa los atajos habituales o Command+Mayús+5 para grabar. El vídeo aparece cuando termina de guardarse y su pista es legible. Si la barra de captura ya estaba abierta al cambiar los ajustes, ciérrala y ábrela de nuevo.

La carpeta es `~/Library/Application Support/CaptureLine/Screenshots`, también para vídeos. La cuerda usa ese archivo sin duplicarlo. La cruz envía los elementos internos a la Papelera; retirar archivos externos conserva sus originales. El menú contextual permite mostrar en Finder o guardar en el Escritorio. Los vídeos normales del Escritorio no se recogen automáticamente; puedes añadir grabaciones existentes desde el menú.

Las comprobaciones de medios, traducciones y compilación universal pasaron. Se verificó la grabación del sistema y el guardado directo en la carpeta interna. La versión 1.0.5 corrige la visibilidad en pantalla completa. El usuario confirmó el despliegue en el Escritorio y una app a pantalla completa en el Mac de prueba; otras apps, Organizador Visual y versiones de macOS requieren más verificación.

El módulo SwiftPM conserva `Tendedero`; la aplicación usa nombre, icono e identificador propios. Se conserva la licencia MIT y el copyright original. El nombre e icono de Tendedero no están incluidos en esa licencia y no se redistribuyen sus imágenes promocionales. Cambios: [CHANGELOG.md](../../CHANGELOG.md).
