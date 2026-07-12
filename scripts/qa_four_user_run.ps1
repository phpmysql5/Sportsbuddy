$ErrorActionPreference = 'Stop'

$base = 'http://localhost:3000'
$results = New-Object System.Collections.Generic.List[Object]

function Add-Result($id, $name, $passed, $details) {
  $results.Add([PSCustomObject]@{
    id = $id
    name = $name
    passed = $passed
    details = $details
  })
}

function Invoke-Json {
  param(
    [string]$Method,
    [string]$Path,
    $Body = $null,
    [string]$AccessToken = $null
  )

  $headers = @{}
  if ($AccessToken) { $headers['Authorization'] = "Bearer $AccessToken" }

  $params = @{
    Method = $Method
    Uri = "$base$Path"
    Headers = $headers
    ContentType = 'application/json'
  }

  if ($null -ne $Body) {
    $params['Body'] = ($Body | ConvertTo-Json -Depth 8)
  }

  return Invoke-RestMethod @params
}

function Login-User {
  param([string]$Email, [string]$Password)
  return Invoke-Json -Method 'POST' -Path '/auth/login' -Body @{ email = $Email; password = $Password }
}

function Assert-True {
  param([bool]$Cond, [string]$Message)
  if (-not $Cond) { throw $Message }
}

try {
  # TC00 Health
  $health = Invoke-Json -Method 'GET' -Path '/health'
  Assert-True ($health.status -eq 'ok') 'Health endpoint not ok'
  Add-Result 'TC00' 'API health' $true 'Health returned ok'

  $users = @{
    A = @{ email='arjun.mangalore@sportsbuddy.dev'; password='Demo@1234'; city='Mangalore'; sports=@('Tennis','Football'); skill='beginner'; days=@('Tue','Thu') }
    B = @{ email='neha.mangalore@sportsbuddy.dev'; password='Demo@1234'; city='Mangalore'; sports=@('Tennis','Badminton'); skill='intermediate'; days=@('Tue','Thu') }
    C = @{ email='rohan.mangalore@sportsbuddy.dev'; password='Demo@1234'; city='Mangalore'; sports=@('Cricket','Tennis'); skill='beginner'; days=@('Tue','Fri') }
    D = @{ email='ava@sportsbuddy.dev'; password='Demo@1234'; city='Bengaluru'; sports=@('Basketball','Football'); skill='advanced'; days=@('Sat','Sun') }
  }

  $sessions = @{}

  # TC01 login all
  foreach ($key in $users.Keys) {
    $u = $users[$key]
    $auth = Login-User -Email $u.email -Password $u.password
    $sessions[$key] = @{
      access = $auth.accessToken
      refresh = $auth.refreshToken
      user = $auth.user
    }
    Assert-True (-not [string]::IsNullOrWhiteSpace($auth.accessToken)) "Missing access token for $key"
  }
  Add-Result 'TC01' 'Login four users' $true 'All four users logged in'

  # TC02 update profiles
  foreach ($key in $users.Keys) {
    $u = $users[$key]
    $s = $sessions[$key]
    $profile = Invoke-Json -Method 'PUT' -Path '/profile' -AccessToken $s.access -Body @{
      city = $u.city
      sport = $u.sports[0]
      sports = $u.sports
      skillLevel = $u.skill
      availabilityDays = $u.days
    }
    Assert-True ($profile.city -eq $u.city) "Profile city mismatch for $key"
  }
  Add-Result 'TC02' 'Profile update four users' $true 'All profiles updated'

  # TC03 suggestions exist for A
  $suggestionsA = Invoke-Json -Method 'GET' -Path '/matching/suggestions' -AccessToken $sessions['A'].access
  Assert-True ($suggestionsA.Count -ge 1) 'A suggestions empty'
  Add-Result 'TC03' 'Discover suggestions for A' $true "A suggestion count: $($suggestionsA.Count)"

  # TC04 A -> C send request
  $cid = $sessions['C'].user.id
  $req = Invoke-Json -Method 'POST' -Path '/connections/requests' -AccessToken $sessions['A'].access -Body @{ receiverId = $cid }
  Assert-True ($req.status -eq 'pending') 'A->C request not pending'
  $acRequestId = $req.id
  Add-Result 'TC04' 'A sends request to C' $true "requestId=$acRequestId"

  # TC05 C accepts A request
  $resp = Invoke-Json -Method 'POST' -Path "/connections/requests/$acRequestId/respond" -AccessToken $sessions['C'].access -Body @{ action='accept' }
  Assert-True ($resp.status -eq 'accepted') 'A->C request not accepted'
  Add-Result 'TC05' 'C accepts A request' $true 'Request accepted'

  # TC06 buddy appears and chat works A->C
  $buddiesA = Invoke-Json -Method 'GET' -Path '/connections/buddies' -AccessToken $sessions['A'].access
  $buddyC = $buddiesA | Where-Object { $_.id -eq $cid } | Select-Object -First 1
  Assert-True ($null -ne $buddyC) 'C not present in A buddies'
  $msg = Invoke-Json -Method 'POST' -Path "/chat/buddies/$cid/messages" -AccessToken $sessions['A'].access -Body @{ content='yo lets play at 6pm' }
  Assert-True ($msg.content -match 'play') 'Message content mismatch'
  Add-Result 'TC06' 'A buddy chat with C' $true 'Buddy exists and message sent'

  # TC07 session plan A create, C discover/join/leave
  $scheduledAt = (Get-Date).AddHours(3).ToString('o')
  $plan = Invoke-Json -Method 'POST' -Path '/sessions/plans' -AccessToken $sessions['A'].access -Body @{
    scheduledAt = $scheduledAt
    area = 'Mangalore'
    sport = 'Tennis'
    skillLevel = 'beginner'
    maxPlayers = 4
  }
  $planId = $plan.id
  Assert-True (-not [string]::IsNullOrWhiteSpace($planId)) 'Missing plan id'

  $discoverC = Invoke-Json -Method 'GET' -Path '/sessions/plans/discover' -AccessToken $sessions['C'].access
  $planForC = $discoverC | Where-Object { $_.id -eq $planId } | Select-Object -First 1
  Assert-True ($null -ne $planForC) 'C cannot discover A plan'

  $join = Invoke-Json -Method 'POST' -Path "/sessions/plans/$planId/join" -AccessToken $sessions['C'].access
  Assert-True ($join.joined -eq $true) 'C join failed'

  $leave = Invoke-Json -Method 'DELETE' -Path "/sessions/plans/$planId/join" -AccessToken $sessions['C'].access
  Assert-True ($leave.success -eq $true) 'C leave failed'

  Add-Result 'TC07' 'Session create/discover/join/leave' $true "planId=$planId"

  # TC08 safety block D by A then verify D absent from A suggestions
  $did = $sessions['D'].user.id
  $block = Invoke-Json -Method 'POST' -Path '/safety/blocks' -AccessToken $sessions['A'].access -Body @{ userId = $did }
  Assert-True ($block.success -eq $true) 'Block failed'

  $suggestionsA2 = Invoke-Json -Method 'GET' -Path '/matching/suggestions' -AccessToken $sessions['A'].access
  $containsD = $suggestionsA2 | Where-Object { $_.user.id -eq $did } | Select-Object -First 1
  Assert-True ($null -eq $containsD) 'Blocked user D still in A suggestions'
  Add-Result 'TC08' 'Block affects discover visibility' $true 'Blocked user removed from suggestions'

} catch {
  Add-Result 'FAIL' 'Run aborted' $false $_.Exception.Message
}

# Render markdown report
$lines = @()
$lines += '# Four-User Active Usage Run Results'
$lines += ''
$lines += "Run time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$lines += ''
$lines += '| ID | Test | Result | Details |'
$lines += '|---|---|---|---|'
foreach ($r in $results) {
  $res = if ($r.passed) { 'PASS' } else { 'FAIL' }
  $details = ($r.details -replace '\|', '/')
  $lines += "| $($r.id) | $($r.name) | $res | $details |"
}

$reportPath = Join-Path $PSScriptRoot '..\docs\QA_4_USER_RESULTS.md'
$reportPath = [System.IO.Path]::GetFullPath($reportPath)
$lines | Set-Content -Path $reportPath -Encoding UTF8

Write-Output "Report written: $reportPath"
$results | Format-Table -AutoSize | Out-String | Write-Output
