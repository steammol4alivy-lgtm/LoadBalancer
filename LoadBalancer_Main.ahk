#Requires AutoHotkey v1.1+
#Persistent
#NoEnv
#SingleInstance force
SetBatchLines, -1
ListLines Off
Menu, Tray, Icon

; ======
global g_ProcessTargetName := "cs2.exe"
global g_IntervalMilliseconds := 2000
global g_DelayBeforeRestore := 1000
global g_CompleteAffinityMask := fn_GetCompleteAffinityMask()
global g_LastExcludedCoreIndex := ""

; ======
MsgBox, 64, LoadBalancer запущен!,
(
Добро пожаловать в LoadBalancer — утилиту для оптимизации загрузки ядер!

Автор: MOL4ALIVY

Пусть FPS будет высоким, а фризы — короткими. Удачи в игре!

После нажатия OK программа продолжит работу в фоне и будет отображаться в трее.
)

; ======
SetTimer, label_MonitorCoreLoads, % g_IntervalMilliseconds
return

; ======
label_MonitorCoreLoads:

    local_CoreLoadMap := fn_GetCoreLoadMap()
    local_MaximumObservedLoad := -1
    local_IndexOfMostLoadedCore := -1
    local_TotalNumberOfCores := DllCall("GetActiveProcessorCount", "UInt", 0)

    Loop, %local_TotalNumberOfCores%
    {
        current_CoreIndex := A_Index - 1
        current_LoadValue := local_CoreLoadMap[current_CoreIndex]

        if ( current_LoadValue > local_MaximumObservedLoad )
        {
            local_MaximumObservedLoad := current_LoadValue
            local_IndexOfMostLoadedCore := current_CoreIndex
        }
    }

    if ( local_IndexOfMostLoadedCore >= 0 )
    {
        temporary_ModifiedMask := g_CompleteAffinityMask & ~(1 << local_IndexOfMostLoadedCore)

        fn_ApplyAffinityMaskSilently( g_ProcessTargetName , temporary_ModifiedMask )

        g_LastExcludedCoreIndex := local_IndexOfMostLoadedCore

        SetTimer, label_RestoreAffinityMask, % -g_DelayBeforeRestore
    }

return

; ======
label_RestoreAffinityMask:

    fn_ApplyAffinityMaskSilently( g_ProcessTargetName , g_CompleteAffinityMask )

    g_LastExcludedCoreIndex := ""

return

; ======
fn_GetCoreLoadMap()
{
    local_LoadDictionary := Object()

    local_WMIService := ComObjGet("winmgmts:\\.\root\CIMV2")
    local_QueryResult := local_WMIService.ExecQuery("SELECT * FROM Win32_PerfFormattedData_PerfOS_Processor")

    for each_Item in local_QueryResult
    {
        if ( each_Item.Name != "_Total" )
        {
            sanitized_CoreIdentifier := StrReplace( each_Item.Name , "," , "" )
            local_LoadDictionary[sanitized_CoreIdentifier] := each_Item.PercentProcessorTime
        }
    }

    return local_LoadDictionary
}

; ======
fn_ApplyAffinityMaskSilently( input_ProcessName , input_AffinityMask )
{
    Process, Exist, %input_ProcessName%
    if ( ErrorLevel = 0 )
        return

    resolved_ProcessID := ErrorLevel
    required_AccessFlags := 0x0200 | 0x0008

    process_Handle := DllCall("OpenProcess", "UInt", required_AccessFlags, "Int", False, "UInt", resolved_ProcessID, "Ptr")

    if ( !process_Handle )
        return

    DllCall("SetProcessAffinityMask", "Ptr", process_Handle, A_Is64bitOS ? "UInt64" : "UInt", input_AffinityMask)

    DllCall("CloseHandle", "Ptr", process_Handle)
}

; ======
fn_GetCompleteAffinityMask()
{
    total_ActiveCoreCount := DllCall("GetActiveProcessorCount", "UInt", 0)
    resulting_MaskValue := 0

    Loop, %total_ActiveCoreCount%
    {
        current_BitPosition := A_Index - 1
        resulting_MaskValue := resulting_MaskValue | (1 << current_BitPosition)
    }

    return resulting_MaskValue
}
