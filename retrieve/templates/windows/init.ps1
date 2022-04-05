<#
        .SYNOPSIS
        Installs the rport clients and connects it to the server

        .DESCRIPTION
        This script will download the latest version of the rport client,
        create the configuration and connect to the server.
        You can change the configuration by editing C:\Program Files\rport\rport.conf
        Rport runs as a service with a local system account.

        .PARAMETER x
        Enable the execution of scripts via rport.

        .PARAMETER t
        Use the latest unstable development release. Dangerous!

        .PARAMETER i
        Install Tascoscript along with the RPort Client

        .INPUTS
        None. You cannot pipe objects.

        .OUTPUTS
        System.String. Add-Extension returns success banner or a failure message.

        .EXAMPLE
        PS> powershell -ExecutionPolicy Bypass -File .\rport-installer.ps1 -x
        Install and connext with script execution enabled.

        .EXAMPLE
        PS> powershell -ExecutionPolicy Bypass -File .\rport-installer.ps1
        Install and connect with script execution disabled.

        .LINK
        Online help: https://kb.rport.io/connecting-clients#advanced-pairing-options
#>
#Requires -RunAsAdministrator
# Definition of command line parameters
Param(
# Enable remote commands yes/no
    [switch]$x,
# Use unstable version yes/no
    [switch]$t,
# Install tacoscript
    [switch]$i
)