#!/bin/bash

# Creates a version for given package on Bintray
# Usage:
#     createVersionOnBintray <user-name> <repo-name> <package-name> <version-name>
function createVersionOnBintray {
	local res=$(curl -o bintray.log -s --write-out "%{http_code}" -u$MYCI_BINTRAY_USERNAME:$MYCI_BINTRAY_API_KEY -H"Content-Type:application/json" -X POST -d"{\"name\":\"$4\",\"desc\":\"\"}" https://api.bintray.com/packages/$1/$2/$3/versions);
    [ -z "$res" ] && source myci-error.sh "curl failed while creating version on Bintray";
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
	local res=$(curl -o bintray.log -s --write-out "%{http_code}" -u$MYCI_BINTRAY_USERNAME:$MYCI_BINTRAY_API_KEY -H"Content-Type:application/json" -X POST -d"{\"name\":\"$3\",\"desc\":\"\", \"licenses\":[\"MIT\"], \"vcs_url\":\"http://github.com\"}" https://api.bintray.com/packages/$1/$2);
    [ -z "$res" ] && source myci-error.sh "curl failed while creating package on Bintray";
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
	local res=$(curl -o bintray.log -s --write-out "%{http_code}" -u$MYCI_BINTRAY_USERNAME:$MYCI_BINTRAY_API_KEY -T $1 -H"X-Bintray-Package:$4" -H"X-Bintray-Version:$5" -H"X-Bintray-Debian-Distribution:$6" -H"X-Bintray-Debian-Component:$7" -H"X-Bintray-Debian-Architecture:$8" -H"X-Bintray-Override:1" -H"X-Bintray-Publish:1" https://api.bintray.com/content/$2/$3/dists/$6/$7/binary-$8/);
    [ -z "$res" ] && source myci-error.sh "curl failed while uploading to Debian repo on Bintray";
    echo '' >> bintray.log # to add a newline to the log
	[ $res -ne 201 ] && cat bintray.log && myci-error.sh "uploading file '$1' to Bintray package '$4' version $5 failed, HTTP code = $res";
    echo "File '$1' uploaded to Bintray package '$4' version '$5'."
	return 0;
}

# Uploads a file to Bintray generic repo.
# Usage:
#     uploadFileToGenericBintray <file-to-upload> <user-name> <repo-name> <repo-path> <package-name> <version>
function uploadFileToGenericBintray {
	local res=$(curl -o /dev/null -s --write-out "%{http_code}" -u$MYCI_BINTRAY_USERNAME:$MYCI_BINTRAY_API_KEY -T $1 -H"X-Bintray-Package:$5" -H"X-Bintray-Version:$6" -H"X-Bintray-Override:1" -H"X-Bintray-Publish:1" https://api.bintray.com/content/$2/$3/$4/);
	[ -z "$res" ] && source myci-error.sh "curl failed while uploading file to Generic repo on Bintray";
	[ $res -ne 201 ] && myci-error.sh "uploading file '$1' to Bintray package '$5' version $6 failed, HTTP code = $res";
	echo "File '$1' uploaded to Bintray package '$5' version '$6'."
	return 0;
}

# Delete file from Bintray.
# Usage:
#     deleteFileFromBintray <file-to-delete> <user-name> <repo-name> <repo-path>
function deleteFileFromBintray {
	local res=$(curl -o /dev/null -s --write-out "%{http_code}" -u$MYCI_BINTRAY_USERNAME:$MYCI_BINTRAY_API_KEY -X DELETE https://api.bintray.com/content/$2/$3/$4/$1);
    [ -z "$res" ] && source myci-error.sh "curl failed while deleting file from Bintray";
	[ $res -ne 200 ] && myci-warning.sh "deleting file '$1' from Bintray failed, HTTP code = $res";
	return 0;
}

# Get package name from filename of form "myfile-1.3.0.suffix".
# Usage:
#     package_from_package_version_filename <filename>
function package_from_package_version_filename {
    echo "$1" | sed -n -e's/^\(.*\)-[0-9]\+\.[0-9]\+\.[0-9]\+\..*/\1/p';
    return 0;
}

# Get version from filename of form "myfile-1.3.0.suffix".
# Usage:
#     package_name_from_package_version_filename <filename>
function version_from_package_version_filename {
    echo "$1" | sed -n -e"s/^.*-\([0-9]\+\.[0-9]\+\.[0-9]\+\)\..*/\1/p";
    return 0;
}
