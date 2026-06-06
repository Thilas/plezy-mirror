[CmdletBinding(SupportsShouldProcess)]
param(
    [string] $SourceRepo = 'edde746/plezy',
    [string] $TarGzAssets = '*android*.tar.gz',
    [int] $MaxReleases
)

function Get-Releases {
    [CmdletBinding()]
    param(
        [switch] $ExcludeDrafts,
        [switch] $ExcludePrereleases,
        [string[]] $Property = @('createdAt', 'isDraft', 'isImmutable', 'isLatest', 'isPrerelease', 'name', 'publishedAt', 'tagName'),
        [int] $Limit,
        [switch] $Asc,
        [string] $Repo
    )
    $arguments = @(
        'release', 'list'
        if ($ExcludeDrafts) { '--exclude-drafts' }
        if ($ExcludePrereleases) { '--exclude-pre-releases' }
        '--json', ($Property -join ',')
        if ($Limit) { '--limit', $Limit }
        if ($Asc) { '--order', 'asc' }
        if ($Repo) { '--repo', $Repo }
    )
    Write-Verbose "gh $arguments"
    & gh $arguments | ConvertFrom-Json
}

function Get-Release {
    [CmdletBinding()]
    param(
        [Alias('tagName')]
        [ValidateNotNullOrWhiteSpace()]
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string] $Tag,
        [string[]] $Property = @('apiUrl', 'assets', 'author', 'body', 'createdAt', 'databaseId', 'id', 'isDraft', 'isImmutable', 'isPrerelease', 'name', 'publishedAt', 'tagName', 'tarballUrl', 'targetCommitish', 'uploadUrl', 'url', 'zipballUrl'),
        [string] $Repo
    )
    $arguments = @(
        'release', 'view'
        $Tag
        '--json', ($Property -join ',')
        if ($Repo) { '--repo', $Repo }
    )
    Write-Verbose "gh $arguments"
    & gh $arguments | ConvertFrom-Json
}

function Get-Asset {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Alias('tagName')]
        [ValidateNotNullOrWhiteSpace()]
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string] $Tag,
        [ValidateSet('zip', 'tar.gz')]
        [string] $Archive,
        [switch] $Clobber,
        [string] $OutDirectory,
        [string] $OutFile,
        [string[]] $Pattern,
        [switch] $SkipExisting,
        [string] $Repo
    )
    $arguments = @(
        'release', 'download'
        $Tag
        if ($Archive) { '--archive', $Archive }
        if ($Clobber) { '--clobber' }
        if ($OutDirectory) { '--dir', $OutDirectory }
        if ($OutFile) { '--output', $OutFile }
        if ($Pattern) { $Pattern | ForEach-Object { '--pattern', $_ } }
        if ($SkipExisting) { '--skip-existing' }
        if ($Repo) { '--repo', $Repo }
    )
    Write-Verbose "gh $arguments"
    if ($PSCmdlet.ShouldProcess("GitHub release: $Tag", 'Download assets')) {
        & gh $arguments
    }
}

function Add-Release {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Alias('tagName')]
        [ValidateNotNullOrWhiteSpace()]
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string] $Tag,
        [string[]] $Asset,
        [Alias('isDraft')]
        [Parameter(ValueFromPipelineByPropertyName)]
        [switch] $Draft,
        [switch] $FailOnNoCommits,
        [switch] $GenerateNotes,
        [System.Nullable[bool]] $Latest,
        [Alias('body')]
        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $Notes,
        [Alias('isPrerelease')]
        [Parameter(ValueFromPipelineByPropertyName)]
        [switch] $Prerelease,
        [Alias('targetCommitish')]
        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $Target,
        [Alias('name')]
        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $Title,
        [switch] $VerifyTag,
        [string] $Repo
    )
    $arguments = @(
        'release', 'create'
        $Tag
        $Asset
        if ($Draft) { '--draft' }
        if ($FailOnNoCommits) { '--fail-on-no-commits' }
        if ($GenerateNotes) { '--generate-notes' }
        if ($Latest) { '--latest' }
        elseif ($false -eq $Latest) { '--latest=false' }
        if ($Notes) { '--notes', $Notes }
        if ($Prerelease) { '--prerelease' }
        if ($Target) { '--target', $Target }
        if ($Title) { '--title', $Title }
        if ($VerifyTag) { '--verify-tag' }
        if ($Repo) { '--repo', $Repo }
    )
    Write-Verbose "gh $arguments"
    if ($PSCmdlet.ShouldProcess("GitHub release: $Tag", 'Create release')) {
        & gh $arguments
    }
}

'Checking for new releases...' >> $env:GITHUB_STEP_SUMMARY

$releases = @{}
Get-Releases -ExcludeDrafts -Property tagName -Limit $MaxReleases -ErrorAction Stop | ForEach-Object {
    $releases[$_.tagName] = $true
}

Get-Releases -Repo $SourceRepo -ExcludeDrafts -Property tagName -Limit $MaxReleases -ErrorAction Stop
| Where-Object { !$releases.ContainsKey($_.tagName) }
| ForEach-Object {
    'Processing release: {0}' -f $_.tagName | Write-Host -ForegroundColor Cyan
    $release = $_ | Get-Release -Repo $SourceRepo -Property body, isDraft, isPrerelease, name, tagName -ErrorAction Stop
    $guid = New-Guid
    $releaseDirectory = New-Item -ItemType Directory -Path "$PSScriptRoot/$guid" -ErrorAction Stop
    try {
        $release | Get-Asset -Repo $SourceRepo -OutDirectory $releaseDirectory -Pattern *.apk, $TarGzAssets -ErrorAction Stop
        
        $releaseDirectory
        | Get-ChildItem -Filter *.tar.gz
        | ForEach-Object {
            Write-Host "Processing asset: $_" -ForegroundColor Cyan
            $name = [System.IO.Path]::ChangeExtension($_.BaseName, ".apk")
            $tempDirectory = New-Item -ItemType Directory -Path "$releaseDirectory/temp" -ErrorAction Stop
            try {
                tar -xzf $_ --directory $tempDirectory
                $tempDirectory
                | Get-ChildItem -Filter *.apk
                | Move-Item -Destination "$releaseDirectory/$name" -ErrorAction Stop
                $_ | Remove-Item -Force -ErrorAction Stop
            } finally {
                $tempDirectory | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        $assets = @($releaseDirectory | Get-ChildItem -Filter *.apk)
        $release | Add-Release -Asset $assets -Target $null -ErrorAction Stop
        '✅ Release {0} created with {1} asset(s)' -f $release.tagName, $assets.Count >> $env:GITHUB_STEP_SUMMARY
    } catch {
        '❌ Release {0} failed: {1}' -f $release.tagName, $_.Exception.Message >> $env:GITHUB_STEP_SUMMARY
        throw
    } finally {
        $releaseDirectory | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
}
