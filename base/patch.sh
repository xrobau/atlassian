#!/bin/bash

LDC=Version2LicenseDecoder

CLASSES=commons-codec-1.15.jar:commons-codec-1.14.jar:atlassian-extras-api-3.4.6.jar:atlassian-extras-legacy-3.4.6.jar:atlassian-extras-common-3.4.6.jar:atlassian-extras-decoder-api-3.4.6.jar:atlassian-extras-key-manager-3.4.6.jar:atlassian-extras-3.4.6.jar

rm -rf /usr/local/patch/

function patchJar() {
	JARFILE=$1
	CLASS=$2
	ORIGFILE=$JARFILE.orig
	FILE=$(basename $JARFILE | sed -E 's/.jar$//')
	VERS=$(basename $JARFILE | sed -E 's/.+-([0-9\.]+).jar/\1/')
	echo "Patching $JARFILE from $FILE as $VERS"
	ls -al $JARFILE
	mkdir -p /usr/local/patch/$FILE/orig /usr/local/patch/$FILE/patched
	[ ! -e $ORIGFILE ] && cp $JARFILE $ORIGFILE
	cd /usr/local/patch/$FILE
	unzip -j ${ORIGFILE} ${CLASS}
	java -jar /usr/local/bin/fernflower.jar -hdc=0 -dgs=1 -rsy=1 -lit=1 ${LDC}.class .
	PROOT=/usr/local/patch/$FILE/patched
	PATCHED=$PROOT/$(dirname ${CLASS})
	mkdir -p $PATCHED
	cp ${LDC}*java $PATCHED
	PATCHEDJAVA=${PATCHED}/${LDC}.java
	sed -E -i \
		-e '/return properties;/i// Force Recent MED\n\tproperties.setProperty("MaintenanceExpiryDate", "2029-01-01");' \
		-e '/import org.apache/i import java.util.Map;' \
		-e '/return properties;/i // Debugging\nMap<String, String> env = System.getenv();\nfor (String envName : env.keySet()) {\n if (envName.startsWith("EXTRAS_")) {\n  System.out.format("DEBUG: --- OVERRIDE %s to %s%n", envName.substring(envName.indexOf("_")+1),env.get(envName));\n properties.setProperty(envName.substring(envName.indexOf("_")+1),env.get(envName)); }\n}' \
		-e '/return properties;/i properties.forEach((k, v) -> {System.out.format("DEBUG: %s=%s%n", k, v);});' \
        	${PATCHEDJAVA}
	cd $(dirname $JARFILE)
	javac -source 8 -target 8 -cp $CLASSES $PATCHEDJAVA -d $PROOT
	cd ${PROOT}
	jar -uf ${JARFILE} ${CLASS}
	chown 1000.1000 ${JARFILE}
	ls -al $JARFILE
}


JARS=$(find /opt/atlassian -name at*jar -print)
for x in $JARS; do
	RES=$(zipinfo -1 $x | grep $LDC)
	[ "$RES" ] && patchJar $x $RES
done
exit 0
