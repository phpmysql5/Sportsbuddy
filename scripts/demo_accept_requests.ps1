$ErrorActionPreference = 'Stop'

function Login($email, $password) {
  $body = @{ email = $email; password = $password } | ConvertTo-Json
  Invoke-RestMethod -Method Post -Uri 'http://localhost:3000/auth/login' -ContentType 'application/json' -Body $body
}

function Headers($token) {
  @{ Authorization = ('Bearer ' + $token) }
}

$arjun = Login 'arjun.mangalore@sportsbuddy.dev' 'Demo@1234'
$neha = Login 'neha.mangalore@sportsbuddy.dev' 'Demo@1234'
$rohan = Login 'rohan.mangalore@sportsbuddy.dev' 'Demo@1234'

$nehaMe = Invoke-RestMethod -Method Get -Uri 'http://localhost:3000/auth/me' -Headers (Headers $neha.accessToken)
$rohanMe = Invoke-RestMethod -Method Get -Uri 'http://localhost:3000/auth/me' -Headers (Headers $rohan.accessToken)

try {
  Invoke-RestMethod -Method Post -Uri 'http://localhost:3000/connections/requests' -Headers (Headers $arjun.accessToken) -ContentType 'application/json' -Body (@{ receiverId = $nehaMe.id } | ConvertTo-Json) | Out-Null
} catch {}

try {
  Invoke-RestMethod -Method Post -Uri 'http://localhost:3000/connections/requests' -Headers (Headers $arjun.accessToken) -ContentType 'application/json' -Body (@{ receiverId = $rohanMe.id } | ConvertTo-Json) | Out-Null
} catch {}

$incomingNeha = Invoke-RestMethod -Method Get -Uri 'http://localhost:3000/connections/requests/incoming' -Headers (Headers $neha.accessToken)
foreach ($req in $incomingNeha) {
  if ($req.sender.email -eq 'arjun.mangalore@sportsbuddy.dev' -and $req.status -eq 'pending') {
    Invoke-RestMethod -Method Post -Uri ("http://localhost:3000/connections/requests/{0}/respond" -f $req.id) -Headers (Headers $neha.accessToken) -ContentType 'application/json' -Body (@{ action = 'accept' } | ConvertTo-Json) | Out-Null
  }
}

$arjunOutgoing = Invoke-RestMethod -Method Get -Uri 'http://localhost:3000/connections/requests/outgoing' -Headers (Headers $arjun.accessToken)
$arjunBuddies = Invoke-RestMethod -Method Get -Uri 'http://localhost:3000/connections/buddies' -Headers (Headers $arjun.accessToken)
$nehaBuddies = Invoke-RestMethod -Method Get -Uri 'http://localhost:3000/connections/buddies' -Headers (Headers $neha.accessToken)
$rohanIncoming = Invoke-RestMethod -Method Get -Uri 'http://localhost:3000/connections/requests/incoming' -Headers (Headers $rohan.accessToken)

Write-Output ("arjun_outgoing_pending=" + $arjunOutgoing.Count)
Write-Output ("arjun_buddies=" + $arjunBuddies.Count)
Write-Output ("neha_buddies=" + $nehaBuddies.Count)
Write-Output ("rohan_incoming_pending=" + $rohanIncoming.Count)
