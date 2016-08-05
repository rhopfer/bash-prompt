CONVERT_ARGS = -size 800 -background black -fill white -pointsize 14 -bordercolor black -border 3

PANGO_DIR = pango
IMAGE_DIR = images
SRCS = $(wildcard $(PANGO_DIR)/*.txt)
IMAGES = $(patsubst $(PANGO_DIR)/%,$(IMAGE_DIR)/%,$(SRCS:.txt=.png))

images: $(IMAGES)

$(IMAGE_DIR)/%.png: $(PANGO_DIR)/%.txt
	convert $(CONVERT_ARGS) pango:"`< $^`" $@

