param(
    [Parameter(Mandatory=$False)]
    [String]
    $debdir
)

If(!$debdir){
    $debdir = "build/debian/"
    if(!(Test-Path -Path $debdir)){
        $debdir = "debian/"
    }
}

$ver = (Get-Content $debdir/changelog -Head 1) -replace ".*\((\d*\.\d*\.\d*)(\-\d+){0,1}\).*",'$1'
echo "$ver"
