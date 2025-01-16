﻿$ErrorActionPreference = 'Stop';
$url64          = 'https://fastdl.mongodb.org/windows/mongodb-windows-x86_64-6.0.20.zip'
$checksum64     = '47addef3cd6d8458b6386c74204cd7a294dbffb6ff09b137625e60118bda8f6b'
$checksumType64 = 'sha256'

$binRoot = Get-ToolsLocation

$pp = Get-PackageParameters
if ($pp.installDir) {
  Write-Debug "Override installDir."
  $binRoot = $pp.installDir
}

$packageName = 'mongodb'

$installDir = Join-Path $binRoot "$packageName"
$installDirBin = "$($installDir)\current\bin"
Write-Host "Adding `'$installDirBin`' to the path and the current shell path"
Install-ChocolateyPath "$installDirBin"
$env:Path = "$($env:Path);$($installDirBin)"

if (![System.IO.Directory]::Exists($installDir)) {[System.IO.Directory]::CreateDirectory($installDir) | Out-Null}

$packageArgs = @{
  packageName    = $env:ChocolateyPackageName
  unzipLocation  = $installDir
  url64bit      = $url64
  checksum64    = $checksum64
  checksumType64= $checksumType64
}

Install-ChocolateyZipPackage  @packageArgs

# find the unpack directory
$installedContentsDir = Get-ChildItem $installDir -include 'mongodb*' | Sort-Object -Property LastWriteTime -Desc | Select-Object -First 1

# delete current bin directory contents
if ([System.IO.Directory]::Exists("$installDirBin")) {
  Write-Host "Clearing out the contents of `'$installDirBin`'."
  Start-Sleep 3
  [System.IO.Directory]::Delete($installDirBin,$true)
}

# copy the installed directory into the current dir
Write-host "Copying contents of `'$installedContentsDir`' to `'$($installDir)\current`'."
[System.IO.Directory]::CreateDirectory("$installDirBin") | Out-Null
Copy-Item "$($installedContentsDir)\*" "$($installDir)\current" -Force -Recurse

# setup mongo working dirs
$dataDir = Join-Path $installDir 'data'
if (!$(Test-Path $dataDir)) {mkdir $dataDir}
$logDir = Join-Path $installDir 'log'
if (!$(Test-Path $logDir)){mkdir $logDir}

# create batch files
$exeFile = Join-Path $installDirBin 'mongo.exe'
$batchFile = Join-Path $installDirBin 'mongo.bat'
"@echo off
$exeFile %*" | Out-File $batchFile -encoding ASCII
$batchFile = Join-Path $installDirBin 'mongorotatelogs.bat'
"@echo off
$exeFile --eval `'db.runCommand(`"logRotate`")`' mongohost:27017/admin" | Out-File $batchFile -encoding ASCII

$exeFile = Join-Path $installDirBin 'mongod.exe'
$batchFile = Join-Path $installDirBin 'start-mongodb.bat'
$logFile = Join-Path $logDir "MongoDB.log"
"@echo off
$exeFile --quiet --bind_ip 127.0.0.1 --logpath $logFile --logappend --dbpath $dataDir --directoryperdb" | Out-File $batchFile -encoding ASCII

# start mongodb
Start-Process "$batchFile"
