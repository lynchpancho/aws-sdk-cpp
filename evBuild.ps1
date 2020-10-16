$awssdkcppver = "1.8.66-1"
$optdir = @{
    x86 = "C:\opt (x86)"
    x64 = "C:\opt"
}
$sdkver = ""

function SetupEnvironment([string]$platform, [string]$sdkver)
{
    # Default to our vc140 install path unless we find a newer install
    $vcvars = "${env:ProgramFiles(x86)}\Microsoft Visual Studio 14.0\VC\vcvarsall.bat"

    # Try newer visual studio versions first in order to get a newer version of msbuild which may be required
    # Newer installs won't pickup the correct msbuild when executing vcvarsall from the old path
    $basePath = "${env:ProgramFiles(x86)}\Microsoft Visual Studio"
    gci -dir "$basePath" | % {
        gci -dir $_.FullName | % {
            $verPath = $_.FullName
            $filePath = "$verPath\VC\Auxiliary\Build\vcvarsall.bat"
            if (Test-Path "$filePath")
            {
                $vcvars = $filePath
            }
        }
    }

    # Is there a better way to get the environment than this?
    "$vcvars $platform $sdkver"
    cmd /c "`"$vcvars`" $platform $sdkver & set" | % { Invoke-Expression "`${env:$_`"".Replace("=", "}=`"") } 2>$null
}

function GetPlatform([string]$platform)
{
    if ($platform -eq "x86")
    {
        return "Win32"
    }

    return $platform
}

$components = @("aws-cpp-sdk-core","aws-cpp-sdk-s3","aws-cpp-sdk-transfer","aws-cpp-sdk-transfer")
$builds = @("Debug")

# Set-PSDebug -Trace 1

foreach ($platform in "x64")
{
    SetupEnvironment $platform $sdkver
    $slnPlatform = GetPlatform $platform

    # clear out any previous builds
    "Deleting build..."
    rd -Recurse -Force build\

    foreach ($build in $builds)
    {
        # create the build directories
        mkdir "build\msw\${build}"

        # run cmake 
        pushd "build\msw\${build}"
        "Executing cmake for ${build}..."
        cmake ..\..\.. -G "Visual Studio 14 Win64" -DCMAKE_BUILD_TYPE="${build}"

        foreach($component in $components)
        {
            pushd "${component}"
            "Building ${component}..."
            msbuild ALL_BUILD.vcxproj /p:Configuration="${build}" /p:Platform=$slnPlatform /p:PlatformToolset=v140 
            popd
        }
        popd
    }

    $outdir = $optdir.$platform + "\aws-sdk-cpp\${awssdkcppver}_vc14"

    "Deleting '${outdir}'..."
    rd -Recurse -Force "${outdir}"

    # dlls
    foreach ($build in $builds)
    {
        pushd "build\msw\${build}"
        "Copying dlls from 'bin\${build}\' to '${outdir}\bin\${build}\'..."
        cp -r -force "bin\${build}\" "${outdir}\bin\${build}\"
        popd
    }

    # lib
    foreach ($build in $builds)
    {
        pushd "build\msw\${build}"
        foreach ($component in $components)
        {
            pushd "${component}"
            "Copying lib from '${component}\${build}' to '${outdir}\bin\${build}\'..."
            cp -r -force "${build}\*.*" "${outdir}\bin\${build}\"
            popd
        }
        popd
    }

    # headers
    foreach ($component in $components)
    {
        pushd "${component}"
        "Copying headers from '${component}\include\' to '${outdir}\include\'..."
        cp -r -force "include\" "${outdir}\"
        popd
    }

    "Done!"
    ""
}