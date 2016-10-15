# Tested only on Mac OS X, YMMV, etc

all: unzip detab

unzip:
	unzip -o Duane\ Blehm\'s\ Code.zip >/dev/null

detab: unzip
	cp -Rp Duane\ Blehm\'s\ Code Duane\ Blehm\'s\ Code.bak
	( cd Duane\ Blehm\'s\ Code && find . -name '*.[pP]as' -exec tab2space -lf -t3 {} {} \; )
	( cd Duane\ Blehm\'s\ Code && find . -name '*.[pP]as' -exec perl -i -p -e "s/ +\Z//" {} \; )
	( cd Duane\ Blehm\'s\ Code && find . -name '*.[rR]'   -exec tab2space -lf {} {} \; )
	( cd Duane\ Blehm\'s\ Code && find . -name '*.txt'    -exec tab2space -lf {} {} \; )
	( cd Duane\ Blehm\'s\ Code && find . -exec touch -r ../Duane\ Blehm\'s\ Code.bak/{} {} \; )
	rm -r Duane\ Blehm\'s\ Code.bak

