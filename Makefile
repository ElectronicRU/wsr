include config.mk


wsr: wsr.sh
	@echo Creating wsr script 
	@cat wsr.sh > wsr
	-@${MAKE} wsr-encoding-table
	-@cat wsr-encoding-table >> wsr

all: clean install

clean:
	@rm -f html-encoding-prescan html-encoding-prescan.o

update-encodings:
	@rm -f encodings encoding.json wsr-encoding-table .wsr-encoding-table
	@${MAKE} wsr-encoding-table

wsr-encoding-table: encodings
	@echo Preparing encodings table for use
	@echo "_wsr_encoding_table () {" > .wsr-encoding-table
	@echo "    cat <<END" >> .wsr-encoding-table
	@cat encodings >> .wsr-encoding-table
	@echo "END" >> .wsr-encoding-table
	@echo "}" >> .wsr-encoding-table
	@mv .wsr-encoding-table wsr-encoding-table

encodings: encodings.json
	@echo Generating encodings table
	@python flatten_encodings.py < encodings.json > encodings

encodings.json:
	@echo Downloading encodings.json from whatwg.org
	@curl http://encoding.spec.whatwg.org/encodings.json > encodings.json

html-encoding-prescan: html-encoding-prescan.o
	@echo ${CC} -o $@
	@${CC} -o $@ ${LDFLAGS} $@.o

.c.o:
	@echo ${CC} -c $<
	@${CC} -c ${CFLAGS} $<

install: wsr
	@echo Installing to ${PREFIX}
	@install -m 0644 wsr ${PREFIX}
	-@install html-encoding-prescan ${PREFIX}

.PHONY: all clean install
