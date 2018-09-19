class Runbook {
    [string] $Name
    
    [string] $Frequency
    
    [string] $TimeZone = "UTC"
    
    [int] $Interval

    [guid] $JobScheduleId = (New-Guid).ToString()
    
    [object] $JobParameters = @{ }

    Runbook([string] $Name, [string] $Frequency, [int] $Interval) {
        $this.Name = $Name
        $this.Frequency = $Frequency
        $this.Interval = $Interval
    }

    Runbook([string] $Name, [string] $Frequency, [int] $Interval, [object] $JobParameters) {
        $this.Name = $Name
        $this.Frequency = $Frequency
        $this.Interval = $Interval
        $this.JobParameters = $JobParameters
    }

    <# .Description Returns runbook in object format. #>
    [object] GetRunbook() {
        return @{
            name = $this.Name
            frequency = $this.Frequency
            interval = $this.Interval
            timeZone = $this.TimeZone
            jobScheduleId = $this.JobScheduleId
            jobParameters = $this.JobParameters
        }
    }
}