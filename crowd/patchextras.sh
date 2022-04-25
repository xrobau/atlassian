#!/bin/bash

F=$1
CP=$(dirname $F)
EXTRAS=$(basename $F | sed -E 's/.+-extras-([0-9\.]+).jar/\1/')
echo "Patching $F from $CP as $EXTRAS"
ls -al $F

PKG=com/atlassian/extras/decoder/v2
LDC=${PKG}/Version2LicenseDecoder
cp $F $F.orig
mkdir -p /usr/local/patch/orig/${PKG} /usr/local/patch/patched/${PKG} 
cd /usr/local/patch/orig
java -jar /usr/local/bin/fernflower.jar -hdc=0 -dgs=1 -rsy=1 -lit=1 ${F} . > /dev/null
rm -f ${LDC}.java
unzip $(basename $F) ${LDC}.java
# find . -name Version2Licens* -ls
cp ${LDC}*java /usr/local/patch/patched/${PKG}/
cd /usr/local/patch/patched
patch -p1 < /usr/local/bin/extras.patch

sed -E -i \
  -e '/this.loadLicenseConfig/a properties.setProperty("MaintenanceExpiryDate", "2029-01-01");' \
  -e '/this.loadLicenseConfig/a properties.setProperty("CreationDate", "2028-01-01");' \
  -e '/this.loadLicenseConfig/a properties.setProperty("PurchaseDate", "2028-01-01");' \
  -e '/this.loadLicenseConfig/a properties.setProperty("Evaluation", "false");' \
  -e '/this.loadLicenseConfig/a properties.setProperty("LicenseExpiryDate", "unlimited");' \
     ${LDC}.java

cd $CP

javac -source 8 -target 8 -cp commons-codec-1.15.jar:atlassian-extras-${EXTRAS}.jar:atlassian-extras-common-${EXTRAS}.jar:atlassian-extras-key-manager-${EXTRAS}.jar \
       	/usr/local/patch/patched/${LDC}.java

cd /usr/local/patch/patched
#find . -name Version2Licens* -ls
jar -uf $F ${LDC}.class
chown 1000.1000 ${F}

echo "After patching:"
ls -al $F
