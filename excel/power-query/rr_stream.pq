// rr_stream — R-R interval stream for the staged recording.
//
// Identical to the working workbook's query except that the absolute file
// path is replaced by the DataFolder parameter (see DataFolder.pq).
// This is the form used in the published template. Leading comment lines
// are stripped when tools/build_template.ps1 loads the query.

let
    Source = Csv.Document(File.Contents(DataFolder & "rr.csv"), [Delimiter=",", Columns=3, Encoding=1252, QuoteStyle=QuoteStyle.None]),
    #"Promoted Headers" = Table.PromoteHeaders(Source, [PromoteAllScalars=true]),
    #"Changed Type" = Table.TransformColumnTypes(#"Promoted Headers", {{"rx_unix_ms", Int64.Type}, {"frame", Int64.Type}, {"rr_ms", Int64.Type}})
in
    #"Changed Type"
