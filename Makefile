CONVERT = convert
CONVERT_ARGS = -size 600 -background black -fill white -pointsize 16

PANGO_DIR = pango
IMAGE_DIR = images
SRCS = $(wildcard $(PANGO_DIR)/*.txt)
IMAGES = $(patsubst $(PANGO_DIR)/%,$(IMAGE_DIR)/%,$(SRCS:.txt=.png))

images: $(IMAGES)

$(IMAGE_DIR)/%.png: $(PANGO_DIR)/%.txt
	$(CONVERT) $(CONVERT_ARGS) pango:@$^ $@

