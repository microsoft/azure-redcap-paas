$global:ProgressPreference = "SilentlyContinue"
$AllProtocols = [System.Net.SecurityProtocolType]'Ssl3,Tls,Tls11,Tls12'
[System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols

Add-Type -AssemblyName System.Net.Http

$path = "$($env:HOME)\site\repository"
$webRoot = "$($env:HOME)\site\wwwroot"

[System.Reflection.Assembly]::LoadFrom("$path\Files\mysql\MySql.Data.dll") | Out-Null

$dbver=""
$zipUri = "$env:APPSETTING_redcapAppZip"
$stamp=(Get-Date).toString("yyyy-MM-dd-HH-mm-ss")
$logFile = "$path\log-$stamp.txt"
Set-Content "$($env:HOME)\site\repository\currlogname.txt" -Value $logFile -NoNewline

Write-Output "loading functions"

function Main {
    Write-Output "Test"
    try {
		Copy-Item -Path "$path\Files\AzDeployStatus.php" -Destination "$webRoot\AzDeployStatus.php"
		Log("Checking ZIP file name and version")

		$filename = GetFileName($zipUri)
		$filePath = "$path\$filename"
        $version = $filename.Replace(".zip","")
		$dbver = $version.Replace("redcap","")

        Log("Processing $version")

        if (-Not (Test-Path "$filePath")) {
            Log("Downloading $filename")
    
            # Download the ZIP file
            Invoke-WebRequest $zipUri -OutFile $filePath

            Log("Unzipping file")
            mkdir "$path\target" -ErrorAction SilentlyContinue
            Expand-Archive $filePath -DestinationPath "$path\target\$version" -Force

            # reset RO attributes on some files
            Log("Resetting file attributes")
            attrib -r "$path\target\$version\redcap\webtools2\pdf\font\unifont\*.*" /S

            # clean up www
            Log("Cleaning up existing web root")
            Get-ChildItem -Path  $webRoot -Recurse -Exclude "AzDeployStatus.php" |
                Select-Object -ExpandProperty FullName |
                Sort-Object length -Descending |
                Remove-Item -force 

            # copy app files to wwwroot
            Log("Moving files to web root")
			MoveFiles

			# add web.config to clean up MIME types in IIS
			Log("Copying web.config")
			Copy-Item -Path "$path\Files\web.config" -Destination "$webRoot\web.config"

			# Setup Web Job
			Log("Setting up web job")
			SetupWebJob

			# initialize PHP_INI_SYSTEM settings
			# https://docs.microsoft.com/en-us/azure/app-service/web-sites-php-configure#changing-phpinisystem-configuration-settings
			Log("Updating PHP and sendmail settings")
			UpdatePHPSettings

		    # Add container to new storage account
		    Log("Creating storage container")
			CreateContainer

            # Update database config
            Log("Updating $dbFilename with assigned variables")
            UpdateDBConnection

			# Apply schema
        	Log("Applying schema to new database (this could take several minutes)")
			ApplySchema
			
			# Update app config
			Log("Updating configuration in redcap_config")
			UpdateConfig

			Log("Deployment complete")

        } else {
            Write-Output "File $filename already present"
        }
    }
    catch {
		Log("An error occured and deployment may not have completed successfully. Try loading the home page to see if the database is connected. The detailed error message is below:<br>")
        Log($_.Exception)
        Exit 1
    }
}

function SetupWebJob {
	$webJobDir = "$webRoot\App_Data\jobs\triggered\CronWebJob";
	mkdir $webJobDir;
	Copy-Item -Path "$path\Files\WebJob\cronWebJob.ps1" -Destination $webJobDir
	Copy-Item -Path "$path\Files\WebJob\settings.job" -Destination $webJobDir
}

function CreateContainer {
    $storageCtx = New-AzureStorageContext -StorageAccountName $env:APPSETTING_StorageAccount -StorageAccountKey $env:APPSETTING_StorageKey
    New-AzureStorageContainer -Name $env:APPSETTING_StorageContainerName -Context $storageCtx 
}

function ApplySchema {
	#Get schema
	$sql = GetSQLSchema
	Log("Schema retrieved from site, applying...")

	CallSql -Query $sql

	Log("Completed applying schema")
}

function UpdateConfig {
	Log("Updating site configuration in database")

	CallSql -Query "UPDATE $($env:APPSETTING_DBName).redcap_config SET value ='https://$($env:WEBSITE_HOSTNAME)/' WHERE field_name = 'redcap_base_url';"

	Log("Updating storage configuration in database")
	$sqlList = @(
		#storage
		"UPDATE $($env:APPSETTING_DBName).redcap_config SET value ='$env:APPSETTING_StorageAccount' WHERE field_name = 'azure_app_name';",
		"UPDATE $($env:APPSETTING_DBName).redcap_config SET value ='$env:APPSETTING_StorageKey' WHERE field_name = 'azure_app_secret';",
		"UPDATE $($env:APPSETTING_DBName).redcap_config SET value ='$env:APPSETTING_StorageContainerName' WHERE field_name = 'azure_container';"
		"UPDATE $($env:APPSETTING_DBName).redcap_config SET value ='4' WHERE field_name = 'edoc_storage_option';"
	)
	$sqlStr = $sqlList -join "`r`n" | Out-String
	#SilentlyContinue should accomodate earlier versions that don't have direct support for Azure storage
	CallSql -Query $sqlStr -ErrorAction SilentlyContinue

	Log("Completed updating configuration")
}

function CallSql {
	param(
		[parameter(Position=0, Mandatory=$true)]
		[string]$Query
    )

	$cs = "Server=$env:APPSETTING_DBHostName;Port=3306;Allow Batch=true;default command timeout=900;Allow User Variables=true;Connection Timeout=600;Uid=$env:APPSETTING_DBUserName;Pwd=$env:APPSETTING_DBPassword;Database=$env:APPSETTING_DBName;"
	$cn = New-Object MySql.Data.MySqlClient.MySqlConnection
	$cn.ConnectionString = $cs
	$cn.Open()

	$cmd= New-Object MySql.Data.MySqlClient.MySqlCommand
	$cmd.Connection  = $cn
	$cmd.CommandType = [System.Data.CommandType]::Text
	$cmd.CommandTimeout = 30000
	$cmd.CommandText = $Query
	$cmd.ExecuteNonQuery()
	$cmd.Dispose()
	$cn.Close()
	$cn.Dispose()
}

function UpdatePHPSettings {
	Log("Updating sendmail")
    $sendmailiniFileName = "$path\Files\sendmail\sendmail.ini"
    $sendmailiniFile = [System.Io.File]::ReadAllText($sendmailiniFileName)
    $sendmailiniFile = $sendmailiniFile.Replace('replace_smtp_server_name',"$env:APPSETTING_smtp_fqdn_name").Replace('replace_smtp_port', "$env:APPSETTING_smtp_port").Replace('replace_smtp_force_sender', "$env:APPSETTING_sendmail_from").Replace('replace_smtp_username', "$env:APPSETTING_smpt_user").Replace('replace_smtp_password', "$env:APPSETTING_smpt_password");
    $settingsFile | Set-Content $settingsFileName
	Copy-Item $settingsFileName "$iniFolder\settings.ini"

    $iniFolder = "$($env:HOME)\site\ini"
	mkdir $iniFolder
    $settingsFileName = "$path\Files\settings.ini"
    Log("Updating $settingsFileName with assigned variables")
    $settingsFile = [System.Io.File]::ReadAllText($settingsFileName)
    $settingsFile = $settingsFile.Replace('replace_smtp_server_name',"$env:APPSETTING_smtp_fqdn_name").Replace('replace_smtp_port', "$env:APPSETTING_smtp_port").Replace('replace_sendmail_from', "$env:APPSETTING_sendmail_from").Replace('replace_sendmail_path', "$path\Files\sendmail\sendmail.exe -t -i");
    $settingsFile | Set-Content $settingsFileName
	Copy-Item $settingsFileName "$iniFolder\settings.ini"
}

function UpdateDBConnection {
    $dbFilename = "$webRoot\database.php"
	$bytes = New-Object Byte[] 8
	$rand = [System.Security.Cryptography.RandomNumberGenerator]::Create()
	$rand.GetBytes($bytes)
	$rand.Dispose()
	$newsalt = [System.Convert]::ToBase64String($bytes)
    $dbFile = [System.Io.File]::ReadAllText($dbFilename)
    $dbFile = $dbFile.Replace('your_mysql_host_name',"$env:APPSETTING_DBHostName").Replace('your_mysql_db_name', "$env:APPSETTING_DBName").Replace('your_mysql_db_username', "$env:APPSETTING_DBUserName").Replace('your_mysql_db_password', "$env:APPSETTING_DBPassword").Replace("`$salt = ''", "`$salt = '$newsalt'");
     
    $dbFile | Set-Content $dbFilename
}

function GetSQLSchema {
	$body = @{
		"version" = $dbver
	}
	$res = Invoke-WebRequest `
		-UseBasicParsing `
		-Uri "https://$($env:WEBSITE_HOSTNAME)/install.php" `
		-Body $body `
		-Method Post

	$str = $res.Content
	$start = $str.IndexOf("<textarea ")
	$end = $str.IndexOf("</textarea>")
	$new = $str.substring($start, ($end - $start))
	$sql = $new -replace("<textarea[^>]*>","")

	#save the schema for posterity
	$sql | Out-File schema.sql
	return $sql
}

function MoveFiles {
    $source = "$path\target\$version\redcap"
    $dest = $webRoot
    $what = @("*.*","/E","/MOVE","/NFL","/NDL","NJH","NP","/LOG+:`"$logFile`"")

    $cmdArgs = @("$source","$dest",$what)
    robocopy @cmdArgs

    Log("RoboCopy output: $($rcOutput[$LASTEXITCODE])")
}

function GetFileName($Url) {
	$res = Invoke-WebRequest -Method Head -Uri $Url -UseBasicParsing

	$header = $res.Headers["content-disposition"]
	if ($null -ne $header) {
		$filename = [System.Net.Http.Headers.ContentDispositionHeaderValue]::Parse($header).Filename
		if ($filename.IndexOf('"') -gt -1) {
			$filename = ConvertFrom-Json $filename
		}
	} else {
		$header = $res.Headers.Keys | Where-Object { if($_.contains("filename")){$_}}
		$filename = $res.Headers[$header]
	}
	return $filename
}

function Log($entry) {
    $msg = "$((Get-Date).ToString("yyyy/MM/dd HH:mm:ss")) $entry"
    Add-Content $logFile -Value $msg | Out-Null
    Write-Output $msg
}

function Resolve-Error ($ErrorRecord=$Error[0])
{
   $ErrorRecord | Format-List * -Force
   $ErrorRecord.InvocationInfo |Format-List *
   $Exception = $ErrorRecord.Exception
   for ($i = 0; $Exception; $i++, ($Exception = $Exception.InnerException))
   {   "$i" * 80
       $Exception |Format-List * -Force
   }
}

#https://support.microsoft.com/en-us/help/954404/return-codes-that-are-used-by-the-robocopy-utility-in-windows-server-2
$rcOutput=@{
    0 = "No files were copied. No failure was encountered. No files were mismatched. The files already exist in the destination directory; therefore, the copy operation was skipped.";
    1 = "All files were copied successfully.";
    2 = "There are some additional files in the destination directory that are not present in the source directory. No files were copied.";
    3 = "Some files were copied. Additional files were present. No failure was encountered.";
    5 = "Some files were copied. Some files were mismatched. No failure was encountered.";
    6 = "Additional files and mismatched files exist. No files were copied and no failures were encountered. This means that the files already exist in the destination directory.";
    7 = "Files were copied, a file mismatch was present, and additional files were present.";
    8 = "Several files did not copy.";
}

# Start running deployment
Main