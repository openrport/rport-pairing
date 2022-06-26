#Requires -RunAsAdministrator
# Definition of command line parameters
Param(
# Use unstable version yes/no
    [Switch]$t,
# Enable scripts
    [Switch]$x,
# Disable scripts
    [Switch]$d,
# Show a help message
    [Switch]$h,
# Install or update tacoscript
    [Switch]$m,
# Force update
    [Switch]$f,
# Install a specific version
    [String]$v,
# Enable file reception
    [Switch]$r
)