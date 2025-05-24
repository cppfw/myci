param(
    [Parameter(Mandatory=$True)]
    [String]
    $version,

    [Parameter(Mandatory=$True)]
    [String]
    $gitref,

    [Parameter(Mandatory=$False)]
    [String]
    $vcpkgdir
)

$scriptdir = Split-Path $MyInvocation.MyCommand.Path

If(!$vcpkgdir){
    $vcpkgdir = "build/vcpkg/"
    echo "vcpkgdir is not given, using default location: $vcpkgdir"
}

echo "apply version $version to vcpkg.json.in -> vcpkg.json"
((Get-Content $vcpkgdir/vcpkg.json.in) -replace '\$\(version\)',"$version") | Set-Content $vcpkgdir/vcpkg.json

$json = (Get-Content "$vcpkgdir/vcpkg.json" -Raw) | ConvertFrom-Json

$homepage = $json.homepage
$package_name = $json.name

$archive_url = "$homepage/archive/$gitref.tar.gz"

echo "calculate sources archive's sha512: $archive_url"
$sha512 = (Get-FileHash -Algorithm SHA512 -InputStream ([System.Net.WebClient]::new().OpenRead($archive_url))).Hash
echo "  sha512 = $sha512"

$overlay_package_dir = "$vcpkgdir/overlay/$package_name"
echo "create overlay directory: $overlay_package_dir"
New-Item -ItemType Directory -Force -Path $overlay_package_dir

echo "apply git-ref and sha512 to portfile.cmake.in -> $overlay_package_dir/portfile.cmake"
((Get-Content $vcpkgdir/portfile.cmake.in) -replace '\$\(git_ref\)',"$gitref" -replace '\$\(archive_hash\)',"$sha512") | Set-Content $overlay_package_dir/portfile.cmake

echo "format vcpkg.json"
Push-Location
cd $vcpkgdir
vcpkg format-manifest ./vcpkg.json
Pop-Location

Move-Item -Path $vcpkgdir/vcpkg.json -Destination $overlay_package_dir -Force
Copy-Item -Path $vcpkgdir/usage -Destination $overlay_package_dir -Force

echo "vcpkg package prepared"
