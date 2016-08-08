# Converts Pango to PNG

_ARGS = -size 800 -pointsize 14 -border 3
ARGS = $(_ARGS) -fill white -background black -bordercolor black
ARGS_WHITE = $(_ARGS) -fill black -background white -bordercolor white

PANGO_DIR = pango
IMAGE_DIR = images
SRCS = $(wildcard $(PANGO_DIR)/*.txt)
IMAGES = $(patsubst $(PANGO_DIR)/%,$(IMAGE_DIR)/%,$(SRCS:.txt=.png))

images: $(IMAGES)

$(IMAGE_DIR)/white.png: $(PANGO_DIR)/white.txt
	convert $(ARGS_WHITE) pango:"`< $^`" $@

$(IMAGE_DIR)/%.png: $(PANGO_DIR)/%.txt
	convert $(ARGS) pango:"`< $^`" $@

