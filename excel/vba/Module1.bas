Attribute VB_Name = "Module1"
Sub SaveNight()

    Dim src As Worksheet
    Dim tbl As ListObject
    Dim target As Range
    Dim c As Range
    Dim stamp As Double
    Dim i As Long

    Set src = ThisWorkbook.Worksheets("HRV Analysis")
    Set tbl = ThisWorkbook.Worksheets("Nightly Log").ListObjects(1)

    If tbl.ListColumns.Count < 30 Then
        MsgBox "Check Nightly Log headers through AD."
        Exit Sub
    End If

    ' Verify that the summary contains numerical data
    For i = 1 To 15
        If Not IsNumeric(src.Cells(2, i).Value2) Then
            MsgBox "Incomplete summary. Check HRV Analysis."
            Exit Sub
        End If
    Next i

    stamp = src.Range("A2").Value2

    ' Check whether this recording already exists
    If Not tbl.DataBodyRange Is Nothing Then
        For Each c In tbl.ListColumns(1).DataBodyRange
            If IsNumeric(c.Value2) Then
                If Abs(c.Value2 - stamp) < 0.5 / 86400 Then
                    Set target = c
                    Exit For
                End If
            End If
        Next c
    End If

    ' Add a row if this is a new recording
    If target Is Nothing Then
        Set target = tbl.ListRows.Add.Range.Cells(1, 1)
    End If

    ' Store original physiological measurements
    target.Resize(1, 12).Value2 = src.Range("A2:L2").Value2

    ' Store screened HRV measurements
    target.Offset(0, 27).Resize(1, 3).Value2 = _
        src.Range("M2:O2").Value2

    MsgBox "Nightly recording saved successfully."

End Sub

Sub RefreshAndSaveNight()

    On Error GoTo RefreshFailed

    ' Refresh heart rate data
    If Not ThisWorkbook.Worksheets("HR") _
        .ListObjects(1).QueryTable.Refresh(False) Then
        GoTo RefreshFailed
    End If

    ' Refresh RR interval data
    If Not ThisWorkbook.Worksheets("RR") _
        .ListObjects(1).QueryTable.Refresh(False) Then
        GoTo RefreshFailed
    End If

    ' Wait for pending queries and recalculate
    Application.CalculateUntilAsyncQueriesDone
    Application.CalculateFull

    ' Save results using the existing macro
    Call SaveNight

    Exit Sub

RefreshFailed:

    MsgBox "Refresh failed. Nightly results were not saved. " _
        & "Check your CSV files and data connections.", vbExclamation

End Sub
