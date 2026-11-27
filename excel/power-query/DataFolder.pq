// DataFolder — text parameter: folder that holds the staged hr.csv and rr.csv,
// with a trailing path separator.
//
// To point the template at your own data, open the Power Query editor
// (Data > Get Data > Launch Power Query Editor), choose Manage Parameters,
// and set the current value of DataFolder to your staging folder.

"C:\path\to\Current Night\" meta [IsParameterQuery = true, Type = "Text", IsParameterQueryRequired = true]
