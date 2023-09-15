function New-RandomPassword {
    param (
        [Parameter(Mandatory, Position = 1)]
        [int]$Length
    )

    $charSet = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!#@_-?=+/*&^$;:~'.ToCharArray()

    $rng = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
    $bytes = New-Object byte[]($length)

    $rng.GetBytes($bytes)

    $result = New-Object char[]($length)

    for ($i = 0 ; $i -lt $length ; $i++) {
        $result[$i] = $charSet[$bytes[$i] % $charSet.Length]
    }

    return ConvertTo-SecureString (-Join $result) -AsPlainText -Force
}

Export-ModuleMember -Function New-RandomPassword