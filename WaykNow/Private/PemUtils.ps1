function PemToDer(
    [byte[]] $Der
){
    $decoder = [PemUtils.DefaultDerAsnDecoder]::new()
    return [string]($decoder.Decode($Der).Value);
}