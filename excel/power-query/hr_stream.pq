// hr_stream — heart-rate notification stream for the staged recording.
//
// Identical to the working workbook's query except that the absolute file
// path is replaced by the DataFolder parameter (see DataFolder.pq).
// This is the form used in the published template. Leading comment lines
// are stripped when tools/build_template.ps1 loads the query.

let
    Source = Csv.Document(File.Contents(DataFolder & "hr.csv"), [Delimiter=",", Columns=8, Encoding=1252, QuoteStyle=QuoteStyle.None]),
    #"Promoted Headers" = Table.PromoteHeaders(Source, [PromoteAllScalars=true]),
    #"Changed Type" = Table.TransformColumnTypes(#"Promoted Headers", {{"rx_unix_ms", Int64.Type}, {"frame", Int64.Type}, {"hr_bpm", Int64.Type}, {"corrected_hr_bpm", Int64.Type}, {"ppg_quality", Int64.Type}, {"rr_available", Int64.Type}, {"contact", Int64.Type}, {"contact_supported", Int64.Type}})
in
    #"Changed Type"
