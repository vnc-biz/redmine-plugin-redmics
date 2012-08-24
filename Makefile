
PLUGIN_NAME=redmine_ics_export
PLUGIN_DIR=$(DESTDIR)/usr/share/redmine/vendor/plugins/$(PLUGIN_NAME)

INSTALL_FILES=\
	app		\
	CHANGELOG.rdoc	\
	config		\
	Gemfile		\
	gpl-2.0.txt	\
	init.rb		\
	lib		\
	Rakefile	\
	README.rdoc

all:

install:
	@rm -Rf $(PLUGIN_DIR)
	@mkdir -p $(PLUGIN_DIR)
	@for i in $(INSTALL_FILES) ; do cp -R --preserve $$i $(PLUGIN_DIR) ; done
