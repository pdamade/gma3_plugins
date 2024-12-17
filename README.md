# Cue List to PDF for GrandMA3

## Acknowledgements
Inspired by the great [Patch2PDF](https://github.com/leonreucher/grandma3-patch2pdf) plugin, and using the [pdf.lua](https://github.com/catseye/pdf.lua) library.

## Overview
This plugin allows you to export a sequence/cue list in a PDF file.

## Installation
- onPC: Copy the `.lua`and `.xml` files in the `gma3_library/datapools/plugins` folder of your installation.
- console: place the files in the `gma3_library/datapools/plugins` folder on a USB drive. If your drive does not have the MA filetree on it yet, just connect it to the console and save a show on it, it should create the whole folder structure automativcally.
- Both: Through a plugin pool window, save an empty plugin and edit it, then Import > cuelist2pdf.xml. Close edit window.
- Run the plugin by simply tapping/clicking it in the plugins pool window.

## Currently supported features:
- Export a sequence's cues with the following fields:
  - Cue number
  - Part number (if applicable)
  - Cue/Part name
  - Cue/Part note (Optional)
  - Cue/Part fade times (FadeIn/FadeOut)
  - Cue TrigType and TrigTime: F for Follow, T for Time. 
- Columns are color-tagged by trig type: Green = Go. Blue = Part. Red = Time or Follow.
- Popup will let you pick a title and filename. 
- If using onPC, saving to the internal drive is possible, simply run the plugin without any external drive connected. The file will be saved in the `gma3_library`folder of your installation.
- If on console, the file will be saved at the root of your external drive. Saving to internal os not possible on console.

## Warning
This is provided as is. I have tested it on an M1 MacBook and onPC v2.1.1, as well as on a MA3 Light also running 2.1 and both behaved as expected.\
This is also the first plugin I write and the first Lua code I write, so look at it at your own risk. It is a horrifying mess which may one day be cleaned up, or not.\
More features may be added in the future, suggestions are always welcome.

