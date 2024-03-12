// A Handlebars Helper to allow bespoke date formatting
// Azure DevOps returns dates in the format "Mon Aug 09 2021 08:31:02 GMT+0000 (Coordinated Universal Time)"
// This functions swaps them to a local format e.g."August 09, 2021 - 08:31"
/* Usage
    {{date_formatter_iso buildDetails.startTime}
*/

module.exports = {
    date_formatter_iso(theDate) {
    return theDate.toISOString();
}};