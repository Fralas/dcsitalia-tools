--------------------------------------------------------------------------------------------------------------------------------
-- DZONE_TEST_Config.lua - Grafo zone per validazione collegamenti (stile DMAP)
--------------------------------------------------------------------------------------------------------------------------------
-- Modifica solo la tabella `confini`: per ogni zona elenca le zone confinanti.
-- I nomi devono corrispondere alle trigger zone create nel Mission Editor.
--
-- Esempio:
--   ["zone_00"] = {"zone_01", "zone_10"},
--   ["zone_01"] = {"zone_00", "zone_02", "zone_11"},

local ZONE_PREFIX = "zone_"

-- Stile disegno F10 (allineato a DMAP_Config.lua)
local ZONE_LINE_TYPE       = 1
local ZONE_FILL_ALPHA      = 0.0
local LABEL_FONT_SIZE      = 10
local LABEL_OFFSET_X_M     = 1000
local LABEL_OFFSET_Y_M     = 1000
local LABEL_TEXT_COLOR     = {255, 255, 255}
local LABEL_TEXT_ALPHA     = 1
local LABEL_BG_COLOR       = {0.4, 0.4, 0.4}
local LABEL_BG_ALPHA       = 1

local COLOR_ZONE           = {1.0, 1.0, 1.0}
local COLOR_LINK           = {0.80, 0.55, 0.10}
local COLOR_LINK_ERROR     = {1.0, 0.0, 0.0}
local COLOR_ZONE_MISSING   = {1.0, 0.0, 0.0}

-- Ritardo prima del primo disegno (secondi) e refresh periodico.
local START_DELAY_SEC      = 5
local REDRAW_SEC           = 60

-- Collegamenti tra zone: definisci qui il grafo da verificare.
local confini = {
  ["zone_00"] = {"zone_01", "zone_10"},
  ["zone_01"] = {"zone_00"},
  ["zone_10"] = {"zone_00"},
}

return {
  ZONE_PREFIX = ZONE_PREFIX,
  ZONE_LINE_TYPE = ZONE_LINE_TYPE,
  ZONE_FILL_ALPHA = ZONE_FILL_ALPHA,
  LABEL_FONT_SIZE = LABEL_FONT_SIZE,
  LABEL_OFFSET_X_M = LABEL_OFFSET_X_M,
  LABEL_OFFSET_Y_M = LABEL_OFFSET_Y_M,
  LABEL_TEXT_COLOR = LABEL_TEXT_COLOR,
  LABEL_TEXT_ALPHA = LABEL_TEXT_ALPHA,
  LABEL_BG_COLOR = LABEL_BG_COLOR,
  LABEL_BG_ALPHA = LABEL_BG_ALPHA,
  COLOR_ZONE = COLOR_ZONE,
  COLOR_LINK = COLOR_LINK,
  COLOR_LINK_ERROR = COLOR_LINK_ERROR,
  COLOR_ZONE_MISSING = COLOR_ZONE_MISSING,
  START_DELAY_SEC = START_DELAY_SEC,
  REDRAW_SEC = REDRAW_SEC,
  confini = confini,
}
