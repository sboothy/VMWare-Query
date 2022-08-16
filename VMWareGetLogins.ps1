Start-Transcript -Path "C:\Scripts\Logs\VDILogins$((Get-Date).ToString('MMddyyyy-HHmmss')).txt"

Import-Module SqlServer
Get-Module -ListAvailable VMware* | Import-Module
Import-Module C:\Scripts\SQL\SQL-Login.psm1
Import-Module C:\Scripts\VMwareQuery\VMWareHorizon-Login.psm1
KACSQL1-LoginWindows


#*********************** SQL QUERY TO FIND USERS WHO HAVE LOGGED INTO THEIR VDI IN THE LAST 30 DAYS #***********************

# Save output
$OuputFileSQL = "c:\scripts\Logs\VDILogins\UsersLoggedInPast30Days.csv"

# SQL query
$SqlQuery = "SELECT
    [ModuleAndEventText] 
    FROM [VDIEventLog].[dbo].[event]
    WHERE CHARINDEX('logged in', ModuleAndEventText) > 0 and DATEDIFF(day,time,GETDATE()) between 0 and 30 and [EventType] = 'BROKER_USERLOGGEDIN'
    ORDER BY [ModuleAndEventText] ASC"
   

$SqlCmd = New-Object System.Data.SqlClient.SqlCommand 
$SqlCmd.CommandText = $SqlQuery
$SqlCmd.Connection = $SqlConnection
  
$SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter 
$SqlAdapter.SelectCommand = $SqlCmd
  
$DataSet = New-Object System.Data.DataSet 
$SqlAdapter.Fill($DataSet) 
$SqlConnection.Close() 
 
#Output RESULTS to CSV
$DataSet.Tables[0] | Export-Csv $OuputFileSQL

#*********************** VMWARE QUERY TO FIND WHO IS ASSIGNED A VDI #***********************

$vms = Get-HVMachineSummary
$AssignedUsersdatapath = 'C:\Scripts\Logs\VDILogins\AssignedUsers.csv'
$AssignedUsers = @()

foreach($vm in $vms){

$properties = @{

UserName = $vm.NamesData.UserName 

}

$AssignedUsers += New-Object psobject -Property $properties

}

$AssignedUsers | Sort username -descending |export-csv -NoTypeInformation -path $AssignedUsersdatapath

Disconnect-HVServer -Confirm:$false

#*********************** LIST OF USERS WHO ARE ASSIGNED A VDI MACHINE #***********************

$AssignedUsers = @([io.file]::readalltext($AssignedUsersdatapath).replace("hwlochner.com\",'')).toUpper()

$AssignedUsers = $AssignedUsers | Out-File -FilePath $AssignedUsersdatapath -Encoding utf8 

$AssignedUsers = Get-Content $AssignedUsersdatapath | select -Unique | Set-Content $AssignedUsersdatapath


#*********************** LIST OF USERS WHO HAVE LOGGED IN IN THE PAST 30 DAYS #***********************

$ActiveUsersPath = "C:\Scripts\Logs\VDILogins\UsersLoggedInPast30Days.csv"

#Convert to string and remove unwanted data (Only get usernames)

$ActiveUsers = @([io.file]::readalltext($ActiveUsersPath).replace("User HWLOCHNER\",'').replace(" has logged in",'')).toUpper().Trim()

#Export string to csv/array

$ActiveUsers = $ActiveUsers| Out-File -FilePath $ActiveUsersPath -Encoding utf8 

#Only show usernames once (i.e. If a user has logged in, we don't need to know all of their log in events)

$ActiveUsers = Get-Content $ActiveUsersPath | Select-Object -Skip 2| select -Unique | Set-Content $ActiveUsersPath

#*********************** COMPARE LISTS AND FIND ASSIGNED USERS WHO ARE NOT IN ACTIVE USERS LIST #***********************

$ActiveUsers = Import-CSV -Path $ActiveUsersPath -Header USERNAME

$AssignedUsers = Import-CSV -Path $AssignedUsersdatapath 

$AssignedUsersArray =@()
$ActiveUsersArray =@()

foreach ($user in $AssignedUsers  ){
    $AssignedUsersArray += $user.USERNAME
}

foreach ($user in $ActiveUsers){
    $ActiveUsersArray += $user.USERNAME
}

$FinalList = $assignedusersarray | Where {$activeusersarray -notcontains $_}

$InactiveUserFormatList = $null

Foreach ($user in $FinalList){

 $InactiveUserFormatList += $user + "@hwlochner.com" + "`n"

}

$MailMessage = @{
			To	    = "sbooth@hwlochner.com"
			From    = "VMWarePowerShell@hwlochner.com"
			Subject = "VMWARE Users Who Have Not Logged On for 30 Days"
			Body    = "$InactiveUserFormatList"
			SMTPServer = "smtp.hwlochner.com"
		}
		Send-MailMessage @MailMessage
