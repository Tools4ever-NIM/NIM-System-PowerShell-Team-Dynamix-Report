#
# TeamDynamixReport.ps1 - TeamDynamixReport Web Services API (SOAP)
#


$Log_MaskableKeys = @(
    # Put a comma-separated list of attribute names here, whose value should be masked before 
    'Password',
    "proxy_password"
)

#
# System functions
#
function Idm-SystemInfo {
    param (
        # Operations
        [switch] $Connection,
        [switch] $TestConnection,
        [switch] $Configuration,
        # Parameters
        [string] $ConnectionParams
    )

    Log info "-Connection=$Connection -TestConnection=$TestConnection -Configuration=$Configuration -ConnectionParams='$ConnectionParams'"

    if ($Connection) {
        @(
            @{
                name = 'hostname'
                type = 'textbox'
                label = 'Hostname'
                description = 'Hostname for Web Services'
                value = 'customer.teamdynamix.com'
            }
            @{
                name = 'report_id'
                type = 'textbox'
                label = 'Report Id'
                description = 'ID for the report to retrieve'
                value = ''
            }
            @{
                name = 'username'
                type = 'textbox'
                label = 'Username'
                label_indent = $true
                description = 'Username account'
                value = ''
            }
            @{
                name = 'password'
                type = 'textbox'
                password = $true
                label = 'Password'
                label_indent = $true
                description = 'User account password'
                value = ''
            }
            @{
                name = 'use_proxy'
                type = 'checkbox'
                label = 'Use Proxy'
                description = 'Use Proxy server for requets'
                value = $false                  # Default value of checkbox item
            }
            @{
                name = 'proxy_address'
                type = 'textbox'
                label = 'Proxy Address'
                description = 'Address of the proxy server'
                value = 'http://localhost:8888'
                disabled = '!use_proxy'
                hidden = '!use_proxy'
            }
            @{
                name = 'use_proxy_credentials'
                type = 'checkbox'
                label = 'Use Proxy'
                description = 'Use Proxy server for requets'
                value = $false
                disabled = '!use_proxy'
                hidden = '!use_proxy'
            }
            @{
                name = 'proxy_username'
                type = 'textbox'
                label = 'Proxy Username'
                label_indent = $true
                description = 'Username account'
                value = ''
                disabled = '!use_proxy_credentials'
                hidden = '!use_proxy_credentials'
            }
            @{
                name = 'proxy_password'
                type = 'textbox'
                password = $true
                label = 'Proxy Password'
                label_indent = $true
                description = 'User account password'
                value = ''
                disabled = '!use_proxy_credentials'
                hidden = '!use_proxy_credentials'
            }
            @{
                name = 'nr_of_sessions'
                type = 'textbox'
                label = 'Max. number of simultaneous sessions'
                description = ''
                value = 1
            }
            @{
                name = 'sessions_idle_timeout'
                type = 'textbox'
                label = 'Session cleanup idle time (minutes)'
                description = ''
                value = 1
            }
        )
    }

    if ($TestConnection) {
        
    }

    if ($Configuration) {
        @()
    }

    Log info "Done"
}

function Idm-OnUnload {
}

#
# Object CRUD functions
#

function Idm-ReportRead {
    param (
        # Mode
        [switch] $GetMeta,    
        # Parameters
        [string] $SystemParams,
        [string] $FunctionParams

    )
        $system_params = ConvertFrom-Json2 $SystemParams    
        
        #Get Authorization Token
        $authToken = Open-TeamDynamixReportConnection $system_params

        
        if ($GetMeta) {
            @()
            
        } else {

            #Retrieve Report
            $uri = "https://$($system_params.hostname)/TDWebApi/api/reports/$($system_params.report_id)?withData=true&dataSortExpression=''"
            
            $headers = @{
                "Authorization" = "Bearer $($authToken)"
            }

            try {
                $splat = @{
                    Method = "GET"
                    Uri = $uri
                    Headers = $headers
                }

                if($system_params.use_proxy)
                {
                    $splat["Proxy"] = $system_params.proxy_address

                    if($system_params.use_proxy_credentials)
                    {
                        $splat["proxyCredential"] = New-Object System.Management.Automation.PSCredential ($system_params.proxy_username, (ConvertTo-SecureString $system_params.proxy_password -AsPlainText -Force) )
                    }
                }

                $response = Invoke-RestMethod @splat -ErrorAction Stop

                $columns = $response.DisplayedColumns | Group-Object ColumnName -AsHashTable
                $hash_table = [ordered]@{}

                foreach ($column_name in $columns.GetEnumerator()) {
                    $name = $column_name.Value.HeaderText.replace(' ','').replace('-','_')
                    $hash_table[$name] = ""
                }
                
                foreach($item in $response.DataRows) {
                    $row = New-Object -TypeName PSObject -Property $hash_table
                
                    foreach($prop in $item.PSObject.properties) {
                            $columnName = ($columns[$prop.Name].HeaderText).replace(' ','').replace('-','_')
                            $row.$columnName = $prop.Value
                        }

                    $row
                }

            }
            catch [System.Net.WebException] {
                $message = "Error : $($_)"
                Log error $message
                Write-Error $_
            }
            catch {
                $message = "Error : $($_)"
                Log error $message
                Write-Error $_
            }
        }
}

function Check-TeamDynamixReportConnection { 
    param (
        [string] $SystemParams
    )
     Open-TeamDynamixReportConnection $SystemParams
}

function Open-TeamDynamixReportConnection {
    param (
        [hashtable] $SystemParams
    )
    
    $uri = "https://$($SystemParams.hostname)/TDWebApi/api/auth"

    $headers = @{
        "Content-Type" = "application/json"
    }

    $body = (@{
        "UserName"= $SystemParams.username
        "Password"= $SystemParams.password
    } | ConvertTo-Json)

    try {
		$splat = @{
            Method = "POST"
            Uri = $uri
            Headers = $headers
            Body = $body
        }

        if($SystemParams.use_proxy)
        {
            $splat["Proxy"] = $SystemParams.proxy_address

            if($SystemParams.use_proxy_credentials)
            {
                $splat["proxyCredential"] = New-Object System.Management.Automation.PSCredential ($SystemParams.proxy_username, (ConvertTo-SecureString $SystemParams.proxy_password -AsPlainText -Force) )
            }
        }

        $result = Invoke-RestMethod @splat -ErrorAction Stop
        
	}
	catch [System.Net.WebException] {
        $message = "Error : $($_)"
        Log error $message
        Write-Error $_
	}
    catch {
        $message = "Error : $($_)"
        Log error $message
        Write-Error $_
    }
    finally {
        Write-Output $result
    }
}
