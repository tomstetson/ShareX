$ErrorActionPreference = "Stop"
$probe = Join-Path $env:RUNNER_TEMP "sharex-sqlite-probe"
New-Item -ItemType Directory -Force $probe | Out-Null
try {
    $history = Join-Path $PSScriptRoot "../ShareX.HistoryLib/ShareX.HistoryLib.csproj"
    @"
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup><OutputType>Exe</OutputType><TargetFramework>net9.0-windows</TargetFramework><UseWindowsForms>true</UseWindowsForms><RuntimeIdentifier>win-x64</RuntimeIdentifier></PropertyGroup>
  <ItemGroup><ProjectReference Include="$history" /></ItemGroup>
</Project>
"@ | Set-Content (Join-Path $probe "Probe.csproj")
    @'
using System;
using Microsoft.Data.Sqlite;
using var connection = new SqliteConnection("Data Source=:memory:");
connection.Open();
using var command = connection.CreateCommand();
command.CommandText = "CREATE TABLE probe(value TEXT); INSERT INTO probe VALUES ('verified'); SELECT value FROM probe;";
if (!Equals(command.ExecuteScalar(), "verified")) throw new Exception("SQLite round trip failed");
command.CommandText = "SELECT sqlite_version()";
var version = (string)command.ExecuteScalar();
if (Version.Parse(version) < new Version("3.53.4")) throw new Exception("Unexpected SQLite runtime " + version);
Console.WriteLine("SQLite " + version + ": native load and in-memory round trip passed");
'@ | Set-Content (Join-Path $probe "Program.cs")
    dotnet run --project (Join-Path $probe "Probe.csproj") --configuration Release
    if ($LASTEXITCODE -ne 0) { throw "SQLite runtime verification failed" }
} finally {
    Remove-Item -Recurse -Force $probe
}
