#!/bin/bash


# Creates a version for given package on Bintray
# Usage:
#     createVersionOnBintray <user-name> <repo-name> <package-name> <version-name>
function createVersionOnBintray {
	local res=$(curl -o bintray.log -s --write-out "%{http_code}" -u$1:$MYCI_BINTRAY_API_KEY -H"Content-Type:application/json" -X POST -d"{\"name\":\"$4\",\"desc\":\"\"}" https://api.bintray.com/packages/$1/$2/$3/versions);
    echo '' >> bintray.log # to add a newline to the log
    # If response code was 409 then package version already exists, this is not an error case.
    if [ $res -ne 409 ]; then
	    [ $res -ne 201 ] && cat bintray.log && myci-error.sh "Creating version $4 on Bintray for package '$3' failed, HTTP code = $res.";
        echo "Version '$4' for package '$3' created on Bintray successfully."
    fi
	return 0;
}


# Creates a package on Bintray.
# Usage:
#     createPackageOnBintray <user-name> <repo-name> <package-name>
function createPackageOnBintray {
	local res=$(curl -o bintray.log -s --write-out "%{http_code}" -u$1:$MYCI_BINTRAY_API_KEY -H"Content-Type:application/json" -X POST -d"{\"name\":\"$3\",\"desc\":\"\", \"licenses\":[\"MIT\"], \"vcs_url\":\"http://github.com\"}" https://api.bintray.com/packages/$1/$2);
    echo '' >> bintray.log # to add a newline to the log
    # If response code was 409 then package already exists, this is not an error case.
    if [ $res -ne 409 ]; then
	    [ $res -ne 201 ] && cat bintray.log && myci-error.sh "Creating package '$3' failed, HTTP code = $res.";
        echo "Package '$3' created on Bintray."
    fi
	return 0;
}


# Uploads a file to Bintray debian repo.
# Usage:
#     uploadFileToDebianBintray <file-to-upload> <user-name> <repo-name> <package-name> <version-name> <distribution> <component> <arch>
function uploadFileToDebianBintray {
	local res=$(curl -o bintray.log -s --write-out "%{http_code}" -u$2:$MYCI_BINTRAY_API_KEY -T $1 -H"X-Bintray-Package:$4" -H"X-Bintray-Version:$5" -H"X-Bintray-Debian-Distribution:$6" -H"X-Bintray-Debian-Component:$7" -H"X-Bintray-Debian-Architecture:$8" -H"X-Bintray-Override:1" -H"X-Bintray-Publish:1" https://api.bintray.com/content/$2/$3/dists/$6/$7/binary-$8/);
    echo '' >> bintray.log # to add a newline to the log
	[ $res -ne 201 ] && cat bintray.log && myci-error.sh "uploading file '$1' to Bintray package '$4' version $5 failed, HTTP code = $res";
    echo "File '$1' uploaded to Bintray package '$4' version '$5'."
	return 0;
}

