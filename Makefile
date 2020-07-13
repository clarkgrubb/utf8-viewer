MAKEFLAGS += --warn-undefined-variables
SHELL := bash
.SHELLFLAGS := -e -o pipefail -c
.DEFAULT_GOAL := all
.DELETE_ON_ERROR:
.SUFFIXES:

LOCAL_INSTALL_DIR ?= $(shell if [ -d ~/Local/bin ]; then echo ~/Local/bin; else echo /usr/local/bin; fi)
LOCAL_MAN_DIR ?= $(shell if [ -d ~/Local/man ]; then echo ~/Local/man; else echo /usr/local/share/man; fi)

local_man1_dir := $(LOCAL_MAN_DIR)/man1
man1_source := $(wildcard *.1.md)
man1_targets := $(patsubst %.md,%,$(man1_source))
pwd := $(shell pwd)
VPATH = test
GEM_HOME = .gems

.PHONY: setup.ruby
setup.ruby: $(GEM_HOME)

$(GEM_HOME):
	GEM_HOME=$(GEM_HOME) gem install rubocop

bin:
	mkdir $@
	LOCAL_INSTALL_DIR=$(shell pwd)/bin make install-script install-c

.PHONY: setup
setup: setup.ruby

# To generate the man pages `pandoc` must be installed.  On Mac go to
#
#    http://johnmacfarlane.net/pandoc/installing.html
#
#  and download the installer.  On Ubuntu there is a package:
#
#    $ sudo apt-get install pandoc
#
# An uninstalled man page can be viewed with the man command:
#
#    $ man doc/foo.1
#
%.1: %.1.md
	pandoc -s -s -w man $< -o $@

.PHONY: man_targets
man_targets: $(man1_targets)

$(local_man1_dir):
	mkdir -p $@

.PHONY: install-man
install-man: $(local_man1_dir)
	if [ ! -d $(LOCAL_MAN_DIR)/man1 ]; then \
	echo directory does not exist: $(LOCAL_MAN_DIR)/man1; \
	false; \
	fi
	for target in $(man1_targets); \
	do \
	cp $$target $(LOCAL_MAN_DIR)/man1; \
	done

.PHONY: install-script
install-script:
	cp utf8_viewer.rb $(LOCAL_INSTALL_DIR)/utf8-viewer

.PHONY: install
install: install-man
	ln -s $(shell pwd)/utf8_viewer.rb $(LOCAL_INSTALL_DIR)/utf8-viewer

.PHONY: all
all:
	@echo
	@echo 'To install Ruby gems:'
	@echo
	@echo '   $$ sudo make setup'
	@echo
	@echo 'To install utf8-viewer and man page:'
	@echo
	@echo '   $$ make install'
	@echo

output:
	mkdir -p $@

output/%:
	mkdir -p $@

# doesn't pass with Ruby 1.8:
#
.PHONY: test.utf8_viewer
test.utf8_viewer: | output/utf8_viewer
	-ruby -e '(0..255).each { |i| print i.chr }' \
	| ./utf8_viewer.rb -bc \
	> output/bytes.bcr.out
	diff test/expected.bytes.bcr.out output/bytes.bcr.out
	#
	./utf8_viewer.rb -a 33 34 35 > output/arg.decimal.out
	diff test/expected.arg.out output/arg.decimal.out
	#
	./utf8_viewer.rb -a 041 042 043 > output/arg.octal.out
	diff test/expected.arg.out output/arg.octal.out

ruby_base := utf8_viewer
ruby_harnesses := $(patsubst %,test.%,$(ruby_base))

.PHONY: ruby.harness
ruby.harness: $(ruby_harnesses)

.PHONY: test.harness
test.harness: ruby.harness

.PHONY: rubocop
rubocop: $(GEM_HOME)
	  echo *.rb | GEM_HOME=$(GEM_HOME) xargs $(GEM_HOME)/bin/rubocop -c .rubocop.yml

.PHONY: check
check: rubocop test.harness

.PHONY: clean
clean:
	-rm -rf output
