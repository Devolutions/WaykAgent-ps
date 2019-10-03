function Set-JsonValue(
    [PSCustomObject] $json,
    [string] $name,
    [PSCustomObject] $value
)
{
    if($json.$name)
    {
        $json.$name = $value;
    }
    else
    {
        # If the json is empty
        if(!$json){
            $json = '{}'
            $json = ConvertFrom-Json $json
        }
          
        $json |  Add-Member -Type NoteProperty -Name $name -Value $value -Force
    }

    return $json
}